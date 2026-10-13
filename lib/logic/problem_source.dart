import 'dart:convert';

import '../models/problem.dart';
import 'problem_generator.dart';
import 'problem_validator.dart';

/// Where the challenge gets its next problem from.
abstract class ProblemSource {
  Future<Problem> next(Difficulty difficulty);
}

/// Always available and instant.
class LocalGenerator implements ProblemSource {
  LocalGenerator([ProblemGenerator? generator]) : _generator = generator ?? ProblemGenerator();

  final ProblemGenerator _generator;

  @override
  Future<Problem> next(Difficulty difficulty) async => _generator.generate(difficulty);
}

/// Persistent queue of validated problems, stored natively so the challenge
/// overlay (a separate Flutter engine) and the main app share it.
abstract class ProblemQueue {
  Future<Problem?> pop(Difficulty difficulty);
  Future<int> size(Difficulty difficulty);
  Future<void> push(Difficulty difficulty, List<Problem> problems);
}

/// Pops from the AI-filled queue and falls back to [LocalGenerator] when it is
/// empty. Never waits on the model.
class QueuedProblemSource implements ProblemSource {
  QueuedProblemSource(this._queue, this._fallback);

  final ProblemQueue _queue;
  final ProblemSource _fallback;

  @override
  Future<Problem> next(Difficulty difficulty) async {
    try {
      final p = await _queue.pop(difficulty);
      if (p != null) return p;
    } catch (_) {
      // Storage trouble must never block the challenge.
    }
    return _fallback.next(difficulty);
  }
}

enum AiAvailability { available, downloading, unavailable }

/// Text generation backend (ML Kit GenAI on Android).
abstract class AiBackend {
  Future<AiAvailability> availability();
  Future<String> generate(String prompt);
}

/// Fills the [ProblemQueue] from the on-device model.
class OnDeviceAiGenerator {
  OnDeviceAiGenerator(this._backend, this._queue);

  final AiBackend _backend;
  final ProblemQueue _queue;

  static const batchSize = 10;
  static const targetQueueSize = 10;

  Future<AiAvailability> status() async {
    try {
      return await _backend.availability();
    } catch (_) {
      return AiAvailability.unavailable;
    }
  }

  /// Requests a batch if the queue is running low. Returns the number of
  /// validated problems added (0 if unavailable, full, or the model failed).
  Future<int> refill(Difficulty difficulty) async {
    try {
      if (await status() != AiAvailability.available) return 0;
      if (await _queue.size(difficulty) >= targetQueueSize) return 0;
      final raw = await _backend.generate(buildPrompt(difficulty, batchSize));
      final problems = parseBatch(raw);
      if (problems.isEmpty) return 0;
      await _queue.push(difficulty, problems);
      return problems.length;
    } catch (_) {
      return 0;
    }
  }

  static String buildPrompt(Difficulty difficulty, int count) {
    final spec = switch (difficulty) {
      Difficulty.easy => 'adding two whole numbers between 2 and 20',
      Difficulty.medium =>
        'multiplying two whole numbers between 3 and 15, or a two-step sum/difference such as 7 × 6 - 9',
      Difficulty.hard =>
        'one-variable linear equations with a whole-number solution, written like "Solve for x: 4x + 7 = 31"',
      Difficulty.adaptive =>
        'a varied mix: simple sums, products, two-step arithmetic, and linear equations like "Solve for x: 4x + 7 = 31"',
    };
    return 'Generate $count different mental-math problems: $spec. '
        'Every answer must be a whole number. Use only digits, + - × ÷ ( ) and the variable x. '
        'Write arithmetic as "7 × 8 = ?". '
        'Reply with ONLY a JSON array, no prose, in this shape: '
        '[{"text": "7 × 8 = ?", "answer": 56}]';
  }

  /// Extracts the JSON array from [raw] and keeps only problems that
  /// [ProblemValidator] confirms are correct (duplicates dropped).
  static List<Problem> parseBatch(String raw) {
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(raw.substring(start, end + 1));
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final seen = <Problem>{};
    for (final item in decoded) {
      final p = ProblemValidator.validate(item);
      if (p != null) seen.add(p);
    }
    return seen.toList();
  }
}
