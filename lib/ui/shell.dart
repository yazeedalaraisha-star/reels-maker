import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'home_page.dart';
import 'idea_page.dart';
import 'library_page.dart';
import 'settings_page.dart';
import 'trends_page.dart';

class Shell extends StatefulWidget {
  final AppState state;
  const Shell({super.key, required this.state});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pages = [
      HomePage(state: s, go: go),
      TrendsPage(state: s, go: go),
      IdeaPage(state: s, go: go),
      LibraryPage(state: s),
      SettingsPage(state: s),
    ];
    const dests = [
      (Icons.auto_awesome_rounded, 'الرئيسية'),
      (Icons.trending_up_rounded, 'التريند'),
      (Icons.lightbulb_rounded, 'من فكرتي'),
      (Icons.video_library_rounded, 'المكتبة'),
      (Icons.settings_rounded, 'الإعدادات'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = IndexedStack(index: index, children: pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.movie_filter_rounded, size: 40),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: [
          for (final d in dests) NavigationDestination(icon: Icon(d.$1), label: d.$2),
        ],
      ),
    );
  }
}
