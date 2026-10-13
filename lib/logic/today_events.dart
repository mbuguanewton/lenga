import '../models/calendar_event.dart';

/// Events that matter for "today" on Home: happening now, or still to come
/// before midnight. Ended events are dropped. Sorted by start time.
List<CalendarEvent> todaysEvents(List<CalendarEvent> events, DateTime now) {
  final midnight = DateTime(now.year, now.month, now.day + 1);
  return [
    for (final e in events)
      if (e.start.isBefore(midnight) && e.end.isAfter(now)) e,
  ]..sort((a, b) => a.start.compareTo(b.start));
}

bool isHappeningNow(CalendarEvent e, DateTime now) => !e.start.isAfter(now) && e.end.isAfter(now);
