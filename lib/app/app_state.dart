// حالة التطبيق: الإعدادات، المسارات، التشغيل، السجل، والتشغيل التلقائي.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/settings.dart';
import '../services/pipeline.dart';
import 'ffmpeg_kit_engine.dart';

class LogLine {
  final DateTime time;
  final String text;
  LogLine(this.text) : time = DateTime.now();
}

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  AppSettings settings = AppSettings();
  late String dataDir;
  late String fontsDir;
  late String defaultOutputDir;
  late ProjectStore store;
  final engine = FfmpegKitEngine();
  final FlutterTts _tts = FlutterTts();

  final logs = <LogLine>[];
  List<ReelProject> projects = [];
  bool running = false;
  String stage = '';
  double progress = 0;
  Pipeline? _current;
  Timer? _autoTimer;
  DateTime? lastAutoRun;
  DateTime? nextAutoRun;

  String get outputDir =>
      settings.outputFolder.isNotEmpty ? settings.outputFolder : defaultOutputDir;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('settings');
    if (raw != null) {
      try {
        settings = AppSettings.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    final support = await getApplicationSupportDirectory();
    dataDir = support.path;
    store = ProjectStore(dataDir);
    fontsDir = await _installFonts();
    defaultOutputDir = await _defaultOutput();
    await FfmpegKitEngine.init(fontsDir);
    final last = _prefs.getString('lastAutoRun');
    if (last != null) lastAutoRun = DateTime.tryParse(last);
    await refreshProjects();
    _scheduleAuto(initial: true);
  }

  Future<String> _installFonts() async {
    final dir = Directory(p.join(dataDir, 'fonts'))..createSync(recursive: true);
    for (final f in [
      'Tajawal-Regular.ttf',
      'Tajawal-Bold.ttf',
      'Tajawal-ExtraBold.ttf',
      'Tajawal-Black.ttf'
    ]) {
      final out = File(p.join(dir.path, f));
      if (!out.existsSync()) {
        final data = await rootBundle.load('assets/fonts/$f');
        await out.writeAsBytes(data.buffer.asUint8List());
      }
    }
    return dir.path;
  }

  Future<String> _defaultOutput() async {
    Directory base;
    if (Platform.isAndroid) {
      base = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    } else {
      base = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
    }
    final d = Directory(p.join(base.path, 'ReelsMaker'))..createSync(recursive: true);
    return d.path;
  }

  Future<void> saveSettings() async {
    await _prefs.setString('settings', jsonEncode(settings.toJson()));
    _scheduleAuto();
    notifyListeners();
  }

  Future<void> refreshProjects() async {
    projects = await store.all();
    notifyListeners();
  }

  void log(String s) {
    logs.add(LogLine(s));
    if (logs.length > 600) logs.removeRange(0, logs.length - 600);
    debugPrint(s);
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  // ---------- صوت الجهاز (أندرويد) ----------
  Future<String?> deviceTts(String text, String outNoExt) async {
    if (!Platform.isAndroid) return null;
    try {
      await _tts.setLanguage('ar');
      if (settings.deviceVoice.isNotEmpty) {
        final voices = await _tts.getVoices as List?;
        final v = voices?.cast<Map>().firstWhere(
            (v) => v['name'] == settings.deviceVoice,
            orElse: () => {});
        if (v != null && v.isNotEmpty) {
          await _tts.setVoice({'name': v['name'], 'locale': v['locale']});
        }
      }
      await _tts.setSpeechRate(settings.deviceRate);
      await _tts.awaitSynthCompletion(true);
      final path = '$outNoExt.wav';
      await _tts.synthesizeToFile(text, path, true);
      for (var i = 0; i < 40 && !File(path).existsSync(); i++) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      return File(path).existsSync() ? path : null;
    } catch (e) {
      log('⚠️ صوت الجهاز: $e');
      return null;
    }
  }

  Future<List<String>> androidVoices() async {
    if (!Platform.isAndroid) return [];
    final voices = await _tts.getVoices as List?;
    return (voices ?? [])
        .cast<Map>()
        .where((v) => '${v['locale']}'.startsWith('ar'))
        .map((v) => '${v['name']}')
        .toList();
  }

  Pipeline newPipeline() => Pipeline(
        settings: settings,
        engine: engine,
        store: store,
        fontsDir: fontsDir,
        outputDir: outputDir,
        log: log,
        deviceTts: deviceTts,
        onStage: (s, f) {
          stage = s;
          progress = f.clamp(0, 1);
          notifyListeners();
        },
      );

  /// يشغّل أي مهمة طويلة مع حماية من التشغيل المزدوج.
  Future<T?> run<T>(String title, Future<T> Function(Pipeline p) job) async {
    if (running) {
      log('⏳ في شغل شغال هلأ، استنى يخلص');
      return null;
    }
    running = true;
    stage = title;
    progress = 0;
    _current = newPipeline();
    notifyListeners();
    try {
      final r = await job(_current!);
      // درايف ممكن يكون حفظ رقم المجلد
      await _prefs.setString('settings', jsonEncode(settings.toJson()));
      return r;
    } catch (e) {
      log('❌ $e');
      return null;
    } finally {
      running = false;
      _current = null;
      await refreshProjects();
    }
  }

  void cancel() {
    _current?.cancel();
    log('🛑 عم بلغي...');
  }

  // ---------- التشغيل التلقائي ----------
  void _scheduleAuto({bool initial = false}) {
    _autoTimer?.cancel();
    nextAutoRun = null;
    if (!settings.autoRunEnabled) return;
    final every = Duration(hours: settings.autoRunHours.clamp(1, 168));
    var next = (lastAutoRun ?? DateTime.now().subtract(every)).add(every);
    if (initial && settings.autoRunOnStart) next = DateTime.now().add(const Duration(seconds: 20));
    if (next.isBefore(DateTime.now())) next = DateTime.now().add(const Duration(seconds: 30));
    nextAutoRun = next;
    _autoTimer = Timer(next.difference(DateTime.now()), () async {
      await autoRunNow();
      _scheduleAuto();
    });
  }

  Future<void> autoRunNow({String? topic}) async {
    lastAutoRun = DateTime.now();
    await _prefs.setString('lastAutoRun', lastAutoRun!.toIso8601String());
    final topics = settings.topics.isEmpty ? ['ترند اليوم'] : settings.topics;
    final t = topic ?? topics[(DateTime.now().day) % topics.length];
    await run('تشغيل تلقائي', (p) => p.runAuto(topic: t));
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }
}
