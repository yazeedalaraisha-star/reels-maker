import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app_state.dart';
import '../core/models.dart';
import '../core/styles.dart';
import 'widgets.dart';

class EditorPage extends StatefulWidget {
  final AppState state;
  final ReelProject project;
  const EditorPage({super.key, required this.state, required this.project});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  ReelProject get r => widget.project;
  late final title = TextEditingController(text: r.title);
  late final hook = TextEditingController(text: r.hook);
  late final caption = TextEditingController(text: r.caption);
  late final tags = TextEditingController(text: r.hashtags.join(' '));
  late final cta = TextEditingController(text: r.cta);

  void _apply() {
    r.title = title.text.trim();
    r.hook = hook.text.trim();
    r.caption = caption.text.trim();
    r.hashtags = tags.text.split(RegExp(r'[\s,،]+')).map((e) => e.replaceAll('#', '')).where((e) => e.isNotEmpty).toList();
    r.cta = cta.text.trim();
  }

  Future<void> _save() async {
    _apply();
    await widget.state.store.save(r);
    await widget.state.refreshProjects();
    if (mounted) toast(context, 'انحفظ ✅');
  }

  Future<void> _render() async {
    _apply();
    await widget.state.store.save(r);
    await widget.state.run('مونتاج "${r.title}"', (p) => p.produce(r));
    if (mounted) setState(() {});
  }

  Future<String?> _pickFile(FileType type) async {
    final res = await FilePicker.pickFiles(type: type);
    return res.isEmpty ? null : res.single.path;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الريل'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_rounded), tooltip: 'حفظ'),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: s,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed: s.running ? null : _render,
          icon: s.running ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.movie_creation_rounded),
          label: Text(s.running ? s.stage : 'اعمل الفيديو'),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            SectionCard(title: 'معلومات الريل', icon: Icons.info_outline_rounded, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 10),
              TextField(controller: hook, decoration: const InputDecoration(labelText: 'جملة الافتتاح (بتظهر كبيرة أول ثواني)')),
              const SizedBox(height: 10),
              TextField(controller: caption, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف المنشور')),
              const SizedBox(height: 10),
              TextField(controller: tags, decoration: const InputDecoration(labelText: 'الهاشتاجات (افصل بمسافة)')),
              const SizedBox(height: 10),
              TextField(controller: cta, decoration: const InputDecoration(labelText: 'جملة النهاية')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: styleById(r.styleId).id,
                decoration: const InputDecoration(labelText: 'الشكل'),
                items: [for (final st in reelStyles) DropdownMenuItem(value: st.id, child: Text(st.name))],
                onChanged: (v) => setState(() => r.styleId = v ?? r.styleId),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(r.musicPath == null ? 'الموسيقى: تلقائي' : 'الموسيقى: ${p.basename(r.musicPath!)}')),
                TextButton(
                    onPressed: () async {
                      final f = await _pickFile(FileType.audio);
                      if (f != null) setState(() => r.musicPath = f);
                    },
                    child: const Text('اختار')),
                if (r.musicPath != null) TextButton(onPressed: () => setState(() => r.musicPath = null), child: const Text('تلقائي')),
              ]),
            ]),
            Row(children: [
              Text('المشاهد (${r.scenes.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => r.scenes.add(Scene(narration: ''))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('مشهد جديد'),
              ),
            ]),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (a, b) => setState(() => r.scenes.insert(b, r.scenes.removeAt(a))),
              children: [
                for (var i = 0; i < r.scenes.length; i++)
                  _SceneCard(
                    key: ObjectKey(r.scenes[i]),
                    index: i,
                    scene: r.scenes[i],
                    state: s,
                    onChanged: () => setState(() {}),
                    onDelete: () => setState(() => r.scenes.removeAt(i)),
                    pickMedia: () async {
                      final f = await _pickFile(FileType.media);
                      if (f != null) setState(() => r.scenes[i].mediaPath = f);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            RunPanel(state: s),
          ]),
        ),
      ),
    );
  }
}

