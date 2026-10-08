// كتابة سكربتات الريلز: Claude (أونلاين) أو مولّد بسيط بدون نت (أوفلاين).
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/engine.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/styles.dart';

const _uuid = Uuid();

/// شكل JSON اللي بنطلبه من Claude (Structured Outputs).
const _reelSchema = {
  'type': 'object',
  'properties': {
    'reels': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'topic': {'type': 'string'},
          'style': {
            'type': 'string',
            'enum': ['neon', 'news', 'story', 'horror', 'clean', 'sport', 'luxury']
          },
          'hook': {'type': 'string'},
          'scenes': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'narration': {'type': 'string'},
                'on_screen': {'type': 'string'},
                'search_query': {'type': 'string'},
                'highlight_words': {
                  'type': 'array',
                  'items': {'type': 'string'}
                },
              },
              'required': ['narration', 'on_screen', 'search_query', 'highlight_words'],
              'additionalProperties': false,
            }
          },
          'caption': {'type': 'string'},
          'hashtags': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'cta': {'type': 'string'},
        },
        'required': ['title', 'topic', 'style', 'hook', 'scenes', 'caption', 'hashtags', 'cta'],
        'additionalProperties': false,
      }
    }
  },
  'required': ['reels'],
  'additionalProperties': false,
};

class ScriptWriter {
  final AppSettings settings;
  final LogFn log;
  final http.Client _http;
  ScriptWriter(this.settings, this.log, [http.Client? client])
      : _http = client ?? http.Client();

  bool get canUseClaude =>
      settings.scriptProvider == ScriptProvider.claude &&
      settings.anthropicKey.trim().isNotEmpty;

  bool get _supportsFallbacks => const {
        'claude-opus-5-5',
        'claude-opus-5',
        'claude-sonnet-5-5',
        'claude-fable-5-1',
      }.contains(settings.claudeModel);

  String _systemPrompt() => '''
أنت صانع محتوى ريلز محترف (Instagram Reels / TikTok / YouTube Shorts) للجمهور العربي.
اكتب بـ${settings.dialectPrompt}. الكلام لازم يكون طبيعي كأنه شخص بيحكي للكاميرا، مش لغة أخبار رسمية.

قواعد كل ريل:
- طوله تقريباً ${settings.targetSeconds} ثانية لما ينقرأ (تقريباً ${(settings.targetSeconds * 2.4).round()} كلمة بالمجمل).
- "hook": جملة افتتاح قصيرة جداً (3-6 كلمات) بتنكتب كبيرة على الشاشة وبتشد من أول ثانية.
- "scenes": من 5 إلى 8 مشاهد. كل "narration" جملة أو جملتين (6-20 كلمة، وما يقل عن 4 كلمات) بتنقرأ بالتعليق الصوتي.
  أول مشهد لازم يكمل الـhook ويشد، وآخر مشهد خاتمة أو سؤال للجمهور.
- "on_screen": كلمتين أو ثلاث كعنوان صغير للمشهد (أو نص فاضي).
- "search_query": كلمات بحث بالإنجليزي (2-4 كلمات) لمقطع فيديو ستوك مناسب للمشهد، وصف بصري مش أسماء أشخاص.
- "highlight_words": كلمة أو كلمتين من نفس narration حرفياً بتتلون بالكابشن.
- "caption": وصف منشور جذاب بسطرين مع إيموجي.
- "hashtags": 6-10 هاشتاجات عربية وإنجليزية بدون #.
- "cta": جملة نهاية قصيرة (مثل: تابعنا لتعرف أكثر).
- "style": اختار الأنسب: news للأخبار، story للقصص، horror للرعب والغموض، sport للرياضة، luxury للفخامة والمال، clean للمعلومات والنصائح، neon للترفيه والتقنية.

مهم: تجنب المعلومات غير المؤكدة، ولو الخبر حساس أو فيه أشخاص حقيقيين احكيه بحياد وبدون اتهامات.
ممنوع المحتوى المسيء أو الطائفي أو السياسي المتطرف أو +18.
''';

