// تشخيص مؤقت للخدمات المجانية على GitHub Actions.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

void note(String m) => stdout.writeln('::notice::${m.replaceAll('\n', ' ')}');
const token = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
String hex(int n) => List.generate(n, (_) => Random.secure().nextInt(16).toRadixString(16)).join();

String gec() {
  var t = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 11644473600;
  t -= t % 300;
  return sha256.convert(ascii.encode('${t}0000000$token')).toString().toUpperCase();
}

Future<void> edge(String name, {String ver = '143.0.3650.75', bool compress = true, bool enc = false, bool cookie = true, bool order = false}) async {
  final major = ver.split('.').first;
  final base = 'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=$token';
  final url = order
      ? '$base&ConnectionId=${hex(32)}&Sec-MS-GEC=${gec()}&Sec-MS-GEC-Version=1-$ver'
      : '$base&Sec-MS-GEC=${gec()}&Sec-MS-GEC-Version=1-$ver&ConnectionId=${hex(32)}';
  try {
    final ws = await WebSocket.connect(url,
        compression: compress ? CompressionOptions.compressionDefault : CompressionOptions.compressionOff,
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'Accept-Language': 'en-US,en;q=0.9',
          if (enc) 'Accept-Encoding': 'gzip, deflate, br, zstd',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$major.0.0.0 Safari/537.36 Edg/$major.0.0.0',
          if (cookie) 'Cookie': 'muid=${hex(32).toUpperCase()};',
        }).timeout(const Duration(seconds: 20));
    note('✅ edge $name connected');
    await ws.close();
  } catch (e) {
    note('❌ edge $name: ${'$e'.split('was not').last}');
  }
}

Future<void> poll(String name, Map<String, dynamic> body) async {
  try {
    final r = await http.post(Uri.parse('https://text.pollinations.ai/openai'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(minutes: 2));
    note('${r.statusCode == 200 ? '✅' : '❌'} poll $name ${r.statusCode} ${utf8.decode(r.bodyBytes).substring(0, min(160, r.bodyBytes.length ~/ 2))}');
  } catch (e) {
    note('❌ poll $name $e');
  }
}


Map<String, String> hdrs(String major) => {
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
      'Sec-WebSocket-Version': '13',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$major.0.0.0 Safari/537.36 Edg/$major.0.0.0',
      'Accept-Encoding': 'gzip, deflate, br, zstd',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cookie': 'muid=${hex(32).toUpperCase()};',
    };

String q(String ver) =>
    '/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=$token&ConnectionId=${hex(32)}&Sec-MS-GEC=${gec()}&Sec-MS-GEC-Version=1-$ver';

Future<void> edgeCase(String host, int port, bool tls) async {
  const ver = '143.0.3650.75';
  try {
    final c = HttpClient();
    final req = await c.openUrl('GET', Uri.parse('${tls ? 'https' : 'http'}://$host:$port${q(ver)}'));
    req.headers.clear();
    req.headers.set('Host', host, preserveHeaderCase: true);
    req.headers.set('Upgrade', 'websocket', preserveHeaderCase: true);
    req.headers.set('Connection', 'Upgrade', preserveHeaderCase: true);
    req.headers.set('Sec-WebSocket-Key', base64.encode(List.generate(16, (_) => Random.secure().nextInt(256))), preserveHeaderCase: true);
    hdrs('143').forEach((k, v) => req.headers.set(k, v, preserveHeaderCase: true));
    final res = await req.close().timeout(const Duration(seconds: 20));
    note('${res.statusCode == 101 ? '✅' : '❌'} edge preserveCase $host ${res.statusCode}');
    c.close(force: true);
  } catch (e) {
    note('❌ edge preserveCase $host $e');
  }
}

Future<void> edgeRaw() async {
  try {
    final s = await SecureSocket.connect('speech.platform.bing.com', 443, timeout: const Duration(seconds: 20));
    final key = base64.encode(List.generate(16, (_) => Random.secure().nextInt(256)));
    final b = StringBuffer('GET ${q('143.0.3650.75')} HTTP/1.1\r\n')
      ..write('Host: speech.platform.bing.com\r\n')
      ..write('Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: $key\r\n');
    hdrs('143').forEach((k, v) => b.write('$k: $v\r\n'));
    b.write('Accept: */*\r\n\r\n');
    s.add(utf8.encode(b.toString()));
    final first = await s.first.timeout(const Duration(seconds: 20));
    note('edge raw: ${utf8.decode(first, allowMalformed: true).split('\r\n').first}');
    s.destroy();
  } catch (e) {
    note('❌ edge raw $e');
  }
}

Future<void> main() async {
  final py = Platform.environment['PY_GEC'];
  note('gec dart=${gec()} py=$py');
  if (Platform.environment['CAPTURE'] == '1') {
    // نبعت لسيرفر محلي بيسجل الطلب
    await edge('capture-default');
    try {
      await WebSocket.connect('ws://127.0.0.1:8765${q('143.0.3650.75')}', headers: hdrs('143')).timeout(const Duration(seconds: 5));
    } catch (_) {}
    await edgeCase('127.0.0.1', 8765, false);
    return;
  }
  await edgeRaw();
  await edgeCase('speech.platform.bing.com', 443, true);
  await edge('default');

  final msgs = [
    {'role': 'system', 'content': 'أنت كاتب محتوى.'},
    {'role': 'user', 'content': 'اكتب جملة عن القهوة'},
  ];
  await poll('plain', {'model': 'openai', 'messages': msgs});
  await poll('plain-noModel', {'messages': msgs});
  await poll('openai-fast', {'model': 'openai-fast', 'messages': msgs});
  await poll('referrer', {'model': 'openai', 'messages': msgs, 'referrer': 'reels-maker'});
  await poll('long', {
    'model': 'openai',
    'messages': [
      {'role': 'system', 'content': 'أنت كاتب محتوى. ' * 300},
      msgs[1],
    ]
  });
  try {
    final r = await http.get(Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent('اكتب جملة عن القهوة باللهجة السعودية')}?model=openai'));
    note('poll GET ${r.statusCode} ${utf8.decode(r.bodyBytes)}');
  } catch (e) {
    note('poll GET $e');
  }
}
