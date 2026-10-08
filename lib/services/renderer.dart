// محرك المونتاج: يحول مشروع الريل (مشاهد + صوت + مقاطع) لفيديو عمودي
// جاهز بالموشن جرافيك والكابشن والموسيقى، باستخدام ffmpeg.
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../core/engine.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/styles.dart';
import 'captions.dart';

const _imageExt = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'};
const _transitionSec = 0.45;

bool isImageFile(String path) =>
    _imageExt.contains(p.extension(path).toLowerCase());

/// تهريب مسار لاستخدامه داخل فلتر ffmpeg (مهم لمسارات ويندوز C:\...).
String filterPath(String path) => path
    .replaceAll('\\', '/')
    .replaceAll(':', '\\:')
    .replaceAll("'", "\\'");

class RenderResult {
  final String video;
  final String thumbnail;
  final String srt;
  final double duration;
  RenderResult(this.video, this.thumbnail, this.srt, this.duration);
}

class Renderer {
  final MediaEngine engine;
  final AppSettings settings;
  final String fontsDir;
  final LogFn log;
  final Random _rnd;

  Renderer({
    required this.engine,
    required this.settings,
    required this.fontsDir,
    required this.log,
    int? seed,
  }) : _rnd = Random(seed);

  int get W => settings.width;
  int get H => settings.height;

  /// مدة كل مشهد: الصوت + نفَس صغير، أو تقدير من طول النص.
  double sceneDuration(Scene s) {
    if (s.durationOverride != null && s.durationOverride! > 0.5) {
      return s.durationOverride!;
    }
    if (s.audioDuration != null && s.audioDuration! > 0.3) {
      return s.audioDuration! + 0.3;
    }
    final words = s.narration.split(RegExp(r'\s+')).length;
    return max(2.5, words / 2.6);
  }

  List<String> _x264([String crf = '20', String preset = 'veryfast']) => [
        '-c:v',
        'libx264',
        '-preset',
        preset,
        '-crf',
        crf,
        '-pix_fmt',
        'yuv420p',
        '-r',
        '30',
      ];

  String _gradeChain(ReelStyle st) {
    final f = <String>[st.grade];
    if (st.vignette) f.add('vignette=PI/5');
    if (st.grain) f.add('noise=alls=7:allf=t');
    return f.join(',');
  }

  /// يجهز مقطع مشهد واحد بطول محدد وبالقياس العمودي.
  Future<String> _sceneClip(
      Scene s, int index, double len, ReelStyle st, String dir) async {
    final out = p.join(dir, 'clip_$index.mp4');
    final grade = _gradeChain(st);
    final frames = (len * 30).ceil();
    final media = s.mediaPath;

    if (media != null && File(media).existsSync() && isImageFile(media)) {
      // صورة: حركة Ken Burns (زوم أو تحريك)
      final zw = (W * 1.3).round(), zh = (H * 1.3).round();
      final step = (0.22 / frames).toStringAsFixed(6);
      final mode = _rnd.nextInt(3);
      final zoom = switch (mode) {
        0 => "z='min(zoom+$step,1.22)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'",
        1 => "z='if(eq(on,0),1.22,max(zoom-$step,1.0))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'",
        _ => "z='1.15':x='(iw-iw/zoom)*on/$frames':y='ih/2-(ih/zoom/2)'",
      };
      await engine.ffmpeg([
        '-i', media,
        '-filter_complex',
        '[0:v]scale=$zw:$zh:force_original_aspect_ratio=increase,crop=$zw:$zh,setsar=1,'
            'zoompan=$zoom:d=$frames:s=${W}x$H:fps=30,$grade,format=yuv420p[v]',
        '-map', '[v]', '-frames:v', '$frames', '-an', ..._x264(), out,
      ]);
      return out;
    }

    if (media != null && File(media).existsSync()) {
      // فيديو: لو أفقي منعمل خلفية مموهة، لو عمودي بنقص عليه
      final dim = await engine.dimensions(media);
      final portrait = dim == null || dim.$2 >= dim.$1 * 1.2;
      final fit = portrait
          ? '[0:v]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,setsar=1[f]'
          : '[0:v]split=2[a][b];[a]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,boxblur=24:2,eq=brightness=-0.08[bg];'
              '[b]scale=$W:-2,setsar=1[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[f]';
      await engine.ffmpeg([
        '-stream_loop', '-1', '-i', media,
        '-filter_complex', '$fit;[f]fps=30,$grade,format=yuv420p[v]',
        '-map', '[v]', '-t', len.toStringAsFixed(3), '-an', ..._x264(), out,
      ]);
      return out;
    }

    // بدون مقاطع: خلفية متدرجة متحركة
    final g = st.gradient;
    final c = List.generate(3, (i) => '0x${g[i % g.length]}');
    await engine.ffmpeg([
      '-f', 'lavfi',
      '-i',
      'gradients=s=${W}x$H:d=${len.toStringAsFixed(3)}:speed=0.012:c0=${c[0]}:c1=${c[1]}:c2=${c[2]}:nb_colors=3:r=30:seed=${_rnd.nextInt(9999)}',
      '-vf', '$grade,format=yuv420p',
      '-t', len.toStringAsFixed(3), '-an', ..._x264(), out,
    ]);
    return out;
  }

