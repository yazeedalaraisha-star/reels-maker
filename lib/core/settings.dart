// كل إعدادات التطبيق بمكان واحد. الكلاس هاد Dart صافي (بدون Flutter)
// عشان خدمات التوليد تقدر تستخدمه وتنفحص من سطر الأوامر.

enum TtsProvider { edge, munsit, elevenlabs, huggingface, google, device, none }

enum ScriptProvider { claude, free, offline }

enum MediaProvider { freeAi, openverse, pexels, pixabay, local, aiImages, gradient }

class AppSettings {
  // ---------- الذكاء الاصطناعي (السكربت) ----------
  ScriptProvider scriptProvider;
  String anthropicKey;
  String claudeModel;
  String claudeEffort; // low / medium / high
  bool claudeWebSearch; // يخلي Claude يدور على التريند بنفسه من النت

  // ---------- التعليق الصوتي ----------
  TtsProvider ttsProvider;
  List<TtsProvider> ttsFallbacks; // لو المزوّد الأساسي فشل
  String munsitKey;
  String munsitBaseUrl;
  String munsitModel;
  String munsitVoiceId;
  String munsitDialect; // auto / fusha / emirati
  double munsitSpeed;
  double munsitStability;
  String elevenKey;
  String elevenVoiceId;
  String elevenModel;
  double elevenStability;
  double elevenStyle;
  String hfToken;
  String hfTtsModel;
  String hfImageModel;
  String edgeVoice; // صوت مايكروسوفت المجاني
  int edgeRate; // نسبة السرعة -50..+50
  String deviceVoice; // اسم صوت الجهاز (اختياري)
  double deviceRate;

  // ---------- المقاطع والصور ----------
  MediaProvider mediaProvider;
  String pexelsKey;
  String pixabayKey;
  String localMediaFolder;

  // ---------- الموسيقى ----------
  String musicFolder;
  bool generatedMusic; // موسيقى خلفية مولدة لو ما في ملفات
  double musicVolume; // 0..1
  bool duckMusic; // يوطّي الموسيقى لما في كلام

  // ---------- التريند ----------
  String trendRegion; // SA, JO, AE...
  List<String> topics; // مواضيع المستخدم المفضلة
  bool useGoogleTrends;
  bool useGoogleNews;
  bool useReddit;
  bool useYoutube;
  String youtubeKey;
  List<String> subreddits;

  // ---------- الفيديو ----------
  int reelsPerRun;
  int targetSeconds; // طول الريل التقريبي
  String styleId;
  bool randomStyle;
  String quality; // 720 / 1080
  String watermark;
  bool showProgressBar;
  bool showHook;
  bool showCta;
  bool karaokeCaptions;
  String dialectPrompt; // وصف اللهجة للسكربت
  String outputFolder;
  String driveSyncFolder; // مجلد Google Drive على الكمبيوتر (بدون ربط)

  // ---------- Google Drive ----------
  bool autoUpload;
  String driveClientId;
  String driveClientSecret;
  String driveRefreshToken;
  String driveFolderId;
  String driveFolderName;

  // ---------- التشغيل التلقائي ----------
  bool autoRunEnabled;
  int autoRunHours;
  bool autoRunOnStart;

  AppSettings({
    this.scriptProvider = ScriptProvider.free,
    this.anthropicKey = '',
    this.claudeModel = 'claude-opus-5-5',
    this.claudeEffort = 'medium',
    this.claudeWebSearch = true,
    this.ttsProvider = TtsProvider.edge,
    List<TtsProvider>? ttsFallbacks,
    this.munsitKey = '',
    this.munsitBaseUrl = 'https://api.munsit.com/api/v1',
    this.munsitModel = 'faseeh-v1-preview',
    this.munsitVoiceId = '',
    this.munsitDialect = 'auto',
    this.munsitSpeed = 1.0,
    this.munsitStability = 0.5,
    this.elevenKey = '',
    this.elevenVoiceId = '',
    this.elevenModel = 'eleven_multilingual_v2',
    this.elevenStability = 0.45,
    this.elevenStyle = 0.35,
    this.hfToken = '',
    this.hfTtsModel = 'facebook/mms-tts-ara',
    this.hfImageModel = 'black-forest-labs/FLUX.1-schnell',
    this.edgeVoice = 'ar-SA-HamedNeural',
    this.edgeRate = 5,
    this.deviceVoice = '',
    this.deviceRate = 0.5,
    this.mediaProvider = MediaProvider.freeAi,
    this.pexelsKey = '',
    this.pixabayKey = '',
    this.localMediaFolder = '',
    this.musicFolder = '',
    this.generatedMusic = true,
    this.musicVolume = 0.18,
    this.duckMusic = true,
    this.trendRegion = 'SA',
    List<String>? topics,
    this.useGoogleTrends = true,
    this.useGoogleNews = true,
    this.useReddit = true,
    this.useYoutube = false,
    this.youtubeKey = '',
    List<String>? subreddits,
    this.reelsPerRun = 3,
    this.targetSeconds = 40,
    this.styleId = 'neon',
    this.randomStyle = true,
    this.quality = '1080',
    this.watermark = '',
    this.showProgressBar = true,
    this.showHook = true,
    this.showCta = true,
    this.karaokeCaptions = true,
    this.dialectPrompt =
        'لهجة سعودية بيضاء قريبة من اللهجة الأردنية والشامية، عفوية وحماسية ومفهومة لكل العرب',
    this.outputFolder = '',
    this.driveSyncFolder = '',
    this.autoUpload = true,
    this.driveClientId = '',
    this.driveClientSecret = '',
    this.driveRefreshToken = '',
    this.driveFolderId = '',
    this.driveFolderName = 'Reels Maker',
    this.autoRunEnabled = false,
    this.autoRunHours = 24,
    this.autoRunOnStart = false,
  })  : ttsFallbacks =
            ttsFallbacks ?? [TtsProvider.munsit, TtsProvider.elevenlabs, TtsProvider.google, TtsProvider.device],
        topics = topics ?? ['ترند اليوم'],
        subreddits = subreddits ?? ['worldnews', 'todayilearned', 'nosleep'];

