import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/logic/today_events.dart';
import 'package:lenga_app/models/calendar_event.dart';

CalendarEvent ev(String id, DateTime start, DateTime end) =>
    CalendarEvent(id: id, title: id, start: start, end: end);

void main() {
  final now = DateTime(2026, 1, 5, 12);

  test('keeps current and upcoming events for today, in start order', () {
    final r = todaysEvents([
      ev('later', DateTime(2026, 1, 5, 16), DateTime(2026, 1, 5, 17)),
      ev('now', DateTime(2026, 1, 5, 11, 30), DateTime(2026, 1, 5, 12, 30)),
      ev('soon', DateTime(2026, 1, 5, 14), DateTime(2026, 1, 5, 15)),
    ], now);
    expect(r.map((e) => e.id), ['now', 'soon', 'later']);
  });

  test('drops events that already ended and ones starting tomorrow', () {
    final r = todaysEvents([
      ev('done', DateTime(2026, 1, 5, 9), DateTime(2026, 1, 5, 10)),
      ev('endsNow', DateTime(2026, 1, 5, 11), now),
      ev('tomorrow', DateTime(2026, 1, 6, 9), DateTime(2026, 1, 6, 10)),
    ], now);
    expect(r, isEmpty);
  });

  test('keeps an event that started yesterday and is still running', () {
    final r = todaysEvents([ev('overnight', DateTime(2026, 1, 4, 23), DateTime(2026, 1, 5, 13))], now);
    expect(r.single.id, 'overnight');
  });

  test('isHappeningNow is inclusive of start and exclusive of end', () {
    expect(isHappeningNow(ev('a', now, now.add(const Duration(hours: 1))), now), isTrue);
    expect(isHappeningNow(ev('b', now.subtract(const Duration(hours: 1)), now), now), isFalse);
    expect(isHappeningNow(ev('c', now.add(const Duration(minutes: 1)), now.add(const Duration(hours: 1))), now), isFalse);
  });
}
