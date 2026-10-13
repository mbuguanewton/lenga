import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/problem.dart';
import '../models/stats_event.dart';
import 'problem_source.dart';

/// Persistence the challenge needs. Backed by native storage so the in-app
/// challenge and the blocking overlay agree on lockouts and unlock windows.
abstract class ChallengeStore {
  Future<DateTime?> lockedUntil();
  Future<void> setLockedUntil(DateTime? until);
  Future<void> setUnlockedUntil(String packageName, DateTime until);
  Future<void> recordEvent(StatsEvent event);
}

enum ChallengePhase { loading, asking, locked, done }

/// State machine for one challenge: 3 attempts -> lockout -> (timer) -> retry,
/// or correct answer -> done. Port of `submitAnswer` / `startLockTimer`.
class ChallengeController extends ChangeNotifier {
  ChallengeController({
    required this.packageName,
    required this.appName,
    required this.difficulty,
    required this.lockoutMinutes,
    required this.source,
    required this.store,
    DateTime Function()? now,
    this.maxAttempts = 3,
    this.unlockMinutes = 15,
  }) : _now = now ?? DateTime.now;

  final String packageName;
  final String appName;
  final Difficulty difficulty;
  final int lockoutMinutes;
  final int maxAttempts;
  final int unlockMinutes;

  final ProblemSource source;
  final ChallengeStore store;
  final DateTime Function() _now;

  ChallengePhase phase = ChallengePhase.loading;
  Problem? problem;
  int attempts = 0;
  bool wrongFeedback = false;
  int lockSecondsLeft = 0;

  DateTime? _lockedUntil;
  Timer? _timer;
  bool _disposed = false;

  int get attemptsLeft => maxAttempts - attempts;

  /// Loads the first problem, or resumes a lockout that is still running
  /// (the end timestamp is persisted, so it survives app restarts).
  Future<void> start() async {
    final locked = await store.lockedUntil();
    if (locked != null && locked.isAfter(_now())) {
      _enterLock(locked);
      return;
    }
    await _newProblem();
  }

  Future<void> submit(String input) async {
    if (phase != ChallengePhase.asking || problem == null) return;
    final text = input.trim();
    if (text.isEmpty) return;
    if (int.tryParse(text) == problem!.answer) {
      phase = ChallengePhase.done;
      wrongFeedback = false;
      notifyListeners();
      await store.setUnlockedUntil(packageName, _now().add(Duration(minutes: unlockMinutes)));
      await _record(StatKind.won, 0);
      return;
    }
    attempts++;
    if (attempts >= maxAttempts) {
      final until = _now().add(Duration(minutes: lockoutMinutes));
      _enterLock(until);
      await store.setLockedUntil(until);
      await _record(StatKind.lockout, lockoutMinutes);
    } else {
      wrongFeedback = true;
      await _newProblem(keepFeedback: true);
    }
  }

  /// The user left without solving it.
  Future<void> dismiss() async {
    if (phase == ChallengePhase.asking) {
      await _record(StatKind.dismissed, kDismissCreditMinutes);
    }
  }

  /// Recomputes the countdown; called every second while locked.
  @visibleForTesting
  Future<void> tick() async {
    final until = _lockedUntil;
    if (phase != ChallengePhase.locked || until == null) return;
    final leftMs = until.difference(_now()).inMilliseconds;
    if (leftMs > 0) {
      lockSecondsLeft = (leftMs / 1000).ceil();
      notifyListeners();
      return;
    }
    _timer?.cancel();
    _lockedUntil = null;
    lockSecondsLeft = 0;
    attempts = 0;
    wrongFeedback = false;
    await store.setLockedUntil(null);
    await _newProblem();
  }

  void _enterLock(DateTime until) {
    _lockedUntil = until;
    phase = ChallengePhase.locked;
    lockSecondsLeft = (until.difference(_now()).inMilliseconds / 1000).ceil();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  Future<void> _newProblem({bool keepFeedback = false}) async {
    final p = await source.next(difficulty);
    if (_disposed) return;
    problem = p;
    phase = ChallengePhase.asking;
    if (!keepFeedback) wrongFeedback = false;
    notifyListeners();
  }

  Future<void> _record(StatKind kind, int minutes) => store.recordEvent(StatsEvent(
        time: _now(),
        packageName: packageName,
        appName: appName,
        kind: kind,
        savedMinutes: minutes,
      ));

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