  Map<String, dynamic> toJson() => {
        'scriptProvider': scriptProvider.name,
        'anthropicKey': anthropicKey,
        'claudeModel': claudeModel,
        'claudeEffort': claudeEffort,
        'claudeWebSearch': claudeWebSearch,
        'ttsProvider': ttsProvider.name,
        'ttsFallbacks': ttsFallbacks.map((e) => e.name).toList(),
        'munsitKey': munsitKey,
        'munsitBaseUrl': munsitBaseUrl,
        'munsitModel': munsitModel,
        'munsitVoiceId': munsitVoiceId,
        'munsitDialect': munsitDialect,
        'munsitSpeed': munsitSpeed,
        'munsitStability': munsitStability,
        'elevenKey': elevenKey,
        'elevenVoiceId': elevenVoiceId,
        'elevenModel': elevenModel,
        'elevenStability': elevenStability,
        'elevenStyle': elevenStyle,
        'hfToken': hfToken,
        'hfTtsModel': hfTtsModel,
        'hfImageModel': hfImageModel,
        'edgeVoice': edgeVoice,
        'edgeRate': edgeRate,
        'deviceVoice': deviceVoice,
        'deviceRate': deviceRate,
        'mediaProvider': mediaProvider.name,
        'pexelsKey': pexelsKey,
        'pixabayKey': pixabayKey,
        'localMediaFolder': localMediaFolder,
        'musicFolder': musicFolder,
        'generatedMusic': generatedMusic,
        'musicVolume': musicVolume,
        'duckMusic': duckMusic,
        'trendRegion': trendRegion,
        'topics': topics,
        'useGoogleTrends': useGoogleTrends,
        'useGoogleNews': useGoogleNews,
        'useReddit': useReddit,
        'useYoutube': useYoutube,
        'youtubeKey': youtubeKey,
        'subreddits': subreddits,
        'reelsPerRun': reelsPerRun,
        'targetSeconds': targetSeconds,
        'styleId': styleId,
        'randomStyle': randomStyle,
        'quality': quality,
        'watermark': watermark,
        'showProgressBar': showProgressBar,
        'showHook': showHook,
        'showCta': showCta,
        'karaokeCaptions': karaokeCaptions,
        'dialectPrompt': dialectPrompt,
        'outputFolder': outputFolder,
        'driveSyncFolder': driveSyncFolder,
        'autoUpload': autoUpload,
        'driveClientId': driveClientId,
        'driveClientSecret': driveClientSecret,
        'driveRefreshToken': driveRefreshToken,
        'driveFolderId': driveFolderId,
        'driveFolderName': driveFolderName,
        'autoRunEnabled': autoRunEnabled,
        'autoRunHours': autoRunHours,
        'autoRunOnStart': autoRunOnStart,
      };

