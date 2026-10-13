import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/calendar_provider.dart';
import '../../models/calendar_event.dart';
import '../shell.dart';
import '../widgets.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final cal = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, kFloatingNavClearance),
        children: [
          const ScreenTitle('Calendar', 'Block social apps automatically during events.'),
          if (cal.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(16)),
              child: Text(cal.error!, style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
            ),
          if (!cal.connected)
            LengaCard(
              radius: 28,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.calendar_today, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(height: 14),
                  const Text('Connect Google Calendar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Text(
                    'Link Google Calendar and Lenga will block the apps you choose for the length of any event you mark.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: cal.loading ? null : notifier.connect,
                    style: FilledButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: const StadiumBorder()),
                    child: const Text('Connect Google Calendar'),
                  ),
                  if (kDebugMode)
                    TextButton(onPressed: notifier.useSamples, child: const Text('Use sample events (debug)')),
                ],
              ),
            )
          else ...[
            if (cal.usingSamples)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Showing sample events (debug build).',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            if (cal.loading && cal.events.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (cal.events.isEmpty)
              LengaCard(
                padding: const EdgeInsets.all(24),
                child: Text('No upcoming events in the next week.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              )
            else
              LengaCard(
                child: Column(
                  children: [
                    for (final e in cal.events)
                      _EventRow(
                        event: e,
                        blocked: cal.blockedIds.contains(e.id),
                        onToggle: () => notifier.toggle(e.id),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Toggle blocking per event — off by default, so nothing is blocked unless you choose it.',
              style: TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant),
            ),
            TextButton(onPressed: notifier.disconnect, child: const Text('Disconnect calendar')),
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.blocked, required this.onToggle});

  final CalendarEvent event;
  final bool blocked;
  final VoidCallback onToggle;

  String get _when {
    final now = DateTime.now();
    final sameDay =
        event.start.year == now.year && event.start.month == now.month && event.start.day == now.day;
    return sameDay ? event.timeLabel : '${DateFormat.E().format(event.start)}, ${event.timeLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(_when, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          PillButton(blocked ? 'Blocking on' : 'Blocking off', onPressed: onToggle, filled: blocked),
        ],
      ),
    );
  }
}
