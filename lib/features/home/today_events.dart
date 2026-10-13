import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/calendar_provider.dart';
import '../../logic/today_events.dart';
import '../../models/calendar_event.dart';
import '../shell.dart';
import '../widgets.dart';

/// Current and upcoming events for today, with a per-event blocking toggle.
class TodayEvents extends ConsumerStatefulWidget {
  const TodayEvents({super.key});

  @override
  ConsumerState<TodayEvents> createState() => _TodayEventsState();
}

class _TodayEventsState extends ConsumerState<TodayEvents> {
  static const _maxRows = 5;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Events start and end while Home is open; keep "now" and the list current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
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
    final cal = ref.watch(calendarProvider);
    final now = DateTime.now();
    final events = todaysEvents(cal.events, now);
    final shown = events.take(_maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Today', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            TextButton(
              onPressed: () => ref.read(selectedTabProvider.notifier).select(AppTab.calendar),
              child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (shown.isEmpty)
          LengaCard(
            padding: const EdgeInsets.all(24),
            child: Text(
              cal.loading && cal.events.isEmpty ? 'Loading your events…' : 'Nothing else on today.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          )
        else
          LengaCard(
            child: Column(
              children: [
                for (final e in shown)
                  _EventRow(
                    event: e,
                    now: now,
                    blocked: cal.blockedIds.contains(e.id),
                    onToggle: () => ref.read(calendarProvider.notifier).toggle(e.id),
                  ),
              ],
            ),
          ),
        if (events.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text('and ${events.length - shown.length} more today',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.now,
    required this.blocked,
    required this.onToggle,
  });

  final CalendarEvent event;
  final DateTime now;
  final bool blocked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final live = isHappeningNow(event, now);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    if (live)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration:
                            BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(999)),
                        child: Text('NOW',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: cs.onPrimaryContainer)),
                      ),
                  ],
                ),
                Text(event.timeLabel, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          PillButton(blocked ? 'Blocking on' : 'Blocking off', onPressed: onToggle, filled: blocked),
        ],
      ),
    );
  }
}
