// خط الإنتاج الكامل: تريند ← سكربت ← صوت ← مقاطع ← مونتاج ← درايف.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/engine.dart';
import '../core/models.dart';
import '../core/settings.dart';
import 'drive.dart';
import 'media.dart';
import 'renderer.dart';
import 'script_writer.dart';
import 'trends.dart';
import 'tts.dart';

class ProjectStore {
  final String root; // مجلد بيانات التطبيق
  ProjectStore(this.root);

  Directory get projectsDir => Directory(p.join(root, 'projects'))..createSync(recursive: true);
  String workDir(String id) => (Directory(p.join(projectsDir.path, id))..createSync(recursive: true)).path;

  Future<void> save(ReelProject r) async {
    await File(p.join(workDir(r.id), 'project.json')).writeAsString(r.encode());
  }

  Future<List<ReelProject>> all() async {
    final out = <ReelProject>[];
    for (final d in projectsDir.listSync().whereType<Directory>()) {
      final f = File(p.join(d.path, 'project.json'));
      if (!f.existsSync()) continue;
      try {
        out.add(ReelProject.fromJson(jsonDecode(await f.readAsString())));
      } catch (_) {}
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> delete(String id) async {
    final d = Directory(p.join(projectsDir.path, id));
    if (d.existsSync()) await d.delete(recursive: true);
  }
}

class Pipeline {
  final AppSettings settings;
  final MediaEngine engine;
  final ProjectStore store;
  final String fontsDir;
  final String outputDir;
  final LogFn log;
  final DeviceTtsFn? deviceTts;
  final void Function(String stage, double progress)? onStage;

  late final trends = TrendsService(settings, log);
  late final writer = ScriptWriter(settings, log);
  late final tts = TtsService(settings, log, deviceTts: deviceTts);
  late final media = MediaService(settings, log);
  late final drive = DriveService(settings, log);

  bool _cancel = false;
  void cancel() => _cancel = true;

  Pipeline({
    required this.settings,
    required this.engine,
    required this.store,
    required this.fontsDir,
    required this.outputDir,
    required this.log,
    this.deviceTts,
    this.onStage,
  });

  void _check() {
    if (_cancel) throw Exception('انلغت العملية');
  }

  /// تشغيلة تلقائية كاملة: بتطلع [settings.reelsPerRun] ريلز عن الموضوع.
  Future<List<ReelProject>> runAuto({String? topic, List<TrendItem>? picked}) async {
    _cancel = false;
    final t = (topic == null || topic.trim().isEmpty)
        ? (settings.topics.isEmpty ? 'ترند اليوم' : settings.topics.first)
        : topic;
    onStage?.call('جلب التريند', 0.02);
    log('🔎 بدور على التريند: $t');
    final items = picked ?? await trends.fetchAll(topic: t);
    _check();
    if (items.isEmpty) {
      log('⚠️ ما لقيت تريند جاهز، رح أكتب عن الموضوع مباشرة');
    }
    final previous = (await store.all()).take(40).map((r) => r.title).toList();
    onStage?.call('كتابة السكربت', 0.08);
    final reels = await writer.fromTrends(items, t,
        count: picked != null ? picked.length.clamp(1, 10) : null, avoidTitles: previous);
    return produceAll(reels);
  }

  Future<List<ReelProject>> runIdea(String idea, {int count = 1}) async {
    _cancel = false;
    onStage?.call('كتابة السكربت', 0.05);
    final reels = await writer.fromIdea(idea, count: count);
    return produceAll(reels);
  }

  Future<List<ReelProject>> produceAll(List<ReelProject> reels) async {
    final done = <ReelProject>[];
    for (var i = 0; i < reels.length; i++) {
      _check();
      final base = 0.1 + 0.9 * i / reels.length;
      final span = 0.9 / reels.length;
      log('━━━━━━ ريل ${i + 1}/${reels.length}: ${reels[i].title} ━━━━━━');
      try {
        done.add(await produce(reels[i], progressBase: base, progressSpan: span));
      } catch (e) {
        reels[i].status = ReelStatus.failed;
        reels[i].error = '$e';
        await store.save(reels[i]);
        log('❌ فشل الريل "${reels[i].title}": $e');
        if (_cancel) rethrow;
      }
    }
    onStage?.call('خلصنا', 1);
    return done;
  }

  /// يجهز الصوت والمقاطع (اللي ناقص بس) ويعمل المونتاج ويرفع.
  Future<ReelProject> produce(ReelProject r,
      {double progressBase = 0, double progressSpan = 1, bool upload = true}) async {
    void stage(String s, double f) => onStage?.call(s, progressBase + progressSpan * f);
    final dir = store.workDir(r.id);
    await store.save(r);

    // 1) التعليق الصوتي
    stage('التعليق الصوتي', 0.05);
    for (var i = 0; i < r.scenes.length; i++) {
      _check();
      final s = r.scenes[i];
      if (s.audioPath != null && File(s.audioPath!).existsSync()) continue;
      log('🎙️ صوت المشهد ${i + 1}/${r.scenes.length}');
      final path = await tts.synthesize(s.narration, voiceFileBase(dir, i));
      if (path == null) {
        log('⚠️ ما في صوت للمشهد ${i + 1}، رح يطلع بكابشن بس');
        s.audioPath = null;
        s.audioDuration = null;
        continue;
      }
      s.audioPath = path;
      try {
        s.audioDuration = await engine.duration(path);
      } catch (_) {}
    }
    await store.save(r);

    // 2) المقاطع
    stage('جلب المقاطع', 0.3);
    for (var i = 0; i < r.scenes.length; i++) {
      _check();
      final s = r.scenes[i];
      if (s.mediaPath != null && File(s.mediaPath!).existsSync()) continue;
      s.mediaPath = await media.forScene(s.searchQuery, dir, i,
          fallbackQuery: r.scenes.first.searchQuery);
    }
    await store.save(r);

    // 3) المونتاج
    stage('المونتاج', 0.45);
    r.status = ReelStatus.rendering;
    await store.save(r);
    final renderer = Renderer(engine: engine, settings: settings, fontsDir: fontsDir, log: log);
    final res = await renderer.render(r, dir, outputDir,
        onProgress: (f) => stage('المونتاج', 0.45 + 0.45 * f));
    r.outputPath = res.video;
    r.thumbnailPath = res.thumbnail;
    r.status = ReelStatus.rendered;
    r.error = null;
    await store.save(r);

    // 4) نسخة لمجلد Google Drive على الكمبيوتر (بدون ربط)
    final sync = settings.driveSyncFolder;
    if (sync.isNotEmpty && Directory(sync).existsSync()) {
      try {
        for (final f in [res.video, p.setExtension(res.video, '.txt')]) {
          if (File(f).existsSync()) await File(f).copy(p.join(sync, p.basename(f)));
        }
        log('☁️ انحفظ بمجلد Google Drive: $sync');
        if (r.status != ReelStatus.uploaded) {
          r.status = ReelStatus.uploaded;
          await store.save(r);
        }
      } catch (e) {
        log('⚠️ ما قدرت أنسخ لمجلد درايف: $e');
      }
    }

    // 5) درايف (ربط مباشر)
    if (upload && settings.autoUpload && drive.isConnected) {
      stage('الرفع على درايف', 0.92);
      try {
        await uploadToDrive(r);
      } catch (e) {
        log('⚠️ الرفع على درايف فشل: $e');
      }
    }
    stage('جاهز', 1);
    return r;
  }

  Future<void> uploadToDrive(ReelProject r) async {
    if (r.outputPath == null) throw Exception('الريل لسا ما انعمل');
    final (id, link) = await drive.upload(r.outputPath!, description: r.postText());
    final txt = p.setExtension(r.outputPath!, '.txt');
    if (File(txt).existsSync()) {
      try {
        await drive.upload(txt);
      } catch (_) {}
    }
    r.driveFileId = id;
    r.driveLink = link;
    r.status = ReelStatus.uploaded;
    await store.save(r);
  }
}
