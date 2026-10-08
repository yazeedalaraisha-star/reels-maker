import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'editor_page.dart';
import 'widgets.dart';

class IdeaPage extends StatefulWidget {
  final AppState state;
  final void Function(int) go;
  const IdeaPage({super.key, required this.state, required this.go});
  @override
  State<IdeaPage> createState() => _IdeaPageState();
}

class _IdeaPageState extends State<IdeaPage> {
  final idea = TextEditingController();
  double count = 1;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => PageScaffold(title: 'من فكرتي', children: [
        SectionCard(children: [
          const Text('اكتب فكرة، قصة، خبر، أو حتى سكربت كامل. لو في مفتاح Claude رح يكتبلك سكربت احترافي، ولو ما في نت رح يقسم نصك لمشاهد.'),
          const SizedBox(height: 12),
          TextField(
            controller: idea,
            onChanged: (_) => setState(() {}),
            minLines: 5,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: 'مثلاً: قصة الرجل اللي لقى كنز بحديقة بيته، أو: 5 معلومات ما بتعرفها عن البتراء',
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('عدد الريلز:'),
            Expanded(
              child: Slider(value: count, min: 1, max: 5, divisions: 4, label: '${count.round()}', onChanged: (v) => setState(() => count = v)),
            ),
            Text('${count.round()}'),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: s.running || idea.text.trim().isEmpty
                  ? null
                  : () => s.run('ريلز من فكرتك', (p) => p.runIdea(idea.text.trim(), count: count.round())),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('اصنع الفيديو كامل'),
            ),
            OutlinedButton.icon(
              onPressed: s.running || idea.text.trim().isEmpty
                  ? null
                  : () async {
                      final reels = await s.run('كتابة السكربت', (p) async {
                        final r = await p.writer.fromIdea(idea.text.trim(), count: count.round());
                        for (final x in r) {
                          await p.store.save(x);
                        }
                        return r;
                      });
                      if (reels != null && reels.isNotEmpty && context.mounted) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(state: s, project: reels.first)));
                      }
                    },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('اكتب السكربت وخليني أعدّل'),
            ),
          ]),
        ]),
        RunPanel(state: s),
      ]),
    );
  }
}
