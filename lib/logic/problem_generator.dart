import 'dart:math';

import '../models/problem.dart';

/// Local, instant problem generator. Port of `genProblem` in `Lenga.dc.html`.
class ProblemGenerator {
  ProblemGenerator([Random? random]) : _random = random ?? Random();

  final Random _random;

  int _r(int a, int b) => a + _random.nextInt(b - a + 1);

  Problem generate(Difficulty difficulty) {
    final tier = difficulty == Difficulty.adaptive
        ? const [Difficulty.easy, Difficulty.medium, Difficulty.hard][_r(0, 2)]
        : difficulty;
    switch (tier) {
      case Difficulty.easy:
        final a = _r(2, 12), b = _r(2, 12);
        return Problem('$a + $b = ?', a + b);
      case Difficulty.hard:
        final a = _r(2, 9), x = _r(2, 15), c = _r(1, 30);
        return Problem('Solve for x: ${a}x + $c = ${a * x + c}', x);
      case Difficulty.medium:
      case Difficulty.adaptive:
        final a = _r(3, 12), b = _r(3, 12);
        return Problem('$a × $b = ?', a * b);
    }
  }
}
