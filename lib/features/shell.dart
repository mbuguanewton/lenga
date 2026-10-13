import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calendar_provider.dart';
import '../data/providers.dart';
import 'calendar/calendar_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';
import 'stats/stats_screen.dart';

/// Bottom padding for tab screens so the last item clears the floating nav bar
/// (bar height + its margin + room for the gesture inset).
const kFloatingNavClearance = 124.0;

enum AppTab { home, calendar, stats, settings }

class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, AppTab>(SelectedTabNotifier.new);

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Providers can't be changed while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onForeground();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onForeground();
  }

  /// Re-check everything that can change while Lenga is in the background.
  void _onForeground() {
    ref.invalidate(permissionsProvider);
    ref.invalidate(blockingPausedProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(aiStatusProvider);
    // Make sure the service matches the block list (it may have been killed).
    ref.read(nativeSyncProvider)();
    ref.read(calendarProvider.notifier).refresh();
    ref.read(aiGeneratorProvider).refill(ref.read(settingsProvider).difficulty);
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(selectedTabProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      // Content scrolls behind the floating bar; screens pad by [kFloatingNavClearance].
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab.index,
          children: const [HomeScreen(), CalendarScreen(), StatsScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: NavigationBar(
              height: 68,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              selectedIndex: tab.index,
              onDestinationSelected: (i) {
                ref.read(selectedTabProvider.notifier).select(AppTab.values[i]);
                if (AppTab.values[i] == AppTab.stats) ref.invalidate(statsProvider);
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_today),
                    label: 'Calendar'),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Stats'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
