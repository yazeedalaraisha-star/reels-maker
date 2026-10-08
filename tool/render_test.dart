// اختبار سريع للمونتاج من سطر الأوامر: dart run tool/render_test.dart <workdir>
import 'dart:io';
import 'package:reels_maker/core/engine.dart';
import 'package:reels_maker/core/models.dart';
import 'package:reels_maker/core/settings.dart';
import 'package:reels_maker/services/renderer.dart';

Future<void> main(List<String> args) async {
  final dir = args.isNotEmpty ? args.first : Directory.systemTemp.createTempSync('reel').path;
  final s = AppSettings(watermark: '@reels_maker', quality: args.length > 1 ? args[1] : '720');
  final project = ReelProject(
    id: 'test',
    title: 'اختبار',
    hook: 'شو صار اليوم؟!',
    caption: 'تجربة',
    hashtags: ['ترند', 'السعودية'],
    cta: 'تابعنا للمزيد',
    styleId: args.length > 2 ? args[2] : 'neon',
    scenes: [
      Scene(narration: 'يا جماعة هاد الخبر قلب السوشال ميديا كلها اليوم', onScreen: 'خبر عاجل', highlights: ['السوشال']),
      Scene(narration: 'والكل صار يحكي عنه بكل مكان وبكل لغة', mediaPath: '$dir/img.jpg', audioPath: '$dir/a0.wav', audioDuration: 3.2),
      Scene(narration: 'خلينا نشوف شو القصة بالزبط من البداية', mediaPath: '$dir/vid.mp4', audioPath: '$dir/a1.wav', audioDuration: 4.1, highlights: ['القصة']),
    ],
  );
  final r = Renderer(engine: ProcessMediaEngine(), settings: s, fontsDir: '${Directory.current.path}/assets/fonts', log: print, seed: 1);
  final res = await r.render(project, dir, '$dir/out');
  print('OK ${res.video} ${res.duration}');
}
