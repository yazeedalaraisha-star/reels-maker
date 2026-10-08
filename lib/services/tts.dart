// التعليق الصوتي: منصت (عربي/لهجات)، ElevenLabs، Hugging Face، أو صوت الجهاز
// بدون نت. لو المزوّد الأساسي فشل بنجرب البدائل بالترتيب.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/engine.dart';
import '../core/settings.dart';
import 'free_tts.dart';

/// صوت الجهاز (بيتنفذ بطبقة Flutter لأنه بيحتاج plugin على أندرويد).
typedef DeviceTtsFn = Future<String?> Function(String text, String outPathNoExt);

class VoiceInfo {
  final String id;
  final String name;
  final String details;
  final String? previewUrl;
  VoiceInfo(this.id, this.name, this.details, [this.previewUrl]);
}

class TtsService {
  final AppSettings settings;
  final LogFn log;
  final DeviceTtsFn? deviceTts;
  final http.Client _http;
  TtsService(this.settings, this.log, {this.deviceTts, http.Client? client})
      : _http = client ?? http.Client();

  String providerName(TtsProvider p) => switch (p) {
        TtsProvider.edge => 'صوت مجاني (مايكروسوفت)',
        TtsProvider.google => 'صوت Google المجاني',
        TtsProvider.munsit => 'منصت',
        TtsProvider.elevenlabs => 'ElevenLabs',
        TtsProvider.huggingface => 'Hugging Face',
        TtsProvider.device => 'صوت الجهاز',
        TtsProvider.none => 'بدون صوت',
      };

  bool isConfigured(TtsProvider p) => switch (p) {
        TtsProvider.edge || TtsProvider.google => true,
        TtsProvider.munsit =>
          settings.munsitKey.isNotEmpty && settings.munsitVoiceId.isNotEmpty,
        TtsProvider.elevenlabs =>
          settings.elevenKey.isNotEmpty && settings.elevenVoiceId.isNotEmpty,
        TtsProvider.huggingface => settings.hfToken.isNotEmpty,
        TtsProvider.device => deviceTts != null || Platform.isWindows,
        TtsProvider.none => false,
      };

  /// يولد صوت للنص ويرجع مسار الملف، أو null لو كل المزودين فشلوا.
  Future<String?> synthesize(String text, String outPathNoExt) async {
    if (settings.ttsProvider == TtsProvider.none) return null;
    // المجاني دايماً بالآخر كاحتياط، عشان التطبيق يشتغل بدون مفاتيح
    final order = <TtsProvider>{
      settings.ttsProvider,
      ...settings.ttsFallbacks.where((f) => f != TtsProvider.device),
      TtsProvider.edge,
      TtsProvider.google,
      TtsProvider.device,
    }.where((p) => p != TtsProvider.none).toList();
    for (final prov in order) {
      if (!isConfigured(prov)) continue;
      try {
        final path = await _synth(prov, text, outPathNoExt);
        if (path != null && File(path).existsSync() && File(path).lengthSync() > 400) {
          return path;
        }
      } catch (e) {
        log('⚠️ ${providerName(prov)} فشل: $e');
      }
    }
    return null;
  }

  Future<String?> _synth(TtsProvider prov, String text, String out) => switch (prov) {
        TtsProvider.edge => _edge(text, out),
        TtsProvider.google => _google(text, out),
        TtsProvider.munsit => _munsit(text, out),
        TtsProvider.elevenlabs => _eleven(text, out),
        TtsProvider.huggingface => _hf(text, out),
        TtsProvider.device => _device(text, out),
        TtsProvider.none => Future.value(null),
      };

