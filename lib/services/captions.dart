// يبني ملف ترجمة ASS فيه كل الموشن جرافيك: عنوان الافتتاح، الكابشن
// المتحرك كلمة بكلمة، عناوين المشاهد، والعلامة المائية ونهاية الفيديو.
import '../core/styles.dart';

class TimedScene {
  final String narration;
  final String onScreen;
  final List<String> highlights;
  final double start;
  final double duration;
  TimedScene(
      {required this.narration,
      required this.onScreen,
      required this.highlights,
      required this.start,
      required this.duration});
}

class CaptionOptions {
  final int width;
  final int height;
  final ReelStyle style;
  final String hook;
  final String cta;
  final String watermark;
  final bool showHook;
  final bool showCta;
  final bool karaoke;
  final double totalDuration;
  CaptionOptions({
    required this.width,
    required this.height,
    required this.style,
    required this.hook,
    required this.cta,
    required this.watermark,
    required this.showHook,
    required this.showCta,
    required this.karaoke,
    required this.totalDuration,
  });
}

/// لون ASS بصيغة &HAABBGGRR من RRGGBB.
String assColor(String rrggbb, [int alpha = 0]) {
  final c = rrggbb.replaceAll('#', '').padLeft(6, '0');
  final r = c.substring(0, 2), g = c.substring(2, 4), b = c.substring(4, 6);
  return '&H${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}$b$g$r'
      .toUpperCase();
}

String assTime(double t) {
  if (t < 0) t = 0;
  final cs = (t * 100).round();
  final h = cs ~/ 360000;
  final m = (cs ~/ 6000) % 60;
  final s = (cs ~/ 100) % 60;
  final c = cs % 100;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${c.toString().padLeft(2, '0')}';
}

String _escape(String s) => s
    .replaceAll('\\', '')
    .replaceAll('{', '(')
    .replaceAll('}', ')')
    .replaceAll('\n', ' ')
    .trim();

/// يقسم النص لمجموعات قصيرة (2-4 كلمات) مناسبة للريلز.
List<List<String>> chunkWords(String text, {int maxWords = 3, int maxChars = 22}) {
  final words =
      text.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
  final chunks = <List<String>>[];
  var cur = <String>[];
  var len = 0;
  for (final w in words) {
    final endsSentence = RegExp(r'[.!?؟،,:]$').hasMatch(w);
    if (cur.isNotEmpty && (cur.length >= maxWords || len + w.length > maxChars)) {
      chunks.add(cur);
      cur = [];
      len = 0;
    }
    cur.add(w);
    len += w.length + 1;
    if (endsSentence) {
      chunks.add(cur);
      cur = [];
      len = 0;
    }
  }
  if (cur.isNotEmpty) chunks.add(cur);
  return chunks;
}

bool _isHighlight(String word, List<String> highlights) {
  final clean = word.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  if (clean.isEmpty) return false;
  for (final h in highlights) {
    final hc = h.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim();
    if (hc.isEmpty) continue;
    if (hc.split(' ').contains(clean) || clean == hc) return true;
  }
  return false;
}