  Map<String, dynamic> _requestBody(String userPrompt, {bool webSearch = false}) => {
        'model': settings.claudeModel,
        'max_tokens': 16000,
        'system': _systemPrompt(),
        'output_config': {
          'effort': settings.claudeEffort,
          'format': {'type': 'json_schema', 'schema': _reelSchema},
        },
        if (_supportsFallbacks) 'fallbacks': 'default',
        if (webSearch)
          'tools': [
            {'type': 'web_search_20260209', 'name': 'web_search', 'max_uses': 5}
          ],
        'messages': [
          {'role': 'user', 'content': userPrompt}
        ],
      };

  Future<Map<String, dynamic>> _callClaude(Map<String, dynamic> body) async {
    var messages = List<Map<String, dynamic>>.from(body['messages']);
    for (var attempt = 0; attempt < 6; attempt++) {
      final r = await _http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': settings.anthropicKey.trim(),
              'anthropic-version': '2023-06-01',
              if (_supportsFallbacks)
                'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode({...body, 'messages': messages}),
          )
          .timeout(const Duration(minutes: 6));
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (r.statusCode == 429 || r.statusCode >= 500) {
        log('⏳ Claude مشغول (${r.statusCode})، بعيد المحاولة...');
        await Future.delayed(Duration(seconds: 4 * (attempt + 1)));
        continue;
      }
      if (r.statusCode != 200) {
        throw Exception('Claude: ${j['error']?['message'] ?? r.body}');
      }
      final stop = j['stop_reason'];
      if (stop == 'refusal') {
        throw Exception('Claude رفض هالموضوع، جرب موضوع تاني.');
      }
      if (stop == 'pause_turn') {
        // البحث على النت لسا شغال: نكمّل من وين وقف
        messages = [
          ...messages,
          {'role': 'assistant', 'content': j['content']},
        ];
        continue;
      }
      return j;
    }
    throw Exception('Claude ما رد بعد عدة محاولات');
  }

  List<ReelProject> _parse(Map<String, dynamic> response, String topic) {
    final texts = (response['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .toList();
    if (texts.isEmpty) throw Exception('Claude ما رجّع نص');
    final raw = texts.last;
    Map<String, dynamic> j;
    try {
      j = jsonDecode(raw);
    } catch (_) {
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (m == null) throw Exception('رد Claude مش JSON');
      j = jsonDecode(m.group(0)!);
    }
    return (j['reels'] as List).map((r) {
      final scenes = (r['scenes'] as List)
          .map((s) => Scene.fromJson(Map<String, dynamic>.from(s)))
          .where((s) => s.narration.trim().isNotEmpty)
          .toList();
      return ReelProject(
        id: _uuid.v4(),
        title: r['title'] ?? 'ريل',
        hook: r['hook'] ?? '',
        caption: r['caption'] ?? '',
        hashtags: (r['hashtags'] as List?)?.map((e) => '$e').toList() ?? [],
        cta: r['cta'] ?? '',
        scenes: scenes,
        topic: r['topic'] ?? topic,
        styleId: settings.randomStyle
            ? (r['style'] ?? settings.styleId)
            : settings.styleId,
      );
    }).toList();
  }

  /// يختار أفضل [count] تريندات ويكتب لكل وحدة سكربت ريل.
  Future<List<ReelProject>> fromTrends(List<TrendItem> trends, String topic,
      {int? count, List<String> avoidTitles = const []}) async {
    final n = count ?? settings.reelsPerRun;
    if (!canUseClaude) {
      log('📴 بدون مفتاح Claude: رح أستخدم المولد الأوفلاين');
      final picked = trends.take(n).toList();
      if (picked.isEmpty) return [offline(topic)];
      return picked
          .map((t) => offline('${t.title}. ${t.summary ?? ''}', title: t.title))
          .toList();
    }
    final list = trends.take(60).map((t) => t.describe()).join('\n');
    final avoid = avoidTitles.isEmpty
        ? ''
        : '\nلا تكرر هالمواضيع اللي عملناها قبل:\n${avoidTitles.take(30).map((t) => '- $t').join('\n')}\n';
    final useWeb = settings.claudeWebSearch;
    final prompt = '''
الموضوع المطلوب: $topic
البلد/الجمهور: ${regionLabel(settings.trendRegion)}

هاي قائمة التريندات والأخبار والقصص اللي انجمعت هلأ:
$list
$avoid
${useWeb ? 'تقدر تستخدم البحث على النت عشان تتأكد من التفاصيل أو تلاقي تريندات أقوى عن الموضوع.\n' : ''}
اختار أقوى $n مواضيع مختلفة عن بعض (الأكثر انتشاراً وقابلية إنها تصير فايرال) وبتناسب الموضوع المطلوب،
واكتب لكل وحدة ريل كامل. رجّع بالضبط $n ريلز.
''';
    log('🧠 Claude عم يختار التريندات ويكتب $n سكربتات...');
    final res = await _callClaude(_requestBody(prompt, webSearch: useWeb));
    final reels = _parse(res, topic);
    for (final r in reels) {
      r.trendSource = topic;
    }
    log('📝 انكتبوا ${reels.length} سكربتات');
    return reels.take(n).toList();
  }

  /// ريلز من فكرة المستخدم نفسه.
  Future<List<ReelProject>> fromIdea(String idea, {int count = 1}) async {
    if (!canUseClaude) return [offline(idea)];
    final prompt = '''
فكرة المستخدم: $idea

اكتب $count ريل${count > 1 ? 'ز بزوايا مختلفة' : ''} عن هالفكرة. لو الفكرة قصة، احكيها بتشويق مع نهاية قوية.
''';
    log('🧠 Claude عم يكتب السكربت من فكرتك...');
    final res = await _callClaude(_requestBody(prompt, webSearch: settings.claudeWebSearch));
    return _parse(res, idea).take(count).toList();
  }

  /// يعيد كتابة نص مشهد واحد (من المحرر).
  Future<String> rewriteLine(String line, String instruction) async {
    if (!canUseClaude) return line;
    final r = await _http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': settings.anthropicKey.trim(),
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': settings.claudeModel,
        'max_tokens': 2000,
        'output_config': {'effort': 'low'},
        'messages': [
          {
            'role': 'user',
            'content':
                'أعد كتابة هالجملة لريل بـ${settings.dialectPrompt}. $instruction\nرجّع الجملة الجديدة بس بدون أي شرح.\n\nالجملة: $line'
          }
        ],
      }),
    );
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw Exception(j['error']?['message'] ?? 'خطأ');
    return (j['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'])
        .join()
        .trim();
  }

  /// مولّد بدون إنترنت: يقسم النص لمشاهد ويطلع هاشتاجات بسيطة.
  ReelProject offline(String text, {String? title}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    var sentences = clean
        .split(RegExp(r'(?<=[.!?؟\n])\s+|،\s+'))
        .map((s) => s.trim())
        .where((s) => s.split(' ').length >= 2)
        .toList();
    if (sentences.isEmpty) sentences = [clean];
    // دمج الجمل القصيرة كتير
    final merged = <String>[];
    for (final s in sentences) {
      if (merged.isNotEmpty && merged.last.split(' ').length < 6) {
        merged[merged.length - 1] = '${merged.last} $s';
      } else {
        merged.add(s);
      }
    }
    final scenes = merged.take(8).map((s) {
      final words = s.split(' ');
      final longest = [...words]..sort((a, b) => b.length.compareTo(a.length));
      return Scene(
        narration: s,
        onScreen: '',
        searchQuery: '',
        highlights: longest.take(1).toList(),
      );
    }).toList();
    final t = title ?? (clean.length > 40 ? '${clean.substring(0, 40)}…' : clean);
    final words = clean
        .split(RegExp(r'[\s،.!?؟]+'))
        .where((w) => w.length > 3)
        .toSet()
        .take(6)
        .toList();
    final hookWords = merged.first.split(' ');
    return ReelProject(
      id: _uuid.v4(),
      title: t,
      hook: hookWords.take(min(5, hookWords.length)).join(' '),
      caption: '$t 👀🔥',
      hashtags: [...words, 'ريلز', 'ترند', 'explore'],
      cta: 'تابعنا للمزيد',
      scenes: scenes,
      topic: text,
      styleId: settings.randomStyle
          ? reelStyles[Random().nextInt(reelStyles.length)].id
          : settings.styleId,
    );
  }
}

String regionLabel(String code) => const {
      'SA': 'السعودية والخليج',
      'JO': 'الأردن وبلاد الشام',
      'AE': 'الإمارات والخليج',
      'EG': 'مصر',
      'KW': 'الكويت',
      'US': 'العالم العربي',
    }[code] ??
    'العالم العربي';
