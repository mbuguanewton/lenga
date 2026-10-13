import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/logic/challenge_controller.dart';
import 'package:lenga_app/logic/problem_source.dart';
import 'package:lenga_app/models/problem.dart';
import 'package:lenga_app/models/stats_event.dart';
import 'package:lenga_app/services/platform_bridge.dart';

class _Counting implements ProblemSource {
  int calls = 0;
  @override
  Future<Problem> next(Difficulty difficulty) async {
    calls++;
    return Problem('$calls + 0 = ?', calls);
  }
}

void main() {
  late MemoryPlatformBridge store;
  late _Counting source;
  late DateTime clock;

  ChallengeController make() => ChallengeController(
        packageName: 'com.example.app',
        appName: 'Example',
        difficulty: Difficulty.easy,
        lockoutMinutes: 15,
        source: source,
        store: store,
        now: () => clock,
      );

  setUp(() {
    store = MemoryPlatformBridge();
    source = _Counting();
    clock = DateTime(2026, 1, 5, 12);
  });

  test('correct answer completes, unlocks for 15 minutes and records a win', () async {
    final c = make();
    await c.start();
    expect(c.phase, ChallengePhase.asking);
    await c.submit('1');
    expect(c.phase, ChallengePhase.done);
    expect(store.unlocked['com.example.app'], clock.add(const Duration(minutes: 15)));
    expect(store.events.single.kind, StatKind.won);
    c.dispose();
  });

  test('wrong answer costs an attempt and serves a new problem', () async {
    final c = make();
    await c.start();
    await c.submit('99');
    expect(c.attemptsLeft, 2);
    expect(c.wrongFeedback, isTrue);
    expect(c.problem!.answer, 2);
    c.dispose();
  });

  test('empty input is ignored', () async {
    final c = make();
    await c.start();
    await c.submit('  ');
    expect(c.attempts, 0);
    c.dispose();
  });

  test('three wrong answers start a persisted lockout and record it', () async {
    final c = make();
    await c.start();
    for (var i = 0; i < 3; i++) {
      await c.submit('-1');
    }
    expect(c.phase, ChallengePhase.locked);
    expect(c.lockSecondsLeft, 15 * 60);
    expect(store.locked, clock.add(const Duration(minutes: 15)));
    expect(store.events.single.kind, StatKind.lockout);
    expect(store.events.single.savedMinutes, 15);
    c.dispose();
  });

  test('lockout survives a restart and ends when the timestamp passes', () async {
    final first = make();
    await first.start();
    for (var i = 0; i < 3; i++) {
      await first.submit('-1');
    }
    first.dispose();

    clock = clock.add(const Duration(minutes: 5));
    final second = make();
    await second.start();
    expect(second.phase, ChallengePhase.locked);
    expect(second.lockSecondsLeft, 10 * 60);

    clock = clock.add(const Duration(minutes: 10));
    await second.tick();
    expect(second.phase, ChallengePhase.asking);
    expect(second.attempts, 0);
    expect(store.locked, isNull);
    second.dispose();
  });

  test('submitting is ignored while locked', () async {
    final c = make();
    await c.start();
    for (var i = 0; i < 3; i++) {
      await c.submit('-1');
    }
    await c.submit('1');
    expect(c.phase, ChallengePhase.locked);
    expect(store.unlocked, isEmpty);
    c.dispose();
  });

  test('dismissing an unsolved challenge credits estimated saved time', () async {
    final c = make();
    await c.start();
    await c.dismiss();
    expect(store.events.single.kind, StatKind.dismissed);
    expect(store.events.single.savedMinutes, kDismissCreditMinutes);
    c.dispose();
  });
}
