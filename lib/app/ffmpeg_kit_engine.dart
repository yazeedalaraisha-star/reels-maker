// تشغيل ffmpeg جوا التطبيق (ويندوز وأندرويد) عن طريق ffmpeg_kit.
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../core/engine.dart';

class FfmpegKitEngine implements MediaEngine {
  static Future<void> init(String fontsDir) async {
    try {
      await FFmpegKitConfig.setFontDirectory(fontsDir);
    } catch (_) {}
  }

  @override
  Future<void> ffmpeg(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments(
        ['-hide_banner', '-y', ...args]);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      throw MediaEngineException('ffmpeg فشل (${rc?.getValue()})', logs);
    }
  }

  @override
  Future<double> duration(String path) async {
    final s = await FFprobeKit.getMediaInformation(path);
    final info = s.getMediaInformation();
    return double.tryParse(info?.getDuration() ?? '') ?? 0;
  }

  @override
  Future<(int, int)?> dimensions(String path) async {
    final s = await FFprobeKit.getMediaInformation(path);
    final info = s.getMediaInformation();
    if (info == null) return null;
    for (final st in info.getStreams()) {
      if (st.getType() == 'video') {
        final w = st.getWidth(), h = st.getHeight();
        if (w != null && h != null) return (w, h);
      }
    }
    return null;
  }
}
