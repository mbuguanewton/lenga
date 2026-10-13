import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../logic/stats_summary.dart';
import '../../models/stats_event.dart';
import '../shell.dart';
import '../widgets.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s = ref.watch(statsProvider).value ?? StatsSummary.empty;
    final maxMinutes = s.weekMinutes.fold(0, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, kFloatingNavClearance),
      children: [
        const ScreenTitle('Stats', "A record of time you didn't lose to social apps."),
        LengaCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('This week'),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: maxMinutes == 0 ? 4 : 4 + 80 * s.weekMinutes[i] / maxMinutes,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: i == s.todayIndex ? cs.primary : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_days[i], style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Top blocked apps', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        if (s.topApps.isEmpty)
          LengaCard(
            padding: const EdgeInsets.all(24),
            child: Text('Nothing yet. Opening a blocked app will show up here.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          )
        else
          LengaCard(
            child: Column(
              children: [
                for (final a in s.topApps)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        AppAvatar(a.name.isEmpty ? '?' : a.name[0].toUpperCase()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('${a.percent}% of blocked time',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text(formatMinutes(a.minutes),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.primary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _Tile('Challenges won', '${s.challengesWon}', cs.secondaryContainer, cs.onSecondaryContainer)),
            const SizedBox(width: 12),
            Expanded(
              child: _Tile('Streak', '${s.streakDays} ${s.streakDays == 1 ? 'day' : 'days'}',
                  cs.tertiaryContainer, cs.onTertiaryContainer),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Saved time is an estimate: the lockout length when you run out of attempts, '
          '$kDismissCreditMinutes minutes when you leave a challenge or a calendar block stops you.',
          style: TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.bg, this.fg);

  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.75))),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}
