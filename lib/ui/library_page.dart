import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_state.dart';
import '../core/models.dart';
import '../core/styles.dart';
import 'editor_page.dart';
import 'player.dart';
import 'widgets.dart';

class LibraryPage extends StatelessWidget {
  final AppState state;
  const LibraryPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final items = state.projects;
        return Scaffold(
          appBar: AppBar(
            title: const Text('المكتبة', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                  tooltip: 'فتح مجلد الفيديوهات',
                  onPressed: () => openPath(state.outputDir),
                  icon: const Icon(Icons.folder_open_rounded)),
              IconButton(onPressed: state.refreshProjects, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text('لسا ما في ريلز. روح عالرئيسية واضغط "ابدأ الآن" 🚀'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220, childAspectRatio: 9 / 19, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ReelCard(state: state, project: items[i]),
                ),
        );
      },
    );
  }
}

class _ReelCard extends StatelessWidget {
  final AppState state;
  final ReelProject project;
  const _ReelCard({required this.state, required this.project});

  @override
  Widget build(BuildContext context) {
    final thumb = project.thumbnailPath;
    final (label, color) = switch (project.status) {
      ReelStatus.uploaded => ('على درايف', Colors.blue),
      ReelStatus.rendered => ('جاهز', Colors.green),
      ReelStatus.rendering => ('عم يتعمل', Colors.amber),
      ReelStatus.failed => ('فشل', Colors.red),
      ReelStatus.draft => ('مسودة', Colors.grey),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReelDetailPage(state: state, project: project))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              if (thumb != null && File(thumb).existsSync())
                Image.file(File(thumb), fit: BoxFit.cover)
              else
                Container(color: Colors.black26, child: const Icon(Icons.movie_rounded, size: 48)),
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(project.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class ReelDetailPage extends StatefulWidget {
  final AppState state;
  final ReelProject project;
  const ReelDetailPage({super.key, required this.state, required this.project});
  @override
  State<ReelDetailPage> createState() => _ReelDetailPageState();
}

class _ReelDetailPageState extends State<ReelDetailPage> {
  ReelProject get r => widget.project;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final hasVideo = r.outputPath != null && File(r.outputPath!).existsSync();
    final wide = MediaQuery.sizeOf(context).width > 900;
    final player = hasVideo
        ? ConstrainedBox(constraints: const BoxConstraints(maxHeight: 640), child: ReelPlayer(path: r.outputPath!))
        : const SizedBox(height: 200, child: Center(child: Text('الفيديو لسا ما انعمل')));
    final info = ListenableBuilder(
      listenable: s,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(r.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('الشكل: ${styleById(r.styleId).name} • ${r.scenes.length} مشاهد'),
        if (r.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('الخطأ: ${r.error}', style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 12),
        SectionCard(title: 'نص المنشور', icon: Icons.notes_rounded, children: [
          SelectableText(r.postText()),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(onPressed: () => copyText(context, r.postText()), icon: const Icon(Icons.copy_rounded), label: const Text('نسخ')),
          ),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (hasVideo)
            FilledButton.icon(
              onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(r.outputPath!)], text: r.postText())),
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة (انستغرام، تيك توك...)'),
            ),
          if (hasVideo)
            FilledButton.tonalIcon(
              onPressed: s.running
                  ? null
                  : () async {
                      if (!s.settings.driveRefreshToken.isNotEmpty) {
                        toast(context, 'اربط Google Drive من الإعدادات أول');
                        return;
                      }
                      await s.run('رفع على درايف', (p) => p.uploadToDrive(r));
                      if (mounted) setState(() {});
                    },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('رفع على درايف'),
            ),
          if (r.driveLink != null)
            OutlinedButton.icon(onPressed: () => openUrl(r.driveLink!), icon: const Icon(Icons.link_rounded), label: const Text('فتح بدرايف')),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(state: s, project: r)));
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('تعديل'),
          ),
          if (hasVideo && !Platform.isAndroid)
            OutlinedButton.icon(onPressed: () => openPath(File(r.outputPath!).parent.path), icon: const Icon(Icons.folder_rounded), label: const Text('المجلد')),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('حذف الريل؟'),
                  content: const Text('بينحذف المشروع وملفاته المؤقتة. الفيديو النهائي بمجلد الإخراج بيضل.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('احذف')),
                  ],
                ),
              );
              if (ok == true) {
                await s.store.delete(r.id);
                await s.refreshProjects();
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف'),
          ),
        ]),
        const SizedBox(height: 12),
        RunPanel(state: s),
      ]),
    );
    return Scaffold(
      appBar: AppBar(title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: wide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 360, child: player),
                const SizedBox(width: 20),
                Expanded(child: SingleChildScrollView(child: info)),
              ]),
            )
          : ListView(padding: const EdgeInsets.all(16), children: [Center(child: SizedBox(width: 340, child: player)), const SizedBox(height: 16), info]),
    );
  }
}
