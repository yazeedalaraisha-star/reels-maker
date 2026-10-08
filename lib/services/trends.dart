// جلب التريند من عدة مصادر مجانية: Google Trends و Google News و Reddit
// و YouTube (لو في مفتاح). كل مصدر مستقل، ولو واحد فشل الباقي بيكمل.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../core/engine.dart';
import '../core/models.dart';
import '../core/settings.dart';

const regionNames = {
  'SA': 'السعودية',
  'JO': 'الأردن',
  'AE': 'الإمارات',
  'EG': 'مصر',
  'KW': 'الكويت',
  'QA': 'قطر',
  'LB': 'لبنان',
  'IQ': 'العراق',
  'MA': 'المغرب',
  'US': 'أمريكا',
};

class TrendsService {
  final AppSettings settings;
  final LogFn log;
  final http.Client _http;
  TrendsService(this.settings, this.log, [http.Client? client])
      : _http = client ?? http.Client();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ReelsMaker/1.0 (trend reader)';

  Future<String> _get(String url) async {
    final r = await _http
        .get(Uri.parse(url), headers: {'User-Agent': _ua})
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return utf8.decode(r.bodyBytes);
  }

  String _strip(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<List<TrendItem>> googleTrends() async {
    final geo = settings.trendRegion;
    final body = await _get('https://trends.google.com/trending/rss?geo=$geo');
    final doc = XmlDocument.parse(body);
    final out = <TrendItem>[];
    for (final item in doc.findAllElements('item')) {
      final title = item.getElement('title')?.innerText.trim() ?? '';
      if (title.isEmpty) continue;
      final traffic = item.getElement('ht:approx_traffic')?.innerText;
      final news = item
          .findAllElements('ht:news_item_title')
          .map((e) => _strip(e.innerText))
          .take(2)
          .join(' | ');
      final url = item.findAllElements('ht:news_item_url').firstOrNull?.innerText;
      out.add(TrendItem(
          title: title,
          source: 'Google Trends',
          traffic: traffic,
          summary: news.isEmpty ? null : news,
          url: url));
    }
    return out;
  }

  Future<List<TrendItem>> googleNews({String? query}) async {
    final geo = settings.trendRegion;
    final base = query == null || query.trim().isEmpty
        ? 'https://news.google.com/rss?hl=ar&gl=$geo&ceid=$geo:ar'
        : 'https://news.google.com/rss/search?q=${Uri.encodeQueryComponent(query)}%20when:2d&hl=ar&gl=$geo&ceid=$geo:ar';
    final doc = XmlDocument.parse(await _get(base));
    return doc
        .findAllElements('item')
        .take(15)
        .map((item) => TrendItem(
              title: _strip(item.getElement('title')?.innerText ?? ''),
              source: query == null ? 'Google News' : 'أخبار: $query',
              url: item.getElement('link')?.innerText,
              summary: _strip(item.getElement('description')?.innerText ?? '')
                  .split(' ')
                  .take(40)
                  .join(' '),
            ))
        .where((t) => t.title.isNotEmpty)
        .toList();
  }

  Future<List<TrendItem>> reddit(String sub) async {
    final body = await _get('https://www.reddit.com/r/$sub/top.json?t=day&limit=10');
    final j = jsonDecode(body);
    final out = <TrendItem>[];
    for (final c in (j['data']?['children'] as List? ?? [])) {
      final d = c['data'];
      if (d == null || d['over_18'] == true) continue;
      final text = (d['selftext'] as String? ?? '').trim();
      out.add(TrendItem(
        title: d['title'] ?? '',
        source: 'Reddit r/$sub',
        traffic: '${d['ups'] ?? ''} تصويت',
        url: 'https://www.reddit.com${d['permalink'] ?? ''}',
        // للقصص: ناخد جزء من النص عشان Claude يقدر يحكيها
        summary: text.isEmpty
            ? null
            : (text.length > 1500 ? '${text.substring(0, 1500)}…' : text),
      ));
    }
    return out;
  }

  Future<List<TrendItem>> youtube() async {
    if (settings.youtubeKey.isEmpty) return [];
    final url =
        'https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics&chart=mostPopular&maxResults=15&regionCode=${settings.trendRegion}&key=${settings.youtubeKey}';
    final j = jsonDecode(await _get(url));
    return (j['items'] as List? ?? [])
        .map((v) => TrendItem(
              title: v['snippet']?['title'] ?? '',
              source: 'YouTube',
              traffic: '${v['statistics']?['viewCount'] ?? ''} مشاهدة',
              url: 'https://youtu.be/${v['id']}',
              summary: (v['snippet']?['description'] as String? ?? '')
                  .split('\n')
                  .first,
            ))
        .toList();
  }

  /// يجمع من كل المصادر المفعلة. [topic] اختياري لتخصيص البحث.
  Future<List<TrendItem>> fetchAll({String? topic}) async {
    final jobs = <String, Future<List<TrendItem>>>{};
    final hasTopic = topic != null &&
        topic.trim().isNotEmpty &&
        !topic.contains('ترند اليوم');
    if (settings.useGoogleTrends && !hasTopic) jobs['Google Trends'] = googleTrends();
    if (settings.useGoogleNews) {
      jobs['Google News'] = googleNews(query: hasTopic ? topic : null);
    }
    if (settings.useReddit) {
      for (final s in settings.subreddits.take(4)) {
        jobs['Reddit $s'] = reddit(s);
      }
    }
    if (settings.useYoutube && !hasTopic) jobs['YouTube'] = youtube();

    final out = <TrendItem>[];
    for (final e in jobs.entries) {
      try {
        final items = await e.value;
        log('📈 ${e.key}: ${items.length} عنصر');
        out.addAll(items);
      } catch (err) {
        log('⚠️ ما قدرت أجيب من ${e.key}: $err');
      }
    }
    // إزالة المكرر
    final seen = <String>{};
    return out.where((t) => seen.add(t.title.toLowerCase().trim())).toList();
  }
}
