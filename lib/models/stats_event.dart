/// What happened when a blocked app was opened.
enum StatKind {
  /// Problem solved; the app was unlocked.
  won,

  /// Ran out of attempts; a lockout started.
  lockout,

  /// Left the challenge without solving it.
  dismissed,

  /// Blocked because a calendar event was active.
  calendar;

  static StatKind parse(String? s) =>
      StatKind.values.firstWhere((k) => k.name == s, orElse: () => StatKind.dismissed);
}

/// Estimated minutes credited to "saved" for a challenge that was left unsolved.
/// A lockout credits the full lockout length instead.
const kDismissCreditMinutes = 5;

class StatsEvent {
  const StatsEvent({
    required this.time,
    required this.packageName,
    required this.appName,
    required this.kind,
    this.savedMinutes = 0,
  });

  final DateTime time;
  final String packageName;
  final String appName;
  final StatKind kind;
  final int savedMinutes;

  Map<String, Object?> toJson() => {
        'ts': time.millisecondsSinceEpoch,
        'package': packageName,
        'app': appName,
        'kind': kind.name,
        'minutes': savedMinutes,
      };

  factory StatsEvent.fromJson(Map<String, Object?> j) => StatsEvent(
        time: DateTime.fromMillisecondsSinceEpoch((j['ts']! as num).toInt()),
        packageName: j['package']! as String,
        appName: (j['app'] as String?) ?? '',
        kind: StatKind.parse(j['kind'] as String?),
        savedMinutes: (j['minutes'] as num?)?.toInt() ?? 0,
      );
}
