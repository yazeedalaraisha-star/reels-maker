import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../app/app_state.dart';
import '../core/settings.dart';
import '../core/styles.dart';
import '../services/drive.dart';
import '../services/trends.dart';
import '../services/tts.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings get st => widget.state.settings;

  void changed(VoidCallback f) {
    setState(f);
    widget.state.saveSettings();
  }

  Widget text(String label, String value, void Function(String) set,
      {bool secret = false, String? hint, int maxLines = 1, String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _SettingField(
        label: label,
        value: value,
        secret: secret,
        hint: hint,
        helper: helper,
        maxLines: maxLines,
        onChanged: (v) {
          set(v.trim());
          widget.state.saveSettings();
        },
      ),
    );
  }

  Widget toggle(String label, bool value, void Function(bool) set, {String? sub}) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: sub == null ? null : Text(sub),
        value: value,
        onChanged: (v) => changed(() => set(v)),
      );

  Widget dropdown<T>(String label, T value, Map<T, String> items, void Function(T) set) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) {
            if (v != null) changed(() => set(v));
          },
        ),
      );

  Widget folder(String label, String value, void Function(String) set) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.folder_rounded),
        title: Text(label),
        subtitle: Text(value.isEmpty ? 'ما في' : value),
        trailing: Wrap(children: [
          TextButton(
            onPressed: () async {
              final d = await FilePicker.getDirectoryPath();
              if (d != null) changed(() => set(d));
            },
            child: const Text('اختار'),
          ),
          if (value.isNotEmpty) IconButton(onPressed: () => changed(() => set('')), icon: const Icon(Icons.clear_rounded)),
        ]),
      );

  Widget slider(String label, double value, double min, double max, void Function(double) set, {int? divisions, String Function(double)? fmt}) =>
      Row(children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: fmt?.call(value) ?? value.toStringAsFixed(2),
            onChanged: (v) => setState(() => set(v)),
            onChangeEnd: (_) => widget.state.saveSettings(),
          ),
        ),
        SizedBox(width: 48, child: Text(fmt?.call(value) ?? value.toStringAsFixed(2))),
      ]);

  Widget link(String label, String url) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(onPressed: () => openUrl(url), icon: const Icon(Icons.open_in_new_rounded, size: 18), label: Text(label)),
      );

  @override
  Widget build(BuildContext context) {
    final ttsNames = {
      TtsProvider.munsit: 'منصت (عربي ولهجات خليجية) ⭐',
      TtsProvider.elevenlabs: 'ElevenLabs',
      TtsProvider.huggingface: 'Hugging Face',
      TtsProvider.device: 'صوت الجهاز (بدون نت)',
      TtsProvider.none: 'بدون تعليق صوتي',
    };
    return PageScaffold(title: 'الإعدادات', children: [
      // ---------------- Claude ----------------
      SectionCard(title: 'كتابة السكربت (Claude)', icon: Icons.psychology_rounded, children: [
        dropdown('الطريقة', st.scriptProvider, {ScriptProvider.claude: 'Claude (أونلاين، احترافي)', ScriptProvider.offline: 'بدون نت (بسيط)'},
            (v) => st.scriptProvider = v),
        text('مفتاح Claude API', st.anthropicKey, (v) => st.anthropicKey = v, secret: true, hint: 'sk-ant-...'),
        link('جيب مفتاح من console.anthropic.com', 'https://console.anthropic.com/settings/keys'),
        dropdown('الموديل', st.claudeModel, {
          'claude-opus-5-5': 'Claude Opus 5.5 (الأقوى) ⭐',
          'claude-sonnet-5-5': 'Claude Sonnet 5.5 (أسرع وأرخص)',
          'claude-haiku-5-5': 'Claude Haiku 5.5 (الأرخص)',
          'claude-fable-5-1': 'Claude Fable 5.1 (الأذكى، أغلى)',
        }, (v) => st.claudeModel = v),
        dropdown('مستوى التفكير', st.claudeEffort, {'low': 'سريع', 'medium': 'متوسط ⭐', 'high': 'عميق'}, (v) => st.claudeEffort = v),
        toggle('Claude يدوّر على النت بنفسه', st.claudeWebSearch, (v) => st.claudeWebSearch = v, sub: 'بيتأكد من التفاصيل وبيلاقي تريند أقوى'),
        text('اللهجة والأسلوب', st.dialectPrompt, (v) => st.dialectPrompt = v, maxLines: 2),
      ]),

      // ---------------- الصوت ----------------
      SectionCard(title: 'التعليق الصوتي', icon: Icons.record_voice_over_rounded, children: [
        dropdown('المزوّد الأساسي', st.ttsProvider, ttsNames, (v) => st.ttsProvider = v),
        const Text('البدائل لو فشل الأساسي:'),
        Wrap(spacing: 8, children: [
          for (final t in [TtsProvider.munsit, TtsProvider.elevenlabs, TtsProvider.huggingface, TtsProvider.device])
            FilterChip(
              label: Text(ttsNames[t]!.split(' (').first),
              selected: st.ttsFallbacks.contains(t),
              onSelected: (v) => changed(() => v ? st.ttsFallbacks.add(t) : st.ttsFallbacks.remove(t)),
            ),
        ]),
        const Divider(height: 28),
        const Text('منصت', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        text('مفتاح منصت', st.munsitKey, (v) => st.munsitKey = v, secret: true),
        link('جيب مفتاح من munsit.com', 'https://app.munsit.com'),
        _VoiceRow(
          label: 'صوت منصت',
          value: st.munsitVoiceId,
          load: () => TtsService(st, widget.state.log).munsitVoices(),
          onPick: (v) => changed(() => st.munsitVoiceId = v),
          hint: 'نصيحة: دوّر على صوت نجدي أو حجازي (أقرب للهجة الشامية)',
        ),
        dropdown('اللهجة', st.munsitDialect, {'auto': 'تلقائي', 'fusha': 'فصحى', 'emirati': 'إماراتي'}, (v) => st.munsitDialect = v),
        slider('السرعة', st.munsitSpeed, 0.7, 1.2, (v) => st.munsitSpeed = v),
        slider('الثبات', st.munsitStability, 0, 1, (v) => st.munsitStability = v),
        text('رابط الخادم', st.munsitBaseUrl, (v) => st.munsitBaseUrl = v, helper: 'لحسابات الإمارات: https://ae.api.faseeh.ai/api/v1'),
        const Divider(height: 28),
        const Text('ElevenLabs', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        text('مفتاح ElevenLabs', st.elevenKey, (v) => st.elevenKey = v, secret: true),
        _VoiceRow(
          label: 'صوت ElevenLabs',
          value: st.elevenVoiceId,
          load: () => TtsService(st, widget.state.log).elevenVoices(search: 'saudi'),
          onPick: (v) => changed(() => st.elevenVoiceId = v),
          allowManual: true,
        ),
        dropdown('الموديل', st.elevenModel, {
          'eleven_multilingual_v2': 'Multilingual v2 ⭐',
          'eleven_v3': 'Eleven v3 (أكثر تعبير)',
          'eleven_flash_v2_5': 'Flash v2.5 (أسرع وأرخص)',
        }, (v) => st.elevenModel = v),
        slider('الثبات', st.elevenStability, 0, 1, (v) => st.elevenStability = v),
        slider('التعبير', st.elevenStyle, 0, 1, (v) => st.elevenStyle = v),
        const Divider(height: 28),
        const Text('Hugging Face', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        text('توكن Hugging Face', st.hfToken, (v) => st.hfToken = v, secret: true, hint: 'hf_...'),
        link('جيب توكن من huggingface.co', 'https://huggingface.co/settings/tokens'),
        text('موديل الصوت', st.hfTtsModel, (v) => st.hfTtsModel = v),
        const Divider(height: 28),
        const Text('صوت الجهاز', style: TextStyle(fontWeight: FontWeight.w800)),
        _VoiceRow(
          label: 'صوت الجهاز',
          value: st.deviceVoice,
          load: () async {
            final names = Platform.isWindows ? await TtsService.windowsVoices() : await widget.state.androidVoices();
            return names.map((n) => VoiceInfo(n.split(' | ').first, n, '')).toList();
          },
          onPick: (v) => changed(() => st.deviceVoice = v),
          hint: Platform.isWindows ? 'لو ما في صوت عربي: الإعدادات ← الوقت واللغة ← الكلام ← أضف صوت عربي' : null,
        ),
        slider('السرعة', st.deviceRate, 0.2, 1.0, (v) => st.deviceRate = v),
      ]),

      // ---------------- المقاطع ----------------
      SectionCard(title: 'المقاطع والصور', icon: Icons.video_collection_rounded, children: [
        dropdown('المصدر', st.mediaProvider, {
          MediaProvider.pexels: 'Pexels (مقاطع مجانية) ⭐',
          MediaProvider.pixabay: 'Pixabay (مقاطع مجانية)',
          MediaProvider.local: 'من ملفاتي',
          MediaProvider.aiImages: 'صور بالذكاء الاصطناعي (Hugging Face)',
          MediaProvider.gradient: 'خلفيات متحركة (بدون نت)',
        }, (v) => st.mediaProvider = v),
        text('مفتاح Pexels', st.pexelsKey, (v) => st.pexelsKey = v, secret: true),
        link('مفتاح Pexels مجاني', 'https://www.pexels.com/api/new/'),
        text('مفتاح Pixabay', st.pixabayKey, (v) => st.pixabayKey = v, secret: true),
        link('مفتاح Pixabay مجاني', 'https://pixabay.com/api/docs/'),
        folder('مجلد مقاطعي وصوري', st.localMediaFolder, (v) => st.localMediaFolder = v),
        text('موديل الصور (HF)', st.hfImageModel, (v) => st.hfImageModel = v),
      ]),

      // ---------------- الموسيقى ----------------
      SectionCard(title: 'الموسيقى', icon: Icons.music_note_rounded, children: [
        folder('مجلد الموسيقى (بيختار عشوائي)', st.musicFolder, (v) => st.musicFolder = v),
        toggle('موسيقى هادئة مولدة لو ما في ملفات', st.generatedMusic, (v) => st.generatedMusic = v),
        slider('صوت الموسيقى', st.musicVolume, 0, 0.6, (v) => st.musicVolume = v, fmt: (v) => '${(v * 100).round()}%'),
        toggle('توطية الموسيقى وقت الكلام', st.duckMusic, (v) => st.duckMusic = v),
      ]),

      // ---------------- التريند ----------------
      SectionCard(title: 'التريند', icon: Icons.trending_up_rounded, children: [
        dropdown('البلد', st.trendRegion, regionNames, (v) => st.trendRegion = v),
        text('مواضيعي (افصل بفاصلة)', st.topics.join('، '),
            (v) => st.topics = v.split(RegExp(r'[،,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
            helper: 'التشغيل التلقائي بيلف عليهم'),
        toggle('Google Trends', st.useGoogleTrends, (v) => st.useGoogleTrends = v),
        toggle('Google News', st.useGoogleNews, (v) => st.useGoogleNews = v),
        toggle('Reddit (قصص وغرائب)', st.useReddit, (v) => st.useReddit = v),
        text('Subreddits', st.subreddits.join(', '),
            (v) => st.subreddits = v.split(RegExp(r'[،,\s]+')).where((e) => e.isNotEmpty).toList()),
        toggle('YouTube الأكثر مشاهدة', st.useYoutube, (v) => st.useYoutube = v),
        text('مفتاح YouTube Data API', st.youtubeKey, (v) => st.youtubeKey = v, secret: true),
      ]),

      // ---------------- الفيديو ----------------
      SectionCard(title: 'الفيديو والشكل', icon: Icons.style_rounded, children: [
        slider('عدد الريلز بالتشغيلة', st.reelsPerRun.toDouble(), 1, 10, (v) => st.reelsPerRun = v.round(), divisions: 9, fmt: (v) => '${v.round()}'),
        slider('الطول (ثانية)', st.targetSeconds.toDouble(), 15, 90, (v) => st.targetSeconds = v.round(), divisions: 15, fmt: (v) => '${v.round()}'),
        dropdown('الدقة', st.quality, {'1080': '1080×1920 (Full HD) ⭐', '720': '720×1280 (أسرع)'}, (v) => st.quality = v),
        toggle('Claude يختار الشكل حسب الموضوع', st.randomStyle, (v) => st.randomStyle = v),
        dropdown('الشكل الافتراضي', st.styleId, {for (final s in reelStyles) s.id: s.name}, (v) => st.styleId = v),
        text('العلامة المائية', st.watermark, (v) => st.watermark = v, hint: '@حسابك'),
        toggle('جملة الافتتاح الكبيرة', st.showHook, (v) => st.showHook = v),
        toggle('كابشن كلمة بكلمة (كاريوكي)', st.karaokeCaptions, (v) => st.karaokeCaptions = v),
        toggle('شريط التقدم', st.showProgressBar, (v) => st.showProgressBar = v),
        toggle('جملة النهاية (تابعنا)', st.showCta, (v) => st.showCta = v),
        folder('مجلد الإخراج', st.outputFolder.isEmpty ? widget.state.defaultOutputDir : st.outputFolder, (v) => st.outputFolder = v),
      ]),

      // ---------------- درايف ----------------
      SectionCard(title: 'Google Drive', icon: Icons.add_to_drive_rounded, children: [
        _DriveSection(state: widget.state, onChanged: () => setState(() {})),
      ]),

      // ---------------- تلقائي ----------------
      SectionCard(title: 'التشغيل التلقائي', icon: Icons.schedule_rounded, children: [
        toggle('شغّل لحاله كل فترة', st.autoRunEnabled, (v) => st.autoRunEnabled = v, sub: 'التطبيق لازم يضل مفتوح'),
        slider('كل كم ساعة', st.autoRunHours.toDouble(), 1, 48, (v) => st.autoRunHours = v.round(), divisions: 47, fmt: (v) => '${v.round()}'),
        toggle('شغّل أول ما يفتح التطبيق', st.autoRunOnStart, (v) => st.autoRunOnStart = v),
      ]),
      const Center(child: Text('Reels Maker 1.0 • صُنع بـ Claude Code', style: TextStyle(color: Colors.grey))),
      const SizedBox(height: 20),
    ]);
  }
}

class _SettingField extends StatefulWidget {
  final String label;
  final String value;
  final bool secret;
  final String? hint;
  final String? helper;
  final int maxLines;
  final void Function(String) onChanged;
  const _SettingField(
      {required this.label, required this.value, required this.secret, this.hint, this.helper, required this.maxLines, required this.onChanged});
  @override
  State<_SettingField> createState() => _SettingFieldState();
}

class _SettingFieldState extends State<_SettingField> {
  late final c = TextEditingController(text: widget.value);
  late bool hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: c,
      obscureText: hidden,
      maxLines: hidden ? 1 : widget.maxLines,
      textDirection: widget.secret ? TextDirection.ltr : null,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        suffixIcon: widget.secret
            ? IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded))
            : null,
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final Future<List<VoiceInfo>> Function() load;
  final void Function(String) onPick;
  final String? hint;
  final bool allowManual;
  const _VoiceRow({required this.label, required this.value, required this.load, required this.onPick, this.hint, this.allowManual = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.mic_rounded),
      title: Text(label),
      subtitle: Text([value.isEmpty ? 'ما اخترت' : value, if (hint != null) hint!].join('\n')),
      trailing: FilledButton.tonal(
        onPressed: () async {
          final v = await showDialog<String>(context: context, builder: (_) => _VoicePicker(load: load, allowManual: allowManual));
          if (v != null && v.isNotEmpty) onPick(v);
        },
        child: const Text('اختار'),
      ),
    );
  }
}

class _VoicePicker extends StatefulWidget {
  final Future<List<VoiceInfo>> Function() load;
  final bool allowManual;
  const _VoicePicker({required this.load, required this.allowManual});
  @override
  State<_VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<_VoicePicker> {
  late final Future<List<VoiceInfo>> future = widget.load();
  final player = Player();
  final filter = TextEditingController();
  final manual = TextEditingController();

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختار صوت'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(children: [
          TextField(controller: filter, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'فلترة (مثلاً: najdi، male، سعودي)')),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<VoiceInfo>>(
              future: future,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('${snap.error}', textAlign: TextAlign.center));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final q = filter.text.toLowerCase();
                final list = snap.data!.where((v) => q.isEmpty || '${v.name} ${v.details} ${v.id}'.toLowerCase().contains(q)).toList();
                if (list.isEmpty) return const Center(child: Text('ما في أصوات'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(list[i].name),
                    subtitle: Text(list[i].details, maxLines: 2),
                    leading: list[i].previewUrl == null
                        ? const Icon(Icons.person_rounded)
                        : IconButton(icon: const Icon(Icons.play_circle_rounded), onPressed: () => player.open(Media(list[i].previewUrl!))),
                    onTap: () => Navigator.pop(context, list[i].id),
                  ),
                );
              },
            ),
          ),
          if (widget.allowManual)
            Row(children: [
              Expanded(child: TextField(controller: manual, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'أو الصق Voice ID', isDense: true))),
              TextButton(onPressed: () => Navigator.pop(context, manual.text.trim()), child: const Text('استخدم')),
            ]),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))],
    );
  }
}

