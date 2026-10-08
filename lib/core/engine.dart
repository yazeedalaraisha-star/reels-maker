// واجهة تشغيل ffmpeg. بالتطبيق بنستخدم ffmpeg_kit، وبالاختبارات من سطر
// الأوامر بنستخدم ffmpeg المثبت على الجهاز. هيك منطق المونتاج كله Dart صافي.
import 'dart:convert';
import 'dart:io';

typedef LogFn = void Function(String message);

abstract class MediaEngine {
  /// يشغّل ffmpeg بالوسائط المعطاة ويرمي استثناء لو فشل.
  Future<void> ffmpeg(List<String> args);

  /// مدة ملف صوت/فيديو بالثواني.
  Future<double> duration(String path);

  /// أبعاد أول مسار فيديو/صورة (عرض، ارتفاع) أو null.
  Future<(int, int)?> dimensions(String path);
}

class MediaEngineException implements Exception {
  final String message;
  final String? log;
  MediaEngineException(this.message, [this.log]);
  @override
  String toString() {
    if (log == null) return message;
    final lines = log!.trim().split('\n');
    final tail = lines.length > 12 ? lines.sublist(lines.length - 12) : lines;
    return '$message\n${tail.join('\n')}';
  }
}

/// محرك يستخدم ffmpeg/ffprobe من نظام التشغيل (للاختبار والتطوير).
class ProcessMediaEngine implements MediaEngine {
  final String ffmpegPath;
  final String ffprobePath;
  ProcessMediaEngine({this.ffmpegPath = 'ffmpeg', this.ffprobePath = 'ffprobe'});

  @override
  Future<void> ffmpeg(List<String> args) async {
    final r = await Process.run(
        ffmpegPath, ['-hide_banner', '-loglevel', 'error', '-y', ...args]);
    if (r.exitCode != 0) {
      throw MediaEngineException('ffmpeg فشل (${r.exitCode})', '${r.stderr}');
    }
  }

  Future<Map<String, dynamic>> _probe(String path) async {
    final r = await Process.run(ffprobePath, [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      path
    ]);
    if (r.exitCode != 0) {
      throw MediaEngineException('ffprobe فشل', '${r.stderr}');
    }
    return jsonDecode(r.stdout as String) as Map<String, dynamic>;
  }

  @override
  Future<double> duration(String path) async {
    final j = await _probe(path);
    return double.tryParse('${j['format']?['duration']}') ?? 0;
  }

  @override
  Future<(int, int)?> dimensions(String path) async {
    final j = await _probe(path);
    for (final s in (j['streams'] as List? ?? [])) {
      if (s['codec_type'] == 'video') {
        return ((s['width'] as num).toInt(), (s['height'] as num).toInt());
      }
    }
    return null;
  }
}
