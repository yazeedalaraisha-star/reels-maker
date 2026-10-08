// جلب مقاطع/صور لكل مشهد: Pexels أو Pixabay (مجاني بمفتاح)، صور AI من
// Hugging Face، ملفات من جهازك، أو خلفيات متحركة بدون نت.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/engine.dart';
import '../core/settings.dart';

const videoExt = {'.mp4', '.mov', '.mkv', '.webm', '.m4v', '.avi'};
const imageExt = {'.jpg', '.jpeg', '.png', '.webp'};

class MediaService {
  final AppSettings settings;
  final LogFn log;
  final http.Client _http;
  final _rnd = Random();
  final Set<String> _usedIds = {};
  MediaService(this.settings, this.log, [http.Client? client])
      : _http = client ?? http.Client();

  /// يرجع مسار ملف محلي للمشهد أو null (يعني خلفية متدرجة).
  Future<String?> forScene(String query, String dir, int index,
      {String fallbackQuery = ''}) async {
    final q = query.trim().isEmpty ? fallbackQuery : query;
    if (settings.mediaProvider == MediaProvider.gradient) return null;
    // المصادر المجانية دايماً بالآخر كاحتياط
    final order = <MediaProvider>{
      settings.mediaProvider,
      if (settings.pexelsKey.isNotEmpty) MediaProvider.pexels,
      if (settings.pixabayKey.isNotEmpty) MediaProvider.pixabay,
      if (settings.localMediaFolder.isNotEmpty) MediaProvider.local,
      MediaProvider.freeAi,
      MediaProvider.openverse,
    }.toList();
    for (final m in order) {
      try {
        final r = switch (m) {
          MediaProvider.freeAi => await _pollinations(q, dir, index),
          MediaProvider.openverse => await _openverse(q, dir, index),
          MediaProvider.pexels => await _pexels(q, dir, index),
          MediaProvider.pixabay => await _pixabay(q, dir, index),
          MediaProvider.local => _local(q),
          MediaProvider.aiImages => await _aiImage(q, dir, index),
          MediaProvider.gradient => null,
        };
        if (r != null) return r;
        if (m == MediaProvider.gradient) return null;
      } catch (e) {
        log('⚠️ مقاطع (${m.name}) للمشهد ${index + 1}: $e');
      }
    }
    return null;
  }

  Future<String> _download(String url, String path,
      {Map<String, String>? headers}) async {
    final req = http.Request('GET', Uri.parse(url));
    if (headers != null) req.headers.addAll(headers);
    final res = await _http.send(req).timeout(const Duration(minutes: 3));
    if (res.statusCode != 200) throw Exception('تنزيل ${res.statusCode}');
    final f = File(path);
    final sink = f.openWrite();
    await res.stream.pipe(sink);
    return path;
  }

  /// صور بالذكاء الاصطناعي مجاناً بدون مفتاح (Pollinations).
  Future<String?> _pollinations(String q, String dir, int i) async {
    if (q.isEmpty) return null;
    final prompt = Uri.encodeComponent(
        '$q, cinematic vertical photo, dramatic lighting, highly detailed, no text');
    final w = settings.width, h = settings.height;
    final url =
        'https://image.pollinations.ai/prompt/$prompt?width=$w&height=$h&nologo=true&seed=${_rnd.nextInt(1 << 30)}';
    final path = p.join(dir, 'media_$i.jpg');
    final r = await _http.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
    final ct = r.headers['content-type'] ?? '';
    if (r.statusCode != 200 || !ct.startsWith('image/') || r.bodyBytes.length < 5000) {
      throw Exception('Pollinations ${r.statusCode}');
    }
    await File(path).writeAsBytes(r.bodyBytes);
    log('🖼️ صورة AI مجانية للمشهد ${i + 1} ($q)');
    return path;
  }

  /// صور حقيقية برخصة حرة من Openverse (بدون مفتاح).
  Future<String?> _openverse(String q, String dir, int i) async {
    if (q.isEmpty) return null;
    final r = await _http.get(
        Uri.parse(
            'https://api.openverse.org/v1/images/?q=${Uri.encodeQueryComponent(q)}&page_size=20&mature=false'),
        headers: {'User-Agent': 'ReelsMaker/1.0'}).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw Exception('Openverse ${r.statusCode}');
    final results = (jsonDecode(r.body)['results'] as List? ?? [])
        .where((x) => !_usedIds.contains('ov${x['id']}') && (x['width'] ?? 0) >= 800)
        .toList();
    if (results.isEmpty) return null;
    // نفضل الصور الطولية
    results.sort((a, b) => ((b['height'] ?? 0) / (b['width'] ?? 1))
        .compareTo((a['height'] ?? 0) / (a['width'] ?? 1)));
    final x = results[_rnd.nextInt(min(4, results.length))];
    _usedIds.add('ov${x['id']}');
    final ext = p.extension(Uri.parse(x['url']).path).toLowerCase();
    final path = p.join(dir, 'media_$i${imageExt.contains(ext) ? ext : '.jpg'}');
    await _download(x['url'], path, headers: {'User-Agent': 'ReelsMaker/1.0'});
    log('📷 صورة من Openverse للمشهد ${i + 1}');
    return path;
  }