String buildAss(List<TimedScene> scenes, CaptionOptions o) {
  final st = o.style;
  final w = o.width, h = o.height;
  final k = w / 1080.0; // معامل التكبير حسب الدقة
  int px(num v) => (v * k).round();
  final capY = (h * (1 - st.captionY)).round();
  final white = assColor(st.captionColor);
  final hi = assColor(st.highlightColor);

  final b = StringBuffer()
    ..writeln('[Script Info]')
    ..writeln('ScriptType: v4.00+')
    ..writeln('PlayResX: $w')
    ..writeln('PlayResY: $h')
    ..writeln('WrapStyle: 0')
    ..writeln('ScaledBorderAndShadow: yes')
    ..writeln()
    ..writeln('[V4+ Styles]')
    ..writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
  // Encoding = -1 مهم: يخلي libass يرتب النص العربي صح حتى لو فيه تلوين.
  b.writeln(
      'Style: Cap,${st.captionFont},${px(st.captionSize)},$white,$hi,${assColor(st.outlineColor)},${assColor('000000', 0x60)},0,0,0,0,100,100,0,0,1,${px(7)},${px(3)},2,${px(70)},${px(70)},$capY,-1');
  b.writeln(
      'Style: Hook,Tajawal Black,${px(96)},${assColor(st.hookColor)},$white,${assColor(st.hookBox)},${assColor('000000', 0x80)},0,0,0,0,100,100,0,0,3,${px(26)},0,5,${px(70)},${px(70)},0,-1');
  b.writeln(
      'Style: Tag,Tajawal ExtraBold,${px(58)},${assColor('FFFFFF')},$white,${assColor(st.hookBox)},${assColor('000000', 0x80)},0,0,0,0,100,100,0,0,3,${px(18)},0,8,${px(60)},${px(60)},${px(190)},-1');
  b.writeln(
      'Style: Mark,Tajawal Bold,${px(40)},${assColor('FFFFFF', 0x50)},$white,${assColor('000000', 0x90)},${assColor('000000', 0xA0)},0,0,0,0,100,100,0,0,1,${px(2)},0,9,${px(40)},${px(40)},${px(60)},-1');
  b.writeln(
      'Style: Cta,Tajawal Black,${px(80)},${assColor('FFFFFF')},$white,${assColor(st.hookBox)},${assColor('000000', 0x80)},0,0,0,0,100,100,0,0,3,${px(22)},0,5,${px(70)},${px(70)},0,-1');
  b
    ..writeln()
    ..writeln('[Events]')
    ..writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

  void ev(int layer, double s, double e, String style, String text) {
    if (e - s < 0.05) return;
    b.writeln('Dialogue: $layer,${assTime(s)},${assTime(e)},$style,,0,0,0,,$text');
  }

  // ---------- عنوان الافتتاح (Hook) ----------
  final hookEnd = o.showHook && o.hook.trim().isNotEmpty
      ? (scenes.isNotEmpty ? scenes.first.duration.clamp(1.6, 3.2) : 2.5)
      : 0.0;
  if (hookEnd > 0) {
    final cx = w ~/ 2, cy = (h * 0.40).round();
    ev(5, 0, hookEnd.toDouble(), 'Hook',
        '{\\an5\\pos($cx,$cy)\\fad(80,220)\\fscx30\\fscy30\\frz-6\\t(0,260,\\fscx108\\fscy108\\frz0)\\t(260,380,\\fscx100\\fscy100)}${_escape(o.hook)}');
  }

  // ---------- الكابشن المتحرك ----------
  for (final sc in scenes) {
    final chunks = chunkWords(sc.narration);
    if (chunks.isEmpty) continue;
    final totalChars =
        chunks.fold<int>(0, (a, c) => a + c.join(' ').length + 3);
    var t = sc.start + 0.05;
    final usable = (sc.duration - 0.15).clamp(0.3, 999.0);
    for (final c in chunks) {
      final share = (c.join(' ').length + 3) / totalChars;
      final d = usable * share;
      final s = t, e = t + d;
      t = e;
      final start = s;
      final anim = switch (st.captionAnim) {
        'slide' =>
          '\\fad(60,60)\\move(${w ~/ 2},${h - capY + px(40)},${w ~/ 2},${h - capY},0,140)',
        'fade' => '\\fad(140,100)',
        'bounce' =>
          '\\fscx60\\fscy60\\t(0,110,\\fscx118\\fscy118)\\t(110,190,\\fscx94\\fscy94)\\t(190,250,\\fscx100\\fscy100)',
        _ =>
          '\\fscx75\\fscy75\\t(0,110,\\fscx112\\fscy112)\\t(110,190,\\fscx100\\fscy100)',
      };
      final pos = st.captionAnim == 'slide' ? '' : '\\an2';
      // لون الكلمة الحالية: لون التمييز، والكلمات المميزة أصلاً بتاخد لون أفتح
      final active_ = hi;
      final accent = o.karaoke ? assColor('FF9F1C') : hi;
      String line(int active) {
        final words = StringBuffer();
        for (var i = 0; i < c.length; i++) {
          final word = _escape(c[i]);
          final colored = _isHighlight(c[i], sc.highlights);
          if (i == active) {
            // الكلمة المقروءة الآن: ملونة. (تغيير الحجم جوا السطر بيخرب ترتيب العربي)
            words.write('{\\c$active_}$word{\\c$white}');
          } else {
            words.write(colored ? '{\\c$accent}$word{\\c$white}' : word);
          }
          if (i < c.length - 1) words.write(' ');
        }
        return words.toString();
      }

      if (o.karaoke && c.length > 1) {
        // كاريوكي: حدث لكل كلمة، الحركة بس على أول وحدة
        final weights = c.map((x) => x.length + 2).toList();
        final wsum = weights.fold<int>(0, (a, x) => a + x);
        var ws = start;
        for (var i = 0; i < c.length; i++) {
          final we = i == c.length - 1 ? e : ws + (e - start) * weights[i] / wsum;
          final a = i == 0 ? anim : '';
          ev(2, ws, we, 'Cap', '{$pos$a}${line(i)}');
          ws = we;
        }
      } else {
        ev(2, start, e, 'Cap', '{$pos$anim}${line(-1)}');
      }
    }

    // عنوان المشهد بالأعلى
    final tag = sc.onScreen.trim();
    if (tag.isNotEmpty) {
      final s = sc.start < hookEnd ? hookEnd : sc.start;
      final e = sc.start + sc.duration - 0.1;
      if (e - s > 0.6) {
        ev(3, s, e, 'Tag',
            '{\\fad(120,150)\\move(${w ~/ 2 + px(220)},${px(190)},${w ~/ 2},${px(190)},0,260)\\an8}${_escape(tag)}');
      }
    }
  }

  // ---------- العلامة المائية ----------
  if (o.watermark.trim().isNotEmpty) {
    ev(1, 0, o.totalDuration, 'Mark', _escape(o.watermark));
  }

  // ---------- نهاية الفيديو ----------
  if (o.showCta && o.cta.trim().isNotEmpty && o.totalDuration > 4) {
    final s = o.totalDuration - 2.2;
    ev(6, s, o.totalDuration, 'Cta',
        '{\\an5\\pos(${w ~/ 2},${(h * 0.42).round()})\\fad(150,0)\\fscx20\\fscy20\\t(0,240,\\fscx106\\fscy106)\\t(240,340,\\fscx100\\fscy100)}${_escape(o.cta)}');
  }
  return b.toString();
}

/// ملف SRT عادي للكابشن (مفيد للرفع على يوتيوب/تيك توك).
String buildSrt(List<TimedScene> scenes) {
  String t(double v) {
    final ms = (v * 1000).round();
    final h = ms ~/ 3600000, m = (ms ~/ 60000) % 60, s = (ms ~/ 1000) % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')},${(ms % 1000).toString().padLeft(3, '0')}';
  }

  final b = StringBuffer();
  var i = 1;
  for (final sc in scenes) {
    final chunks = chunkWords(sc.narration, maxWords: 6, maxChars: 40);
    final total = chunks.fold<int>(0, (a, c) => a + c.join(' ').length + 3);
    var cur = sc.start;
    for (final c in chunks) {
      final d = sc.duration * (c.join(' ').length + 3) / total;
      b
        ..writeln(i++)
        ..writeln('${t(cur)} --> ${t(cur + d)}')
        ..writeln(c.join(' '))
        ..writeln();
      cur += d;
    }
  }
  return b.toString();
}