class _SceneCard extends StatefulWidget {
  final int index;
  final Scene scene;
  final AppState state;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback pickMedia;
  const _SceneCard({
    super.key,
    required this.index,
    required this.scene,
    required this.state,
    required this.onChanged,
    required this.onDelete,
    required this.pickMedia,
  });
  @override
  State<_SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<_SceneCard> {
  Scene get sc => widget.scene;
  late final narration = TextEditingController(text: sc.narration);
  late final onScreen = TextEditingController(text: sc.onScreen);
  late final query = TextEditingController(text: sc.searchQuery);
  late final highlights = TextEditingController(text: sc.highlights.join('، '));
  bool busy = false;

  Future<void> _rewrite(String how) async {
    setState(() => busy = true);
    try {
      final w = widget.state.newPipeline().writer;
      final t = await w.rewriteLine(narration.text, how);
      narration.text = t;
      _narrationChanged(t);
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _narrationChanged(String v) {
    if (v != sc.narration) {
      sc.narration = v;
      // النص تغير، فالصوت القديم ما عاد ينفع
      sc.audioPath = null;
      sc.audioDuration = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = sc.mediaPath;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ReorderableDragStartListener(index: widget.index, child: const Icon(Icons.drag_indicator_rounded)),
            const SizedBox(width: 6),
            Text('مشهد ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            PopupMenuButton<String>(
              tooltip: 'إعادة كتابة بالذكاء الاصطناعي',
              icon: const Icon(Icons.auto_fix_high_rounded),
              onSelected: _rewrite,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'خليها أقصر وأقوى.', child: Text('أقصر وأقوى')),
                PopupMenuItem(value: 'خليها أكثر تشويق وحماس.', child: Text('أكثر تشويق')),
                PopupMenuItem(value: 'خليها مضحكة وخفيفة دم.', child: Text('مضحكة')),
                PopupMenuItem(value: 'خليها أوضح وأبسط.', child: Text('أوضح')),
              ],
            ),
            IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'حذف المشهد'),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: narration,
            maxLines: 3,
            minLines: 2,
            onChanged: _narrationChanged,
            decoration: const InputDecoration(labelText: 'التعليق الصوتي / الكابشن'),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(
              width: 220,
              child: TextField(controller: onScreen, onChanged: (v) => sc.onScreen = v, decoration: const InputDecoration(labelText: 'عنوان المشهد', isDense: true)),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                  controller: highlights,
                  onChanged: (v) => sc.highlights = v.split(RegExp(r'[،,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  decoration: const InputDecoration(labelText: 'كلمات ملونة', isDense: true)),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                  controller: query,
                  onChanged: (v) {
                    sc.searchQuery = v;
                  },
                  decoration: const InputDecoration(labelText: 'بحث المقطع (إنجليزي)', isDense: true)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
            Icon(media == null ? Icons.gradient_rounded : Icons.movie_rounded, size: 18),
            Text(media == null ? 'المقطع: تلقائي' : p.basename(media), overflow: TextOverflow.ellipsis),
            TextButton(onPressed: widget.pickMedia, child: const Text('اختار من جهازي')),
            if (media != null)
              TextButton(
                  onPressed: () {
                    sc.mediaPath = null;
                    widget.onChanged();
                  },
                  child: const Text('بدّل تلقائي')),
            Icon(sc.audioPath != null && File(sc.audioPath!).existsSync() ? Icons.graphic_eq_rounded : Icons.mic_off_rounded, size: 18),
            Text(sc.audioDuration != null ? 'صوت ${sc.audioDuration!.toStringAsFixed(1)}ث' : 'الصوت بيتولد'),
            if (sc.audioPath != null)
              TextButton(
                  onPressed: () {
                    sc.audioPath = null;
                    sc.audioDuration = null;
                    widget.onChanged();
                  },
                  child: const Text('أعد توليد الصوت')),
          ]),
        ]),
      ),
    );
  }
}
