import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/models.dart';
import 'widgets.dart';

class TrendsPage extends StatefulWidget {
  final AppState state;
  final void Function(int) go;
  const TrendsPage({super.key, required this.state, required this.go});
  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  final query = TextEditingController();
  List<TrendItem> items = [];
  final selected = <int>{};
  bool loading = false;

  Future<void> fetch() async {
    setState(() {
      loading = true;
      selected.clear();
    });
    try {
      final p = widget.state.newPipeline();
      final r = await p.trends.fetchAll(topic: query.text.trim().isEmpty ? null : query.text.trim());
      setState(() => items = r);
      if (r.isEmpty && mounted) toast(context, 'ما لقيت شي، تأكد من النت');
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return PageScaffold(
      title: 'التريند',
      actions: [
        IconButton(onPressed: loading ? null : fetch, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
      ],
      children: [
        SectionCard(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: query,
                onSubmitted: (_) => fetch(),
                decoration: const InputDecoration(
                    labelText: 'دوّر بموضوع معين (أو خليه فاضي لترند اليوم)', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: loading ? null : fetch, child: const Text('جيب')),
          ]),
          const SizedBox(height: 8),
          Text('المنطقة: ${s.settings.trendRegion} • اختار التريندات اللي بدك ريلز عنها'),
        ]),
        if (selected.isNotEmpty)
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: s.running
                ? null
                : () => s.run('ريلز من التريند', (p) => p.runAuto(
                    topic: query.text.trim().isEmpty ? 'ترند اليوم' : query.text.trim(),
                    picked: selected.map((i) => items[i]).toList())),
            icon: const Icon(Icons.movie_creation_rounded),
            label: Text('اصنع ${selected.length} ريلز من المختار'),
          ),
        const SizedBox(height: 10),
        RunPanel(state: s),
        if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        for (var i = 0; i < items.length; i++)
          Card(
            child: CheckboxListTile(
              value: selected.contains(i),
              onChanged: (v) => setState(() => v == true ? selected.add(i) : selected.remove(i)),
              title: Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                [items[i].source, if (items[i].traffic != null) items[i].traffic!, if (items[i].summary != null) items[i].summary!]
                    .join(' • '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              secondary: items[i].url == null
                  ? null
                  : IconButton(icon: const Icon(Icons.open_in_new_rounded), onPressed: () => openUrl(items[i].url!)),
            ),
          ),
      ],
    );
  }
}
