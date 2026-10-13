import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/logic/stats_summary.dart';
import 'package:lenga_app/models/stats_event.dart';

StatsEvent ev(DateTime t, String pkg, StatKind k, int min) =>
    StatsEvent(time: t, packageName: pkg, appName: pkg.toUpperCase(), kind: k, savedMinutes: min);

void main() {
  // Thursday 8 Jan 2026.
  final now = DateTime(2026, 1, 8, 15);

  test('empty events give zeros', () {
    final s = StatsSummary.compute(const [], now);
    expect(s.savedTodayMinutes, 0);
    expect(s.streakDays, 0);
    expect(s.topApps, isEmpty);
    expect(s.todayIndex, 3);
  });

  test('sums today, week bars, top apps, wins and streak', () {
    final s = StatsSummary.compute([
      ev(DateTime(2026, 1, 8, 9), 'a', StatKind.lockout, 15),
      ev(DateTime(2026, 1, 8, 10), 'a', StatKind.dismissed, 5),
      ev(DateTime(2026, 1, 8, 11), 'b', StatKind.won, 0),
      ev(DateTime(2026, 1, 7, 9), 'b', StatKind.lockout, 30),
      ev(DateTime(2026, 1, 6, 9), 'a', StatKind.dismissed, 5),
      ev(DateTime(2026, 1, 3, 9), 'a', StatKind.lockout, 15), // previous week
    ], now);
    expect(s.savedTodayMinutes, 20);
    expect(s.savedTodayByApp, {'a': 20, 'b': 0});
    expect(s.weekMinutes[1], 5); // Tue 6th
    expect(s.weekMinutes[2], 30); // Wed 7th
    expect(s.weekMinutes[3], 20); // Thu 8th
    expect(s.challengesWon, 1);
    expect(s.streakDays, 3);
    expect(s.topApps.first.name, 'B');
    expect(s.topApps.first.percent, 55);
    expect(s.topApps.map((a) => a.minutes), [30, 25]);
  });

  test('streak counts from yesterday if nothing happened yet today', () {
    final s = StatsSummary.compute([
      ev(DateTime(2026, 1, 7, 9), 'a', StatKind.dismissed, 5),
      ev(DateTime(2026, 1, 6, 9), 'a', StatKind.dismissed, 5),
    ], now);
    expect(s.streakDays, 2);
  });

  test('a gap resets the streak', () {
    final s = StatsSummary.compute([
      ev(DateTime(2026, 1, 8, 9), 'a', StatKind.dismissed, 5),
      ev(DateTime(2026, 1, 5, 9), 'a', StatKind.dismissed, 5),
    ], now);
    expect(s.streakDays, 1);
  });

  test('formatMinutes', () {
    expect(formatMinutes(0), '0m');
    expect(formatMinutes(48), '48m');
    expect(formatMinutes(60), '1h');
    expect(formatMinutes(134), '2h 14m');
  });
}
