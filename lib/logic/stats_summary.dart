import '../models/stats_event.dart';

class AppStat {
  const AppStat(this.packageName, this.name, this.minutes, this.percent);
  final String packageName;
  final String name;
  final int minutes;

  /// Share of this week's saved time, 0-100.
  final int percent;
}

/// Everything the Stats and Home screens show, computed from real events.
class StatsSummary {
  const StatsSummary({
    required this.savedTodayMinutes,
    required this.savedTodayByApp,
    required this.weekMinutes,
    required this.todayIndex,
    required this.topApps,
    required this.challengesWon,
    required this.streakDays,
  });

  final int savedTodayMinutes;
  final Map<String, int> savedTodayByApp;

  /// Saved minutes for Mon..Sun of the current week.
  final List<int> weekMinutes;
  final int todayIndex;
  final List<AppStat> topApps;
  final int challengesWon;
  final int streakDays;

  static const empty = StatsSummary(
    savedTodayMinutes: 0,
    savedTodayByApp: {},
    weekMinutes: [0, 0, 0, 0, 0, 0, 0],
    todayIndex: 0,
    topApps: [],
    challengesWon: 0,
    streakDays: 0,
  );

  /// "Saved" time is [StatsEvent.savedMinutes] (an estimate: the lockout length
  /// for a lockout, [kDismissCreditMinutes] for an abandoned challenge or
  /// calendar block). A streak is consecutive days, ending today or yesterday,
  /// on which at least one blocked app was intercepted.
  factory StatsSummary.compute(List<StatsEvent> events, DateTime now) {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = day(now);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = List<int>.filled(7, 0);
    final todayByApp = <String, int>{};
    final weekByApp = <String, int>{};
    final names = <String, String>{};
    final activeDays = <DateTime>{};
    var saved = 0;
    var won = 0;

    for (final e in events) {
      final d = day(e.time);
      activeDays.add(d);
      if (e.kind == StatKind.won) won++;
      names[e.packageName] = e.appName;
      final offset = d.difference(monday).inDays;
      if (offset >= 0 && offset < 7) {
        week[offset] += e.savedMinutes;
        weekByApp[e.packageName] = (weekByApp[e.packageName] ?? 0) + e.savedMinutes;
      }
      if (d == today) {
        saved += e.savedMinutes;
        todayByApp[e.packageName] = (todayByApp[e.packageName] ?? 0) + e.savedMinutes;
      }
    }

    final weekTotal = weekByApp.values.fold(0, (a, b) => a + b);
    final top = weekByApp.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topApps = [
      for (final e in top.take(3))
        AppStat(e.key, names[e.key] ?? e.key, e.value, (e.value * 100 / weekTotal).round()),
    ];

    var streak = 0;
    var cursor = activeDays.contains(today) ? today : today.subtract(const Duration(days: 1));
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    return StatsSummary(
      savedTodayMinutes: saved,
      savedTodayByApp: todayByApp,
      weekMinutes: week,
      todayIndex: today.weekday - 1,
      topApps: topApps,
      challengesWon: won,
      streakDays: streak,
    );
  }
}

String formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