  Future<String?> _pexels(String q, String dir, int i) async {
    if (settings.pexelsKey.isEmpty || q.isEmpty) return null;
    final h = {'Authorization': settings.pexelsKey.trim()};
    final r = await _http.get(
        Uri.parse(
            'https://api.pexels.com/videos/search?query=${Uri.encodeQueryComponent(q)}&orientation=portrait&per_page=15&size=medium'),
        headers: h);
    if (r.statusCode != 200) throw Exception('Pexels ${r.statusCode}');
    final videos = (jsonDecode(r.body)['videos'] as List? ?? [])
        .where((v) => !_usedIds.contains('px${v['id']}'))
        .toList();
    if (videos.isNotEmpty) {
      final v = videos[_rnd.nextInt(min(5, videos.length))];
      _usedIds.add('px${v['id']}');
      final files = (v['video_files'] as List)
          .where((f) => (f['height'] ?? 0) >= 1000 && f['file_type'] == 'video/mp4')
          .toList()
        ..sort((a, b) => (a['height'] as int).compareTo(b['height'] as int));
      final file = files.isNotEmpty ? files.first : (v['video_files'] as List).first;
      log('🎞️ Pexels: مقطع للمشهد ${i + 1} ($q)');
      return _download(file['link'], p.join(dir, 'media_$i.mp4'));
    }
    // ما في فيديو؟ صورة
    final pr = await _http.get(
        Uri.parse(
            'https://api.pexels.com/v1/search?query=${Uri.encodeQueryComponent(q)}&orientation=portrait&per_page=10'),
        headers: h);
    final photos = (jsonDecode(pr.body)['photos'] as List? ?? []);
    if (photos.isEmpty) return null;
    final ph = photos[_rnd.nextInt(min(5, photos.length))];
    return _download(ph['src']['large2x'], p.join(dir, 'media_$i.jpg'));
  }

  Future<String?> _pixabay(String q, String dir, int i) async {
    if (settings.pixabayKey.isEmpty || q.isEmpty) return null;
    final r = await _http.get(Uri.parse(
        'https://pixabay.com/api/videos/?key=${settings.pixabayKey.trim()}&q=${Uri.encodeQueryComponent(q)}&per_page=15&safesearch=true'));
    if (r.statusCode != 200) throw Exception('Pixabay ${r.statusCode}');
    final hits = (jsonDecode(r.body)['hits'] as List? ?? [])
        .where((v) => !_usedIds.contains('pb${v['id']}'))
        .toList();
    if (hits.isEmpty) return null;
    final v = hits[_rnd.nextInt(min(5, hits.length))];
    _usedIds.add('pb${v['id']}');
    final vids = v['videos'] as Map;
    final pick = (vids['medium']?['url'] as String?)?.isNotEmpty == true
        ? vids['medium']['url']
        : vids['small']?['url'] ?? vids['large']?['url'];
    if (pick == null || '$pick'.isEmpty) return null;
    log('🎞️ Pixabay: مقطع للمشهد ${i + 1} ($q)');
    return _download(pick, p.join(dir, 'media_$i.mp4'));
  }

  List<File>? _localCache;
  String? _local(String q) {
    final folder = settings.localMediaFolder;
    if (folder.isEmpty || !Directory(folder).existsSync()) return null;
    _localCache ??= Directory(folder)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
      final e = p.extension(f.path).toLowerCase();
      return videoExt.contains(e) || imageExt.contains(e);
    }).toList();
    final files = _localCache!;
    if (files.isEmpty) return null;
    // لو اسم الملف فيه كلمة من البحث بنفضله
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2);
    final matches = files
        .where((f) => words.any((w) => p.basename(f.path).toLowerCase().contains(w)))
        .where((f) => !_usedIds.contains(f.path))
        .toList();
    final pool = matches.isNotEmpty
        ? matches
        : files.where((f) => !_usedIds.contains(f.path)).toList();
    final pick = (pool.isEmpty ? files : pool)[_rnd.nextInt((pool.isEmpty ? files : pool).length)];
    _usedIds.add(pick.path);
    return pick.path;
  }

  Future<String?> _aiImage(String q, String dir, int i) async {
    if (settings.hfToken.isEmpty || q.isEmpty) return null;
    final r = await _http
        .post(
          Uri.parse(
              'https://router.huggingface.co/hf-inference/models/${settings.hfImageModel}'),
          headers: {
            'Authorization': 'Bearer ${settings.hfToken.trim()}',
            'Content-Type': 'application/json',
            'Accept': 'image/png',
          },
          body: jsonEncode({
            'inputs':
                '$q, cinematic vertical photo, dramatic lighting, high detail, 9:16',
            'parameters': {'width': 768, 'height': 1344},
          }),
        )
        .timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) throw Exception('HF صور ${r.statusCode}');
    log('🖼️ صورة AI للمشهد ${i + 1}');
    final path = p.join(dir, 'media_$i.png');
    await File(path).writeAsBytes(r.bodyBytes);
    return path;
  }
}
