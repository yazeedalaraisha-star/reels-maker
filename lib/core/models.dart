// نماذج البيانات المشتركة بين كل أجزاء التطبيق.
import 'dart:convert';

/// عنصر تريند جاي من أي مصدر (Google Trends, News, Reddit, YouTube...).
class TrendItem {
  final String title;
  final String source;
  final String? summary;
  final String? url;
  final String? traffic;
  final DateTime fetchedAt;

  TrendItem({
    required this.title,
    required this.source,
    this.summary,
    this.url,
    this.traffic,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'title': title,
        'source': source,
        'summary': summary,
        'url': url,
        'traffic': traffic,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory TrendItem.fromJson(Map<String, dynamic> j) => TrendItem(
        title: j['title'] ?? '',
        source: j['source'] ?? '',
        summary: j['summary'],
        url: j['url'],
        traffic: j['traffic'],
        fetchedAt: DateTime.tryParse(j['fetchedAt'] ?? ''),
      );

  /// نص مختصر يوصف التريند للذكاء الاصطناعي.
  String describe() {
    final b = StringBuffer('- [$source] $title');
    if (traffic != null && traffic!.isNotEmpty) b.write(' (بحث: $traffic)');
    if (summary != null && summary!.isNotEmpty) b.write(' — $summary');
    return b.toString();
  }
}

/// مشهد واحد داخل الريل.
class Scene {
  String narration; // النص المقروء بالتعليق الصوتي
  String onScreen; // نص قصير يظهر فوق كعنوان للمشهد (اختياري)
  String searchQuery; // كلمات بحث إنجليزية للمقاطع (Pexels)
  List<String> highlights; // كلمات تتلوّن بالكابشن
  String? mediaPath; // مسار مقطع/صورة محلية (لو المستخدم اختار أو تم التنزيل)
  String? audioPath; // مسار التعليق الصوتي للمشهد
  double? durationOverride; // مدة يدوية بالثواني (اختياري)
  double? audioDuration; // مدة الصوت الفعلية بعد التوليد

  Scene({
    required this.narration,
    this.onScreen = '',
    this.searchQuery = '',
    List<String>? highlights,
    this.mediaPath,
    this.audioPath,
    this.durationOverride,
    this.audioDuration,
  }) : highlights = highlights ?? [];

  Map<String, dynamic> toJson() => {
        'narration': narration,
        'onScreen': onScreen,
        'searchQuery': searchQuery,
        'highlights': highlights,
        'mediaPath': mediaPath,
        'audioPath': audioPath,
        'durationOverride': durationOverride,
        'audioDuration': audioDuration,
      };

  factory Scene.fromJson(Map<String, dynamic> j) => Scene(
        narration: j['narration'] ?? '',
        onScreen: j['onScreen'] ?? j['on_screen'] ?? '',
        searchQuery: j['searchQuery'] ?? j['search_query'] ?? '',
        highlights: ((j['highlights'] ?? j['highlight_words']) as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        mediaPath: j['mediaPath'],
        audioPath: j['audioPath'],
        durationOverride: (j['durationOverride'] as num?)?.toDouble(),
        audioDuration: (j['audioDuration'] as num?)?.toDouble(),
      );
}

enum ReelStatus { draft, rendering, rendered, uploaded, failed }

/// مشروع ريل كامل: السكربت + المشاهد + الملفات الناتجة.
class ReelProject {
  final String id;
  String title;
  String hook; // جملة الافتتاح الكبيرة على الشاشة
  String caption; // وصف المنشور
  List<String> hashtags;
  String cta; // نهاية الفيديو (تابعنا...)
  List<Scene> scenes;
  String topic;
  String? trendSource;
  String styleId;
  String? musicPath;
  String? outputPath;
  String? thumbnailPath;
  String? driveFileId;
  String? driveLink;
  ReelStatus status;
  String? error;
  DateTime createdAt;

  ReelProject({
    required this.id,
    required this.title,
    required this.hook,
    required this.caption,
    required this.hashtags,
    required this.cta,
    required this.scenes,
    this.topic = '',
    this.trendSource,
    this.styleId = 'neon',
    this.musicPath,
    this.outputPath,
    this.thumbnailPath,
    this.driveFileId,
    this.driveLink,
    this.status = ReelStatus.draft,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hook': hook,
        'caption': caption,
        'hashtags': hashtags,
        'cta': cta,
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'topic': topic,
        'trendSource': trendSource,
        'styleId': styleId,
        'musicPath': musicPath,
        'outputPath': outputPath,
        'thumbnailPath': thumbnailPath,
        'driveFileId': driveFileId,
        'driveLink': driveLink,
        'status': status.name,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReelProject.fromJson(Map<String, dynamic> j) => ReelProject(
        id: j['id'],
        title: j['title'] ?? '',
        hook: j['hook'] ?? '',
        caption: j['caption'] ?? '',
        hashtags:
            (j['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        cta: j['cta'] ?? '',
        scenes: (j['scenes'] as List? ?? [])
            .map((e) => Scene.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        topic: j['topic'] ?? '',
        trendSource: j['trendSource'],
        styleId: j['styleId'] ?? 'neon',
        musicPath: j['musicPath'],
        outputPath: j['outputPath'],
        thumbnailPath: j['thumbnailPath'],
        driveFileId: j['driveFileId'],
        driveLink: j['driveLink'],
        status: ReelStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => ReelStatus.draft),
        error: j['error'],
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// نص المنشور الجاهز للنسخ (وصف + هاشتاجات).
  String postText() {
    final tags = hashtags
        .map((h) => h.startsWith('#') ? h : '#${h.replaceAll(' ', '_')}')
        .join(' ');
    return '$caption\n\n$tags'.trim();
  }
}
