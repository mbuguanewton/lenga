import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/logic/block_status.dart';

void main() {
  final now = DateTime(2026, 1, 5, 12);
  DateTime mins(int m) => now.add(Duration(minutes: m));

  test('a plain blocked app', () {
    expect(BlockStatus.empty.stateFor('a', now).kind, AppBlockKind.blocked);
  });

  test('an unlock window opens only that app', () {
    final s = BlockStatus(unlockedUntil: {'a': mins(10)});
    expect(s.stateFor('a', now).kind, AppBlockKind.open);
    expect(s.stateFor('a', now).until, mins(10));
    expect(s.stateFor('b', now).kind, AppBlockKind.blocked);
  });

  test('expired windows no longer count', () {
    final s = BlockStatus(
      unlockedUntil: {'a': mins(-1)},
      lockedUntil: mins(-1),
      calendarEnd: mins(-1),
    );
    expect(s.stateFor('a', now).kind, AppBlockKind.blocked);
  });

  test('a lockout is shared and beats an unlock window', () {
    final s = BlockStatus(lockedUntil: mins(9), unlockedUntil: {'a': mins(10)});
    expect(s.stateFor('a', now).kind, AppBlockKind.locked);
    expect(s.stateFor('b', now).kind, AppBlockKind.locked);
  });

  test('an active calendar event beats everything', () {
    final s = BlockStatus(calendarEnd: mins(30), lockedUntil: mins(9), unlockedUntil: {'a': mins(10)});
    expect(s.stateFor('a', now).kind, AppBlockKind.calendar);
    expect(s.stateFor('a', now).until, mins(30));
  });

  test('parses the native map, ignoring zero timestamps', () {
    final s = BlockStatus.fromMap({
      'lockedUntil': 0,
      'calendarTitle': null,
      'calendarEnd': null,
      'unlocked': {'a': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch, 'b': 0},
    });
    expect(s.lockedUntil, isNull);
    expect(s.unlockedUntil.keys, ['a']);
  });
}
