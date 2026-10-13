import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/calendar_provider.dart';
import '../../data/providers.dart';
import '../../logic/block_status.dart';
import '../../logic/stats_summary.dart';
import '../../models/blocked_app.dart';
import '../add_apps/add_apps_screen.dart';
import '../challenge/challenge_screen.dart';
import '../shell.dart';
import '../widgets.dart';
import 'today_events.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final apps = ref.watch(blockedAppsProvider);
    final stats = ref.watch(statsProvider).value ?? StatsSummary.empty;
    final cal = ref.watch(calendarProvider);
    final perms = ref.watch(permissionsProvider).value;
    final paused = ref.watch(blockingPausedProvider).value ?? false;
    final bridge = ref.read(bridgeProvider);


    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, kFloatingNavClearance),
      children: [
        ScreenTitle(
          _greeting(),
          apps.isEmpty
              ? 'Add an app to start blocking.'
              : "You're protected from ${apps.length} ${apps.length == 1 ? 'app' : 'apps'} today.",
        ),
        if (apps.isNotEmpty && perms != null && !perms.blockingReady)
          Banner2(
            message: 'Blocking is off until Lenga has Usage access and Display over other apps.',
            actionLabel: 'Fix',
            onAction: () => ref.read(selectedTabProvider.notifier).select(AppTab.settings),
          )
        else if (apps.isNotEmpty && paused)
          Banner2(
            message: 'Blocking is paused. Your phone may have stopped Lenga to save battery.',
            actionLabel: 'Restart',
            onAction: () async {
              await ref.read(nativeSyncProvider)();
              await bridge.openBatterySettings();
              ref.invalidate(blockingPausedProvider);
            },
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(28)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAVED TODAY',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.96,
                          color: cs.onPrimary.withValues(alpha: 0.85))),
                  const SizedBox(height: 6),
                  Text(formatMinutes(stats.savedTodayMinutes),
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: cs.onPrimary)),
                ],
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.lock_outline, color: cs.onPrimaryContainer, size: 26),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Blocked apps', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const AddAppsScreen())),
              child: const Text('Add app', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (apps.isEmpty)
          LengaCard(
            padding: const EdgeInsets.all(24),
            child: Text('No apps yet. Tap "Add app" to choose the ones you want out of easy reach.',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
          )
        else
          LengaCard(
            child: Column(
              children: [
                for (final app in apps)
                  _AppRow(
                    app: app,
                    savedToday: stats.savedTodayByApp[app.packageName] ?? 0,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (!cal.connected)
          Material(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => ref.read(selectedTabProvider.notifier).select(AppTab.calendar),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CALENDAR',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.88,
                                  color: cs.onSecondaryContainer.withValues(alpha: 0.7))),
                          const SizedBox(height: 4),
                          Text('Connect your calendar',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSecondaryContainer),
                  ],
                ),
              ),
            ),
          )
        else
          const TodayEvents(),
      ],
    );
  }
}

class _AppRow extends ConsumerWidget {
  const _AppRow({required this.app, required this.savedToday});

  final BlockedApp app;
  final int savedToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          AppAvatar(app.letter),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${formatMinutes(savedToday)} today',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          _StatusChip(packageName: app.packageName),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
            onSelected: (v) => v == 'preview'
                ? _tryOpening(context, ref)
                : ref.read(blockedAppsProvider.notifier).remove(app.packageName),
            itemBuilder: (_) => [
              // Previewing the challenge in-app is a development aid only.
              if (kDebugMode) const PopupMenuItem(value: 'preview', child: Text('Preview challenge (debug)')),
              const PopupMenuItem(value: 'remove', child: Text('Stop blocking')),
            ],
          ),
        ],
      ),
    );
  }

  void _tryOpening(BuildContext context, WidgetRef ref) {
    final nav = Navigator.of(context);
    nav
        .push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ChallengeScreen(
            packageName: app.packageName,
            appName: app.name,
            onClose: nav.pop,
            onContinue: nav.pop,
          ),
        ))
        .then((_) => ref.invalidate(statsProvider));
  }
}

/// Live state of one blocked app: Blocked / Open for N min / Locked mm:ss /
/// Blocked until h:mm. Ticks every second so countdowns and expiries stay live.
class _StatusChip extends ConsumerStatefulWidget {
  const _StatusChip({required this.packageName});

  final String packageName;

  @override
  ConsumerState<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends ConsumerState<_StatusChip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = ref.watch(blockStatusProvider).value ?? BlockStatus.empty;
    final now = DateTime.now();
    final state = status.stateFor(widget.packageName, now);
    final left = state.until?.difference(now) ?? Duration.zero;

    final (String label, Color bg, Color fg) = switch (state.kind) {
      AppBlockKind.blocked => ('Blocked', cs.surfaceContainerHighest, cs.onSurfaceVariant),
      AppBlockKind.open => (
          left.inSeconds < 60 ? 'Open for <1 min' : 'Open for ${(left.inSeconds / 60).ceil()} min',
          cs.primary,
          cs.onPrimary,
        ),
      AppBlockKind.locked => (
          'Locked · ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
          cs.errorContainer,
          cs.onErrorContainer,
        ),
      AppBlockKind.calendar => (
          'Blocked until ${DateFormat.jm().format(state.until!)}',
          cs.secondaryContainer,
          cs.onSecondaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}