  /// يدمج المقاطع بانتقالات xfade بحيث تضل متزامنة مع الصوت.
  Future<String> _joinClips(
      List<String> clips, List<double> durs, ReelStyle st, String dir) async {
    final out = p.join(dir, 'joined.mp4');
    if (clips.length == 1) {
      await File(clips.first).copy(out);
      return out;
    }
    final args = <String>[];
    for (final c in clips) {
      args.addAll(['-i', c]);
    }
    final f = StringBuffer();
    var prev = '[0:v]';
    var offset = 0.0;
    for (var i = 1; i < clips.length; i++) {
      offset += durs[i - 1];
      final tr = st.transitions[_rnd.nextInt(st.transitions.length)];
      final label = i == clips.length - 1 ? '[v]' : '[x$i]';
      f.write(
          '$prev[$i:v]xfade=transition=$tr:duration=$_transitionSec:offset=${offset.toStringAsFixed(3)}$label;');
      prev = label;
    }
    var graph = f.toString();
    graph = graph.substring(0, graph.length - 1);
    await engine.ffmpeg([
      ...args,
      '-filter_complex', graph,
      '-map', '[v]', ..._x264('19'), out,
    ]);
    return out;
  }

  /// يركّب التعليق الصوتي لكل المشاهد على خط زمني واحد.
  Future<String> _voiceTrack(
      List<Scene> scenes, List<double> durs, String dir) async {
    final out = p.join(dir, 'voice.wav');
    final args = <String>[];
    final f = StringBuffer();
    var n = 0;
    final labels = <String>[];
    for (var i = 0; i < scenes.length; i++) {
      final a = scenes[i].audioPath;
      final d = durs[i].toStringAsFixed(3);
      if (a != null && File(a).existsSync()) {
        args.addAll(['-i', a]);
        f.write(
            '[$n:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo,apad=whole_dur=$d,atrim=0:$d,asetpts=PTS-STARTPTS[a$i];');
        n++;
      } else {
        f.write('anullsrc=r=44100:cl=stereo,atrim=0:$d,aformat=sample_fmts=fltp[a$i];');
      }
      labels.add('[a$i]');
    }
    f.write('${labels.join()}concat=n=${scenes.length}:v=0:a=1[out]');
    await engine.ffmpeg([
      ...args,
      '-filter_complex', f.toString(),
      '-map', '[out]', '-c:a', 'pcm_s16le', out,
    ]);
    return out;
  }

