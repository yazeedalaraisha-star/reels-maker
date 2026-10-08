import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/settings.dart';
import '../services/free_tts.dart';
import 'widgets.dart';

const quickTopics = [
  'ترند اليوم',
  'أخبار السعودية',
  'أخبار الأردن',
  'قصص رعب حقيقية',
  'قصص نجاح ملهمة',
  'معلومات غريبة',
  'تقنية وذكاء اصطناعي',
  'رياضة وكرة قدم',
  'سيارات',
  'مال وأعمال',
  'ألغاز وغموض',
  'تاريخ وحضارات',
];

class HomePage extends StatefulWidget {
  final AppState state;
  final void Function(int) go;
  const HomePage({super.key, required this.state, required this.go});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final topic = TextEditingController(
      text: widget.state.settings.topics.isEmpty ? 'ترند اليوم' : widget.state.settings.topics.first);

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final st = s.settings;
        final voice = freeArabicVoices.firstWhere((v) => v.id == st.edgeVoice, orElse: () => freeArabicVoices.first);
        final checks = <(String, bool, String)>[
          ('كتابة السكربت', true, st.anthropicKey.isNotEmpty && st.scriptProvider == ScriptProvider.claude ? 'Claude' : st.scriptProvider == ScriptProvider.offline ? 'بسيط بدون نت' : 'ذكاء اصطناعي مجاني'),
          ('التعليق الصوتي', true, _ttsReady(st) ? _ttsLabel(st) : 'صوت مجاني: ${voice.name} (${voice.details.split(' •').first})'),
          ('المقاطع والصور', true, _mediaReady(st) ? _mediaLabel(st) : 'صور ذكاء اصطناعي مجانية'),
          ('Google Drive', st.driveRefreshToken.isNotEmpty || st.driveSyncFolder.isNotEmpty,
              st.driveRefreshToken.isNotEmpty ? 'مربوط' : st.driveSyncFolder.isNotEmpty ? 'بينحفظ بمجلد درايف على الكمبيوتر' : 'اختياري: الفيديوهات بتنحفظ بالجهاز'),
        ];
        return PageScaffold(title: 'صانع الريلز', children: [
          SectionCard(children: [
            Text('اصنع ${st.reelsPerRun} ريلز كاملة بضغطة وحدة',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('بيجيب التريند ← بيكتب السكربت ← تعليق صوتي ← مقاطع ← مونتاج وموشن جرافيك ← رفع على درايف'),
            const SizedBox(height: 16),
            TextField(
              controller: topic,
              decoration: const InputDecoration(labelText: 'الموضوع', prefixIcon: Icon(Icons.topic_rounded)),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in quickTopics)
                ActionChip(label: Text(t), onPressed: () => setState(() => topic.text = t)),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: s.running ? null : () => s.autoRunNow(topic: topic.text.trim()),
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(s.running ? 'شغّال...' : 'ابدأ الآن', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ]),
          RunPanel(state: s),
          SectionCard(title: 'الجاهزية', icon: Icons.fact_check_rounded, children: [
            for (final c in checks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(c.$2 ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: c.$2 ? Colors.green : Colors.orange),
                title: Text(c.$1),
                subtitle: Text(c.$3),
                trailing: c.$2 ? null : TextButton(onPressed: () => widget.go(4), child: const Text('إعداد')),
              ),
            if (st.autoRunEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text('تشغيل تلقائي كل ${st.autoRunHours} ساعة'),
                subtitle: Text(s.nextAutoRun == null ? '' : 'الجاية: ${_fmt(s.nextAutoRun!)} (لازم التطبيق يكون مفتوح)'),
              ),
          ]),
          if (s.projects.isNotEmpty)
            SectionCard(title: 'آخر الريلز', icon: Icons.video_library_rounded, children: [
              for (final r in s.projects.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.movie_rounded),
                  title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(r.status.name == 'uploaded'
                      ? 'انرفع على درايف ☁️'
                      : r.status.name == 'rendered'
                          ? 'جاهز ✅'
                          : r.status.name == 'failed'
                              ? 'فشل ❌'
                              : 'مسودة'),
                  onTap: () => widget.go(3),
                ),
            ]),
        ]);
      },
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  bool _ttsReady(AppSettings s) => switch (s.ttsProvider) {
        TtsProvider.edge || TtsProvider.google => false,
        TtsProvider.munsit => s.munsitKey.isNotEmpty && s.munsitVoiceId.isNotEmpty,
        TtsProvider.elevenlabs => s.elevenKey.isNotEmpty && s.elevenVoiceId.isNotEmpty,
        TtsProvider.huggingface => s.hfToken.isNotEmpty,
        TtsProvider.device => true,
        TtsProvider.none => true,
      };
  String _ttsLabel(AppSettings s) => switch (s.ttsProvider) {
        TtsProvider.edge || TtsProvider.google => 'مجاني',
        TtsProvider.munsit => _ttsReady(s) ? 'منصت' : 'منصت: حط المفتاح واختار صوت',
        TtsProvider.elevenlabs => _ttsReady(s) ? 'ElevenLabs' : 'ElevenLabs: حط المفتاح واختار صوت',
        TtsProvider.huggingface => _ttsReady(s) ? 'Hugging Face' : 'حط توكن Hugging Face',
        TtsProvider.device => 'صوت الجهاز (أوفلاين)',
        TtsProvider.none => 'بدون صوت',
      };
  bool _mediaReady(AppSettings s) => switch (s.mediaProvider) {
        MediaProvider.freeAi || MediaProvider.openverse => false,
        MediaProvider.pexels => s.pexelsKey.isNotEmpty,
        MediaProvider.pixabay => s.pixabayKey.isNotEmpty,
        MediaProvider.local => s.localMediaFolder.isNotEmpty,
        MediaProvider.aiImages => s.hfToken.isNotEmpty,
        MediaProvider.gradient => true,
      };
  String _mediaLabel(AppSettings s) => switch (s.mediaProvider) {
        MediaProvider.freeAi => 'صور AI مجانية',
        MediaProvider.openverse => 'صور حقيقية مجانية',
        MediaProvider.pexels => _mediaReady(s) ? 'Pexels' : 'حط مفتاح Pexels (مجاني)',
        MediaProvider.pixabay => _mediaReady(s) ? 'Pixabay' : 'حط مفتاح Pixabay (مجاني)',
        MediaProvider.local => _mediaReady(s) ? 'ملفاتك' : 'اختار مجلد المقاطع',
        MediaProvider.aiImages => _mediaReady(s) ? 'صور AI' : 'حط توكن Hugging Face',
        MediaProvider.gradient => 'خلفيات متحركة (أوفلاين)',
      };
}