  // ---------------- مجاني ----------------
  Future<String> _edge(String text, String out) async {
    final r = settings.edgeRate;
    final bytes = await EdgeTts.synthesize(text, settings.edgeVoice,
        rate: '${r >= 0 ? '+' : ''}$r%');
    final path = '$out.mp3';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<String> _google(String text, String out) async {
    final bytes = await GoogleTts.synthesize(text, client: _http);
    final path = '$out.mp3';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  // ---------------- منصت ----------------
  Future<String> _munsit(String text, String out) async {
    var t = text.trim();
    // منصت بيطلب 3 كلمات و10 حروف على الأقل
    if (t.split(RegExp(r'\s+')).length < 3 || t.length < 10) t = '$t ... $t';
    final r = await _http
        .post(
          Uri.parse(
              '${settings.munsitBaseUrl}/text-to-speech/${settings.munsitModel}'),
          headers: {
            'x-api-key': settings.munsitKey.trim(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'voice_id': settings.munsitVoiceId,
            'text': t,
            'stability': settings.munsitStability,
            'speed': settings.munsitSpeed,
            'streaming': false,
            'sample_rate': 44100,
            'dialect': settings.munsitDialect,
          }),
        )
        .timeout(const Duration(minutes: 2));
    if (r.statusCode != 200) {
      String msg = r.body;
      try {
        msg = jsonDecode(utf8.decode(r.bodyBytes))['errorMessage'] ?? msg;
      } catch (_) {}
      throw Exception('منصت ${r.statusCode}: $msg');
    }
    final path = '$out.wav';
    await File(path).writeAsBytes(r.bodyBytes);
    return path;
  }

  Future<List<VoiceInfo>> munsitVoices() async {
    final r = await _http.get(Uri.parse('${settings.munsitBaseUrl}/voices'),
        headers: {'x-api-key': settings.munsitKey.trim()});
    if (r.statusCode != 200) throw Exception('منصت ${r.statusCode}: ${r.body}');
    final list = jsonDecode(utf8.decode(r.bodyBytes));
    final items = list is List ? list : (list['voices'] ?? list['data'] ?? []) as List;
    return items.map((v) {
      final dialects = (v['dialect'] as List?)?.join('، ') ?? '';
      final gender = v['gender'] == 'male'
          ? 'رجل'
          : v['gender'] == 'female'
              ? 'امرأة'
              : '';
      return VoiceInfo('${v['voice_id']}', '${v['name'] ?? v['voice_id']}',
          [gender, dialects, v['description'] ?? ''].where((e) => '$e'.isNotEmpty).join(' • '),
          v['sample_url']);
    }).toList();
  }

  // ---------------- ElevenLabs ----------------
  Future<String> _eleven(String text, String out) async {
    final r = await _http
        .post(
          Uri.parse(
              'https://api.elevenlabs.io/v1/text-to-speech/${settings.elevenVoiceId}?output_format=mp3_44100_128'),
          headers: {
            'xi-api-key': settings.elevenKey.trim(),
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': text,
            'model_id': settings.elevenModel,
            'voice_settings': {
              'stability': settings.elevenStability,
              'similarity_boost': 0.75,
              'style': settings.elevenStyle,
              'use_speaker_boost': true,
            },
          }),
        )
        .timeout(const Duration(minutes: 2));
    if (r.statusCode != 200) {
      throw Exception('ElevenLabs ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
    }
    final path = '$out.mp3';
    await File(path).writeAsBytes(r.bodyBytes);
    return path;
  }

  /// أصوات حسابك + بحث بمكتبة الأصوات العامة عن أصوات سعودية/شامية.
  Future<List<VoiceInfo>> elevenVoices({String search = ''}) async {
    final headers = {'xi-api-key': settings.elevenKey.trim()};
    final out = <VoiceInfo>[];
    final mine = await _http.get(
        Uri.parse('https://api.elevenlabs.io/v2/voices?page_size=100'),
        headers: headers);
    if (mine.statusCode == 200) {
      for (final v in (jsonDecode(utf8.decode(mine.bodyBytes))['voices'] as List? ?? [])) {
        final labels = (v['labels'] as Map?)?.values.join('، ') ?? '';
        out.add(VoiceInfo(v['voice_id'], '${v['name']} (حسابك)', labels, v['preview_url']));
      }
    }
    final q = search.isEmpty ? '' : '&search=${Uri.encodeQueryComponent(search)}';
    final shared = await _http.get(
        Uri.parse(
            'https://api.elevenlabs.io/v1/shared-voices?page_size=60&language=ar$q'),
        headers: headers);
    if (shared.statusCode == 200) {
      for (final v in (jsonDecode(utf8.decode(shared.bodyBytes))['voices'] as List? ?? [])) {
        out.add(VoiceInfo(
            v['voice_id'],
            '${v['name']}',
            [v['accent'], v['gender'], v['age'], v['descriptive']]
                .where((e) => e != null && '$e'.isNotEmpty)
                .join(' • '),
            v['preview_url']));
      }
    }
    if (out.isEmpty && mine.statusCode != 200) {
      throw Exception('ElevenLabs ${mine.statusCode}: ${mine.body}');
    }
    return out;
  }

  // ---------------- Hugging Face ----------------
  Future<String> _hf(String text, String out) async {
    final r = await _http
        .post(
          Uri.parse(
              'https://router.huggingface.co/hf-inference/models/${settings.hfTtsModel}'),
          headers: {
            'Authorization': 'Bearer ${settings.hfToken.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'inputs': text}),
        )
        .timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) {
      throw Exception('HF ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
    }
    final ct = r.headers['content-type'] ?? '';
    final ext = ct.contains('wav')
        ? 'wav'
        : ct.contains('mpeg') || ct.contains('mp3')
            ? 'mp3'
            : ct.contains('ogg')
                ? 'ogg'
                : 'flac';
    final path = '$out.$ext';
    await File(path).writeAsBytes(r.bodyBytes);
    return path;
  }

  // ---------------- صوت الجهاز (أوفلاين) ----------------
  Future<String?> _device(String text, String out) async {
    if (deviceTts != null) {
      final r = await deviceTts!(text, out);
      if (r != null) return r;
    }
    if (Platform.isWindows) return _windowsSapi(text, out);
    return null;
  }

  /// ويندوز: نستخدم محرك الكلام المدمج (SAPI) عن طريق PowerShell.
  Future<String?> _windowsSapi(String text, String out) async {
    final path = '$out.wav';
    final txt = File('$out.txt')..writeAsStringSync(text);
    final voice = settings.deviceVoice.replaceAll("'", '');
    final rate = ((settings.deviceRate - 0.5) * 10).round().clamp(-10, 10);
    final script = '''
Add-Type -AssemblyName System.Speech
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$v = '$voice'
if (\$v -ne '') { try { \$s.SelectVoice(\$v) } catch {} } else {
  \$ar = \$s.GetInstalledVoices() | Where-Object { \$_.VoiceInfo.Culture.Name -like 'ar*' } | Select-Object -First 1
  if (\$ar) { \$s.SelectVoice(\$ar.VoiceInfo.Name) }
}
\$s.Rate = $rate
\$s.SetOutputToWaveFile('${path.replaceAll("'", "''")}')
\$s.Speak([IO.File]::ReadAllText('${txt.path.replaceAll("'", "''")}', [Text.Encoding]::UTF8))
\$s.Dispose()
''';
    final ps = File('$out.ps1')..writeAsStringSync(script);
    final r = await Process.run('powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps.path]);
    if (r.exitCode != 0) throw Exception('SAPI: ${r.stderr}');
    return File(path).existsSync() ? path : null;
  }

  /// أسماء أصوات ويندوز المثبتة.
  static Future<List<String>> windowsVoices() async {
    if (!Platform.isWindows) return [];
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      r'Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).GetInstalledVoices() | % { $_.VoiceInfo.Name + " | " + $_.VoiceInfo.Culture.Name }'
    ]);
    return '${r.stdout}'
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

String voiceFileBase(String dir, int index) => p.join(dir, 'voice_$index');
