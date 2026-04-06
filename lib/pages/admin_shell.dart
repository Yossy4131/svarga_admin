import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'events_page.dart';
import 'applications_page.dart';
import 'casts_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.client});

  final ApiClient client;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event),
      label: 'イベント',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox),
      label: '応募一覧',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_alt_outlined),
      selectedIcon: Icon(Icons.people_alt),
      label: 'キャスト',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      EventsPage(client: widget.client),
      ApplicationsPage(client: widget.client),
      CastsPage(client: widget.client),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: const Color(0xFF111850),
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFB38246),
                      size: 28,
                    ),
                  ),
                  destinations: _destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(
                          onPressed: () =>
                              Navigator.of(context).pushReplacementNamed('/'),
                          icon: const Icon(Icons.logout, color: Colors.white54),
                          tooltip: 'ログアウト',
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0x33FFFFFF)),
                Expanded(child: pages[_index]),
              ],
            ),
          );
        }

        return Scaffold(
          body: pages[_index],
          bottomNavigationBar: NavigationBar(
            backgroundColor: const Color(0xFF111850),
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: _destinations,
          ),
        );
      },
    );
  }
}
