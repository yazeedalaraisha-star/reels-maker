// تجربة كاملة بدون مفاتيح: dart run tool/e2e.dart <مجلد>
// بتفحص كل خدمة مجانية لحالها، وبعدين بتعمل ريل كامل من التريند.
import 'dart:io';

import 'package:reels_maker/core/engine.dart';
import 'package:reels_maker/core/settings.dart';
import 'package:reels_maker/services/free_tts.dart';
import 'package:reels_maker/services/media.dart';
import 'package:reels_maker/services/pipeline.dart';
import 'package:reels_maker/services/script_writer.dart';
import 'package:reels_maker/services/trends.dart';

Future<void> check(String name, Future<String> Function() f) async {
  final sw = Stopwatch()..start();
  try {
    final r = await f();
    stdout.writeln('✅ $name (${sw.elapsedMilliseconds}ms): $r');
  } catch (e) {
    stdout.writeln('❌ $name (${sw.elapsedMilliseconds}ms): $e');
  }
}

Future<void> main(List<String> args) async {
  final dir = Directory(args.isNotEmpty ? args.first : 'e2e_out')..createSync(recursive: true);
  final s = AppSettings(quality: '720', reelsPerRun: 1, targetSeconds: 25);
  void log(String m) => stdout.writeln('   $m');

  await check('Edge TTS', () async {
    final b = await EdgeTts.synthesize('يا هلا والله، هاد اختبار للصوت المجاني', 'ar-SA-HamedNeural');
    await File('${dir.path}/edge.mp3').writeAsBytes(b);
    return '${b.length} bytes';
  });
  await check('Google TTS', () async => '${(await GoogleTts.synthesize('مرحبا هذا اختبار')).length} bytes');
  final writer = ScriptWriter(s, log);
  await check('Free LLM', () async {
    final t = await writer.freeLlm('رد بكلمة وحدة.', 'قول: تمام', json: false);
    return t.length > 80 ? t.substring(0, 80) : t;
  });
  final media = MediaService(s, log);
  await check('Pollinations image', () async => '${await media.forScene('desert sunset camel', dir.path, 90)}');
  s.mediaProvider = MediaProvider.openverse;
  await check('Openverse', () async => '${await media.forScene('mountain lake', dir.path, 91)}');
  s.mediaProvider = MediaProvider.freeAi;
  final trends = TrendsService(s, log);
  await check('Google Trends', () async => '${(await trends.googleTrends()).take(3).map((e) => e.title).toList()}');
  await check('Google News', () async => '${(await trends.googleNews()).length} items');
  await check('Reddit', () async => '${(await trends.reddit('todayilearned')).length} items');

  stdout.writeln('\n━━ Full pipeline ━━');
  final p = Pipeline(
    settings: s,
    engine: ProcessMediaEngine(),
    store: ProjectStore('${dir.path}/data'),
    fontsDir: '${Directory.current.path}/assets/fonts',
    outputDir: '${dir.path}/out',
    log: log,
  );
  final reels = await p.runAuto(topic: 'ترند اليوم');
  for (final r in reels) {
    stdout.writeln('🎬 ${r.title} → ${r.outputPath}');
    for (final sc in r.scenes) {
      stdout.writeln('   - ${sc.narration} | media=${sc.mediaPath != null} audio=${sc.audioDuration}');
    }
  }
  if (reels.isEmpty) exitCode = 1;
}