  static T _enum<T extends Enum>(List<T> values, dynamic v, T def) =>
      values.firstWhere((e) => e.name == v, orElse: () => def);

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings();
    double dbl(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int integer(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    String str(String k, String def) => (j[k] as String?) ?? def;
    bool b(String k, bool def) => (j[k] as bool?) ?? def;
    List<String> list(String k, List<String> def) =>
        (j[k] as List?)?.map((e) => e.toString()).toList() ?? def;
    return AppSettings(
      scriptProvider:
          _enum(ScriptProvider.values, j['scriptProvider'], d.scriptProvider),
      anthropicKey: str('anthropicKey', d.anthropicKey),
      claudeModel: str('claudeModel', d.claudeModel),
      claudeEffort: str('claudeEffort', d.claudeEffort),
      claudeWebSearch: b('claudeWebSearch', d.claudeWebSearch),
      ttsProvider: _enum(TtsProvider.values, j['ttsProvider'], d.ttsProvider),
      ttsFallbacks: (j['ttsFallbacks'] as List?)
              ?.map((e) => _enum(TtsProvider.values, e, TtsProvider.none))
              .where((e) => e != TtsProvider.none)
              .toList() ??
          d.ttsFallbacks,
      munsitKey: str('munsitKey', d.munsitKey),
      munsitBaseUrl: str('munsitBaseUrl', d.munsitBaseUrl),
      munsitModel: str('munsitModel', d.munsitModel),
      munsitVoiceId: str('munsitVoiceId', d.munsitVoiceId),
      munsitDialect: str('munsitDialect', d.munsitDialect),
      munsitSpeed: dbl('munsitSpeed', d.munsitSpeed),
      munsitStability: dbl('munsitStability', d.munsitStability),
      elevenKey: str('elevenKey', d.elevenKey),
      elevenVoiceId: str('elevenVoiceId', d.elevenVoiceId),
      elevenModel: str('elevenModel', d.elevenModel),
      elevenStability: dbl('elevenStability', d.elevenStability),
      elevenStyle: dbl('elevenStyle', d.elevenStyle),
      hfToken: str('hfToken', d.hfToken),
      hfTtsModel: str('hfTtsModel', d.hfTtsModel),
      hfImageModel: str('hfImageModel', d.hfImageModel),
      edgeVoice: str('edgeVoice', d.edgeVoice),
      edgeRate: integer('edgeRate', d.edgeRate),
      deviceVoice: str('deviceVoice', d.deviceVoice),
      deviceRate: dbl('deviceRate', d.deviceRate),
      mediaProvider:
          _enum(MediaProvider.values, j['mediaProvider'], d.mediaProvider),
      pexelsKey: str('pexelsKey', d.pexelsKey),
      pixabayKey: str('pixabayKey', d.pixabayKey),
      localMediaFolder: str('localMediaFolder', d.localMediaFolder),
      musicFolder: str('musicFolder', d.musicFolder),
      generatedMusic: b('generatedMusic', d.generatedMusic),
      musicVolume: dbl('musicVolume', d.musicVolume),
      duckMusic: b('duckMusic', d.duckMusic),
      trendRegion: str('trendRegion', d.trendRegion),
      topics: list('topics', d.topics),
      useGoogleTrends: b('useGoogleTrends', d.useGoogleTrends),
      useGoogleNews: b('useGoogleNews', d.useGoogleNews),
      useReddit: b('useReddit', d.useReddit),
      useYoutube: b('useYoutube', d.useYoutube),
      youtubeKey: str('youtubeKey', d.youtubeKey),
      subreddits: list('subreddits', d.subreddits),
      reelsPerRun: integer('reelsPerRun', d.reelsPerRun),
      targetSeconds: integer('targetSeconds', d.targetSeconds),
      styleId: str('styleId', d.styleId),
      randomStyle: b('randomStyle', d.randomStyle),
      quality: str('quality', d.quality),
      watermark: str('watermark', d.watermark),
      showProgressBar: b('showProgressBar', d.showProgressBar),
      showHook: b('showHook', d.showHook),
      showCta: b('showCta', d.showCta),
      karaokeCaptions: b('karaokeCaptions', d.karaokeCaptions),
      dialectPrompt: str('dialectPrompt', d.dialectPrompt),
      outputFolder: str('outputFolder', d.outputFolder),
      driveSyncFolder: str('driveSyncFolder', d.driveSyncFolder),
      autoUpload: b('autoUpload', d.autoUpload),
      driveClientId: str('driveClientId', d.driveClientId),
      driveClientSecret: str('driveClientSecret', d.driveClientSecret),
      driveRefreshToken: str('driveRefreshToken', d.driveRefreshToken),
      driveFolderId: str('driveFolderId', d.driveFolderId),
      driveFolderName: str('driveFolderName', d.driveFolderName),
      autoRunEnabled: b('autoRunEnabled', d.autoRunEnabled),
      autoRunHours: integer('autoRunHours', d.autoRunHours),
      autoRunOnStart: b('autoRunOnStart', d.autoRunOnStart),
    );
  }

  int get width => quality == '720' ? 720 : 1080;
  int get height => quality == '720' ? 1280 : 1920;
}
