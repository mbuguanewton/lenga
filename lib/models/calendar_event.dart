import 'package:intl/intl.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;

  /// "10:00 – 11:00 AM" style label from the mockup.
  String get timeLabel {
    final f = DateFormat.jm();
    return '${f.format(start)} – ${f.format(end)}';
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      };

  factory CalendarEvent.fromJson(Map<String, Object?> j) => CalendarEvent(
        id: j['id']! as String,
        title: j['title']! as String,
        start: DateTime.fromMillisecondsSinceEpoch((j['start']! as num).toInt()),
        end: DateTime.fromMillisecondsSinceEpoch((j['end']! as num).toInt()),
      );
}
