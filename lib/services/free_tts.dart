// أصوات مجانية بدون أي مفتاح:
// 1) أصوات مايكروسوفت العصبية (نفس أصوات "القراءة بصوت عالٍ" بمتصفح Edge):
//    فيها سعودي (حامد، زارية) وأردني (تيم، سناء) وغيرهم. جودة عالية جداً.
// 2) صوت Google Translate كاحتياط.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class FreeVoice {
  final String id; // مثل ar-SA-HamedNeural
  final String name;
  final String details;
  const FreeVoice(this.id, this.name, this.details);
}

const freeArabicVoices = <FreeVoice>[
  FreeVoice('ar-SA-HamedNeural', 'حامد', 'سعودي • رجل ⭐'),
  FreeVoice('ar-SA-ZariyahNeural', 'زارية', 'سعودية • امرأة'),
  FreeVoice('ar-JO-TaimNeural', 'تيم', 'أردني • رجل'),
  FreeVoice('ar-JO-SanaNeural', 'سناء', 'أردنية • امرأة'),
  FreeVoice('ar-SY-LaithNeural', 'ليث', 'سوري • رجل'),
  FreeVoice('ar-SY-AmanyNeural', 'أماني', 'سورية • امرأة'),
  FreeVoice('ar-LB-RamiNeural', 'رامي', 'لبناني • رجل'),
  FreeVoice('ar-LB-LaylaNeural', 'ليلى', 'لبنانية • امرأة'),
  FreeVoice('ar-AE-HamdanNeural', 'حمدان', 'إماراتي • رجل'),
  FreeVoice('ar-KW-FahedNeural', 'فهد', 'كويتي • رجل'),
  FreeVoice('ar-EG-ShakirNeural', 'شاكر', 'مصري • رجل'),
  FreeVoice('ar-EG-SalmaNeural', 'سلمى', 'مصرية • امرأة'),
];

class EdgeTts {
  static const _token = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _versions = ['143.0.3650.75', '140.0.3485.14', '130.0.2849.68'];
  static int _clockSkew = 0; // ثواني فرق ساعة الجهاز عن السيرفر

  static String _secMsGec() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + _clockSkew;
    var ticks = now + 11644473600;
    ticks -= ticks % 300;
    final s = '${ticks}0000000$_token'; // بوحدات 100 نانوثانية
    return sha256.convert(ascii.encode(s)).toString().toUpperCase();
  }

  static String _hex(int n) {
    final r = Random.secure();
    return List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  static String _date() {
    final d = DateTime.now().toUtc();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${days[d.weekday - 1]} ${months[d.month - 1]} ${two(d.day)} ${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)} GMT+0000 (Coordinated Universal Time)';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// يحول النص لصوت mp3. [rate] مثل +5% و [pitch] مثل +0Hz.
  static Future<Uint8List> synthesize(String text, String voice,
      {String rate = '+0%', String pitch = '+0Hz'}) async {
    Object? lastError;
    for (final ver in _versions) {
      try {
        return await _once(text, voice, rate, pitch, ver);
      } on WebSocketException catch (e) {
        lastError = e;
        // 403 غالباً بسبب فرق الساعة: نصلحها من تاريخ السيرفر ونجرب
        await _syncClock();
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('صوت مايكروسوفت المجاني فشل: $lastError');
  }

  static Future<void> _syncClock() async {
    try {
      final r = await http
          .head(Uri.parse('https://speech.platform.bing.com/'))
          .timeout(const Duration(seconds: 10));
      final d = r.headers['date'];
      if (d != null) {
        final server = HttpDate.parse(d);
        _clockSkew = server.difference(DateTime.now().toUtc()).inSeconds;
      }
    } catch (_) {}
  }

  static Future<Uint8List> _once(
      String text, String voice, String rate, String pitch, String ver) async {
    final major = ver.split('.').first;
    final url =
        'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1'
        '?TrustedClientToken=$_token&Sec-MS-GEC=${_secMsGec()}&Sec-MS-GEC-Version=1-$ver&ConnectionId=${_hex(32)}';
    final ws = await WebSocket.connect(url, headers: {
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
      'Accept-Language': 'en-US,en;q=0.9',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$major.0.0.0 Safari/537.36 Edg/$major.0.0.0',
      'Cookie': 'muid=${_hex(32).toUpperCase()};',
    }).timeout(const Duration(seconds: 20));

    final audio = BytesBuilder();
    final done = Completer<void>();
    final sub = ws.listen((msg) {
      if (msg is String) {
        if (msg.contains('Path:turn.end') && !done.isCompleted) done.complete();
      } else if (msg is List<int>) {
        final b = Uint8List.fromList(msg);
        if (b.length < 2) return;
        final headerLen = (b[0] << 8) | b[1];
        if (b.length < 2 + headerLen) return;
        final header = ascii.decode(b.sublist(2, 2 + headerLen), allowInvalid: true);
        if (header.contains('Path:audio')) audio.add(b.sublist(2 + headerLen));
      }
    }, onError: (e) {
      if (!done.isCompleted) done.completeError(e);
    }, onDone: () {
      if (!done.isCompleted) done.complete();
    });

    final reqId = _hex(32);
    ws.add('X-Timestamp:${_date()}\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n');
    ws.add('X-RequestId:$reqId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${_date()}Z\r\n'
        'Path:ssml\r\n\r\n'
        "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='ar-SA'>"
        "<voice name='$voice'><prosody pitch='$pitch' rate='$rate' volume='+0%'>${_escape(text)}</prosody></voice></speak>");

    try {
      await done.future.timeout(const Duration(seconds: 60));
    } finally {
      await sub.cancel();
      await ws.close();
    }
    final bytes = audio.toBytes();
    if (bytes.length < 500) throw Exception('ما رجع صوت');
    return bytes;
  }
}

/// صوت Google Translate (احتياط): بيقسم النص لقطع قصيرة ويلزقها.
class GoogleTts {
  static Future<Uint8List> synthesize(String text, {http.Client? client}) async {
    final c = client ?? http.Client();
    final parts = <String>[];
    var cur = '';
    for (final w in text.split(RegExp(r'\s+'))) {
      if ((cur.length + w.length + 1) > 180 && cur.isNotEmpty) {
        parts.add(cur);
        cur = '';
      }
      cur = cur.isEmpty ? w : '$cur $w';
    }
    if (cur.isNotEmpty) parts.add(cur);
    final out = BytesBuilder();
    for (var i = 0; i < parts.length; i++) {
      final u = Uri.parse('https://translate.google.com/translate_tts'
          '?ie=UTF-8&tl=ar&client=tw-ob&total=${parts.length}&idx=$i&textlen=${parts[i].length}&q=${Uri.encodeQueryComponent(parts[i])}');
      final r = await c.get(u, headers: {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://translate.google.com/'});
      if (r.statusCode != 200) throw Exception('Google TTS ${r.statusCode}');
      out.add(r.bodyBytes);
    }
    return out.toBytes();
  }
}