  String? _pickMusic(ReelProject project) {
    if (project.musicPath != null && File(project.musicPath!).existsSync()) {
      return project.musicPath;
    }
    final folder = settings.musicFolder;
    if (folder.isEmpty || !Directory(folder).existsSync()) return null;
    final files = Directory(folder)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => {'.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'}
            .contains(p.extension(f.path).toLowerCase()))
        .toList();
    if (files.isEmpty) return null;
    return files[_rnd.nextInt(files.length)].path;
  }

  /// موسيقى خلفية بسيطة مولدة (Pad هادي) لما ما يكون في ملفات موسيقى.
  String _generatedMusicSource(double total) {
    final chords = [
      [220.0, 277.18, 329.63],
      [196.0, 246.94, 293.66],
      [174.61, 220.0, 261.63],
      [196.0, 246.94, 311.13],
    ];
    final ch = chords[_rnd.nextInt(chords.length)];
    final expr = ch
        .map((f) =>
            '0.05*sin(2*PI*$f*t)*(0.7+0.3*sin(2*PI*0.2*t))+0.02*sin(2*PI*${f * 2}*t)')
        .join('+');
    return "aevalsrc='$expr':s=44100:d=${total.toStringAsFixed(2)}";
  }

  Future<RenderResult> render(ReelProject project, String workDir,
      String outDir, {void Function(double)? onProgress}) async {
    final st = styleById(project.styleId);
    final dir = Directory(p.join(workDir, 'render'))..createSync(recursive: true);
    Directory(outDir).createSync(recursive: true);
    final scenes = project.scenes.where((s) => s.narration.trim().isNotEmpty).toList();
    if (scenes.isEmpty) throw MediaEngineException('ما في مشاهد بالريل');

    final durs = scenes.map(sceneDuration).toList();
    final total = durs.fold<double>(0, (a, b) => a + b);
    log('⏱️ مدة الريل: ${total.toStringAsFixed(1)} ثانية، ${scenes.length} مشاهد');

    // 1) مقاطع المشاهد
    final clips = <String>[];
    for (var i = 0; i < scenes.length; i++) {
      final len = durs[i] + (i < scenes.length - 1 ? _transitionSec : 0);
      log('🎬 تجهيز المشهد ${i + 1}/${scenes.length}');
      try {
        clips.add(await _sceneClip(scenes[i], i, len, st, dir.path));
      } catch (e) {
        // لو المقطع خربان منرجع لخلفية متدرجة بدل ما يوقف كل شي
        log('⚠️ مشكلة بمقطع المشهد ${i + 1}، رح أستخدم خلفية متحركة: $e');
        final saved = scenes[i].mediaPath;
        scenes[i].mediaPath = null;
        clips.add(await _sceneClip(scenes[i], i, len, st, dir.path));
        scenes[i].mediaPath = saved;
      }
      onProgress?.call(0.6 * (i + 1) / scenes.length);
    }

    // 2) دمج بانتقالات
    log('🔀 دمج المشاهد بانتقالات');
    final joined = await _joinClips(clips, durs, st, dir.path);
    onProgress?.call(0.7);

    // 3) الصوت
    log('🎙️ تركيب التعليق الصوتي');
    final voice = await _voiceTrack(scenes, durs, dir.path);

    // 4) الكابشن والموشن جرافيك
    final timed = <TimedScene>[];
    var t = 0.0;
    for (var i = 0; i < scenes.length; i++) {
      timed.add(TimedScene(
          narration: scenes[i].narration,
          onScreen: scenes[i].onScreen,
          highlights: scenes[i].highlights,
          start: t,
          duration: durs[i]));
      t += durs[i];
    }
    final assFile = File(p.join(dir.path, 'captions.ass'));
    await assFile.writeAsString(buildAss(
        timed,
        CaptionOptions(
          width: W,
          height: H,
          style: st,
          hook: project.hook,
          cta: project.cta,
          watermark: settings.watermark,
          showHook: settings.showHook,
          showCta: settings.showCta,
          karaoke: settings.karaokeCaptions,
          totalDuration: total,
        )));
    final safeName = _safeFileName(project.title.isEmpty ? project.id : project.title);
    final srtPath = p.join(outDir, '$safeName.srt');
    await File(srtPath).writeAsString(buildSrt(timed));

    // 5) التركيب النهائي
    log('✨ الإخراج النهائي (موشن جرافيك + موسيقى)');
    final music = _pickMusic(project);
    final outPath = p.join(outDir, '$safeName.mp4');
    final totalS = total.toStringAsFixed(3);

    List<String> finalArgs({required bool captions}) {
      final args = <String>['-i', joined, '-i', voice];
      if (music != null) {
        args.addAll(['-stream_loop', '-1', '-i', music]);
      } else if (settings.generatedMusic) {
        args.addAll(['-f', 'lavfi', '-i', _generatedMusicSource(total)]);
      }
      final hasMusic = music != null || settings.generatedMusic;
      final g = StringBuffer();
      var v = '[0:v]';
      if (captions) {
        g.write(
            "${v}ass=filename='${filterPath(assFile.path)}':fontsdir='${filterPath(fontsDir)}'[vs];");
        v = '[vs]';
      }
      if (settings.showProgressBar) {
        final bh = max(6, (H / 190).round());
        g.write(
            'color=c=0x${st.highlightColor}:s=${W}x$bh:r=30:d=$totalS[bar];$v[bar]overlay=x=\'-w+w*t/$totalS\':y=H-h:shortest=1[vb];');
        v = '[vb]';
      }
      g.write('${v}format=yuv420p[vout];');
      final vol = settings.musicVolume.toStringAsFixed(2);
      if (hasMusic) {
        g.write(
            '[2:a]aresample=44100,aformat=channel_layouts=stereo,volume=$vol,afade=t=in:d=1,afade=t=out:st=${max(0, total - 1.8).toStringAsFixed(2)}:d=1.8[m];');
        if (settings.duckMusic) {
          g.write(
              '[1:a]asplit=2[va][vk];[m][vk]sidechaincompress=threshold=0.02:ratio=6:attack=15:release=350[md];[va][md]amix=inputs=2:duration=first:normalize=0[mix];');
        } else {
          g.write('[1:a][m]amix=inputs=2:duration=first:normalize=0[mix];');
        }
        g.write('[mix]loudnorm=I=-14:TP=-1.5:LRA=11[aout]');
      } else {
        g.write('[1:a]loudnorm=I=-14:TP=-1.5:LRA=11[aout]');
      }
      return [
        ...args,
        '-filter_complex', g.toString(),
        '-map', '[vout]', '-map', '[aout]',
        '-t', totalS,
        ..._x264('21', 'medium'),
        '-c:a', 'aac', '-b:a', '192k', '-ar', '44100',
        '-movflags', '+faststart',
        outPath,
      ];
    }

    try {
      await engine.ffmpeg(finalArgs(captions: true));
    } on MediaEngineException catch (e) {
      log('⚠️ الكابشن ما اشتغل على هالجهاز، رح أطلع الفيديو بدونه: $e');
      await engine.ffmpeg(finalArgs(captions: false));
    }
    onProgress?.call(0.95);

    // 6) صورة الغلاف
    final thumb = p.join(outDir, '$safeName.jpg');
    try {
      await engine.ffmpeg([
        '-ss', min(1.0, total / 3).toStringAsFixed(2), '-i', outPath,
        '-frames:v', '1', '-q:v', '3', thumb,
      ]);
    } catch (_) {}

    // 7) نص المنشور
    await File(p.join(outDir, '$safeName.txt')).writeAsString(project.postText());
    onProgress?.call(1);
    log('✅ الريل جاهز: $outPath');
    return RenderResult(outPath, thumb, srtPath, total);
  }
}

String _safeFileName(String s) {
  var n = s.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').trim();
  n = n.replaceAll(RegExp(r'\s+'), '_');
  if (n.length > 60) n = n.substring(0, 60);
  final stamp = DateTime.now();
  final ts =
      '${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}_${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}${stamp.second.toString().padLeft(2, '0')}';
  return n.isEmpty ? 'reel_$ts' : '${n}_$ts';
}
