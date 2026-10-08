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

Future<void> main() async {
  final py = Platform.environment['PY_GEC'];
  note('gec dart=${gec()} py=$py');
  await edge('default');
  await edge('order', order: true);
  await edge('nocompress', compress: false);
  await edge('enc', enc: true);
  await edge('order+nocompress+enc', order: true, compress: false, enc: true);
  await edge('v130', ver: '130.0.2849.68');

  final msgs = [
    {'role': 'system', 'content': 'أنت كاتب محتوى.'},
    {'role': 'user', 'content': 'اكتب جملة عن القهوة'},
  ];
  await poll('plain', {'model': 'openai', 'messages': msgs});
  await poll('json', {'model': 'openai', 'messages': msgs, 'response_format': {'type': 'json_object'}});
  await poll('seed', {'model': 'openai', 'messages': msgs, 'seed': 42});
  await poll('referrer', {'model': 'openai', 'messages': msgs, 'referrer': 'reels-maker'});
  await poll('long', {
    'model': 'openai',
    'messages': [
      {'role': 'system', 'content': 'أنت كاتب محتوى. ' * 300},
      msgs[1],
    ]
  });
  await poll('long2', {
    'model': 'openai',
    'messages': [
      {'role': 'system', 'content': 'أنت كاتب محتوى. ' * 120},
      msgs[1],
    ]
  });
}
