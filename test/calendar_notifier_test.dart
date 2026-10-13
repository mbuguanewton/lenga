import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/data/calendar_provider.dart';
import 'package:lenga_app/data/providers.dart';
import 'package:lenga_app/models/calendar_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('connected without a client ID: explains it and keeps cached events and toggles', () async {
    final event = CalendarEvent(
      id: 'e1',
      title: 'Standup',
      start: DateTime.now().add(const Duration(hours: 1)),
      end: DateTime.now().add(const Duration(hours: 2)),
    );
    SharedPreferences.setMockInitialValues({
      'calendar_connected': true,
      'calendar_events': '[${_json(event)}]',
      'calendar_blocked_ids': ['e1'],
    });
    final container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(await SharedPreferences.getInstance())],
    );
    addTearDown(container.dispose);

    await container.read(calendarProvider.notifier).refresh(force: true);

    final s = container.read(calendarProvider);
    expect(s.error, contains('client ID'));
    expect(s.connected, isTrue);
    expect(s.events.single.id, 'e1');
    expect(s.blockedIds, {'e1'});
    expect(s.loading, isFalse);
  });
}

String _json(CalendarEvent e) =>
    '{"id":"${e.id}","title":"${e.title}","start":${e.start.millisecondsSinceEpoch},"end":${e.end.millisecondsSinceEpoch}}';