class _DriveSection extends StatefulWidget {
  final AppState state;
  final VoidCallback onChanged;
  const _DriveSection({required this.state, required this.onChanged});
  @override
  State<_DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends State<_DriveSection> {
  AppSettings get st => widget.state.settings;
  late final id = TextEditingController(text: st.driveClientId);
  late final secret = TextEditingController(text: st.driveClientSecret);
  late final folderName = TextEditingController(text: st.driveFolderName);

  Future<void> connect() async {
    st.driveClientId = id.text.trim();
    st.driveClientSecret = secret.text.trim();
    await widget.state.saveSettings();
    final drive = DriveService(st, widget.state.log);
    DeviceCode code;
    try {
      code = await drive.startDeviceLogin();
    } catch (e) {
      if (mounted) toast(context, '$e');
      return;
    }
    if (!mounted) return;
    var cancelled = false;
    final dialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('ربط Google Drive'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('افتح الرابط وادخل هالكود وسجل دخول بحساب جوجل:'),
          const SizedBox(height: 12),
          SelectableText(code.userCode, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4), textDirection: TextDirection.ltr),
          const SizedBox(height: 8),
          TextButton(onPressed: () => openUrl(code.verificationUrl), child: Text(code.verificationUrl)),
          TextButton.icon(onPressed: () => copyText(c, code.userCode), icon: const Icon(Icons.copy), label: const Text('نسخ الكود')),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          const Text('بستنى موافقتك...'),
        ]),
        actions: [
          TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(c);
              },
              child: const Text('إلغاء')),
        ],
      ),
    );
    openUrl(code.verificationUrl);
    try {
      final token = await drive.waitForApproval(code, cancelled: () => cancelled);
      st.driveRefreshToken = token;
      st.driveFolderId = '';
      await drive.ensureFolder();
      await widget.state.saveSettings();
      if (mounted && !cancelled) {
        Navigator.of(context).pop();
        toast(context, 'انربط Google Drive ✅');
      }
    } catch (e) {
      if (mounted && !cancelled) {
        Navigator.of(context).pop();
        toast(context, '$e');
      }
    }
    await dialog;
    widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final connected = st.driveRefreshToken.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: connected ? Colors.green : null),
        title: Text(connected ? 'مربوط ✅' : 'مش مربوط'),
        subtitle: Text(connected ? 'المجلد: ${st.driveFolderName}' : 'بدك Client ID من Google Cloud (مرة وحدة بس)'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('ارفع تلقائياً بعد كل ريل'),
        value: st.autoUpload,
        onChanged: (v) {
          setState(() => st.autoUpload = v);
          widget.state.saveSettings();
        },
      ),
      TextField(
        controller: folderName,
        decoration: const InputDecoration(labelText: 'اسم المجلد على درايف'),
        onChanged: (v) {
          st.driveFolderName = v.trim();
          st.driveFolderId = '';
          widget.state.saveSettings();
        },
      ),
      const SizedBox(height: 10),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Client ID و Secret'),
        initiallyExpanded: !connected,
        children: [
          const Text(
              'الخطوات (مرة وحدة):\n'
              '1. افتح console.cloud.google.com واعمل مشروع.\n'
              '2. فعّل Google Drive API.\n'
              '3. OAuth consent screen ← External ← ضيف إيميلك كـ Test user.\n'
              '4. Credentials ← Create OAuth client ID ← النوع: TVs and Limited Input devices.\n'
              '5. انسخ Client ID و Client secret لهون واضغط ربط.'),
          TextButton.icon(
              onPressed: () => openUrl('https://console.cloud.google.com/apis/credentials'),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('فتح Google Cloud Console')),
          const SizedBox(height: 8),
          TextField(controller: id, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Client ID')),
          const SizedBox(height: 8),
          TextField(controller: secret, textDirection: TextDirection.ltr, obscureText: true, decoration: const InputDecoration(labelText: 'Client secret')),
          const SizedBox(height: 8),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        FilledButton.icon(onPressed: connect, icon: const Icon(Icons.link_rounded), label: Text(connected ? 'إعادة الربط' : 'ربط Google Drive')),
        if (connected)
          OutlinedButton(
            onPressed: () {
              setState(() {
                st.driveRefreshToken = '';
                st.driveFolderId = '';
              });
              widget.state.saveSettings();
            },
            child: const Text('فصل'),
          ),
      ]),
    ]);
  }
}
