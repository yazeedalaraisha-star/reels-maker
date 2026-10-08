import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_state.dart';

class PageScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  const PageScaffold({super.key, required this.title, required this.children, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), actions: actions),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(padding: const EdgeInsets.all(16), children: children),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final List<Widget> children;
  const SectionCard({super.key, this.title, this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
          ...children,
        ]),
      ),
    );
  }
}

/// لوحة التقدم والسجل المباشر، بتظهر بكل صفحات التشغيل.
class RunPanel extends StatelessWidget {
  final AppState state;
  const RunPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (!state.running && state.logs.isEmpty) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return SectionCard(
          title: state.running ? 'شغّال: ${state.stage}' : 'آخر تشغيلة',
          icon: state.running ? Icons.hourglass_top_rounded : Icons.history_rounded,
          children: [
            if (state.running) ...[
              LinearProgressIndicator(value: state.progress <= 0 ? null : state.progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 8),
              Row(children: [
                Text('${(state.progress * 100).round()}%'),
                const Spacer(),
                TextButton.icon(onPressed: state.cancel, icon: const Icon(Icons.stop_circle_outlined), label: const Text('إلغاء')),
              ]),
            ],
            Container(
              height: 220,
              decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(10),
              child: ListView.builder(
                reverse: true,
                itemCount: state.logs.length,
                itemBuilder: (_, i) {
                  final l = state.logs[state.logs.length - 1 - i];
                  final t = '${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText('$t  ${l.text}', style: const TextStyle(fontSize: 13)),
                  );
                },
              ),
            ),
            if (!state.running)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: state.clearLogs, child: const Text('مسح السجل')),
              ),
          ],
        );
      },
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'انسخ ✅');
}

Future<void> openPath(String path) async {
  if (Platform.isWindows) {
    await Process.run('explorer', [path]);
  } else {
    await launchUrl(Uri.file(path));
  }
}

Future<void> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
