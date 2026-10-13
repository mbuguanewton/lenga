import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/calendar_provider.dart';
import '../../data/providers.dart';
import '../../logic/problem_source.dart';
import '../../models/problem.dart';
import '../../models/settings.dart';
import '../shell.dart';
import '../widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apps = ref.watch(blockedAppsProvider);
    final cal = ref.watch(calendarProvider);
    final perms = ref.watch(permissionsProvider).value;
    final ai = ref.watch(aiStatusProvider).value;
    final bridge = ref.read(bridgeProvider);

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Eyebrow(t),
        );
    Widget hint(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Text(t, style: TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, kFloatingNavClearance),
      children: [
        const Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(height: 24),
        label('Challenge difficulty'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<Difficulty>(
            showSelectedIcon: false,
            segments: [
              for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {settings.difficulty},
            onSelectionChanged: (s) => notifier.update(settings.copyWith(difficulty: s.first)),
          ),
        ),
        hint("Adaptive mixes problem types so you can't memorize an answer."),
        label('Lockout duration'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final m in LengaSettings.lockoutOptions) ButtonSegment(value: m, label: Text('$m min')),
            ],
            selected: {settings.lockoutMinutes},
            onSelectionChanged: (s) => notifier.update(settings.copyWith(lockoutMinutes: s.first)),
          ),
        ),
        hint('How long you wait after running out of attempts, instead of solving the problem.'),
        LengaCard(
          child: Column(
            children: [
              _Row('Blocked apps', '${apps.length} ${apps.length == 1 ? 'app' : 'apps'}',
                  onTap: () => ref.read(selectedTabProvider.notifier).select(AppTab.home)),
              _Row('Calendar connection', cal.connected ? 'Connected' : 'Not connected',
                  onTap: () => ref.read(selectedTabProvider.notifier).select(AppTab.calendar)),
              _Row('Usage access', perms == null ? '…' : (perms.usageAccess ? 'Granted' : 'Grant'),
                  onTap: perms?.usageAccess == true ? null : bridge.openUsageAccessSettings),
              _Row('Display over other apps', perms == null ? '…' : (perms.overlay ? 'Granted' : 'Grant'),
                  onTap: perms?.overlay == true ? null : bridge.openOverlaySettings),
              _Row('Notifications', perms == null ? '…' : (perms.notifications ? 'On' : 'Off'),
                  onTap: perms?.notifications == true ? null : bridge.requestNotifications),
              _Row('Battery settings', 'Set to Unrestricted', onTap: bridge.openBatterySettings),
              _Row('AI-generated problems', switch (ai) {
                AiAvailability.available => 'On',
                AiAvailability.downloading => 'Downloading model…',
                _ => 'Unavailable on this device',
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(child: Text('Lenga v1.0', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.title, this.value, {this.onTap});

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            Flexible(
              child: Text(onTap == null ? value : '$value ›',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
