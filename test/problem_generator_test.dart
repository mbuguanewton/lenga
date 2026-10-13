import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/logic/problem_generator.dart';
import 'package:lenga_app/logic/problem_validator.dart';
import 'package:lenga_app/models/problem.dart';

void main() {
  final gen = ProblemGenerator(Random(42));

  test('every generated problem validates against its own text', () {
    for (final d in Difficulty.values) {
      for (var i = 0; i < 300; i++) {
        final p = gen.generate(d);
        expect(ProblemValidator.solve(p.text), p.answer, reason: '${d.name}: ${p.text}');
      }
    }
  });

  test('easy is addition, medium is multiplication, hard is a linear equation', () {
    for (var i = 0; i < 50; i++) {
      expect(gen.generate(Difficulty.easy).text, contains('+'));
      expect(gen.generate(Difficulty.medium).text, contains('×'));
      expect(gen.generate(Difficulty.hard).text, startsWith('Solve for x:'));
    }
  });

  test('hard answers stay in range', () {
    for (var i = 0; i < 200; i++) {
      final a = gen.generate(Difficulty.hard).answer;
      expect(a, inInclusiveRange(2, 15));
    }
  });

  test('adaptive mixes all three problem types', () {
    final kinds = <String>{};
    for (var i = 0; i < 200; i++) {
      final t = gen.generate(Difficulty.adaptive).text;
      kinds.add(t.contains('Solve') ? 'hard' : t.contains('×') ? 'medium' : 'easy');
    }
    expect(kinds, {'easy', 'medium', 'hard'});
  });

  group('ProblemValidator', () {
    test('accepts correct arithmetic and equations', () {
      expect(ProblemValidator.validate({'text': '7 × 8 = ?', 'answer': 56}), const Problem('7 × 8 = ?', 56));
      expect(ProblemValidator.validate({'text': '(3 + 4) × 5 - 6 = ?', 'answer': 29}), isNotNull);
      expect(ProblemValidator.validate({'text': '48 ÷ 6 = ?', 'answer': 8}), isNotNull);
      expect(ProblemValidator.validate({'text': 'Solve for x: 4x + 7 = 31', 'answer': 6}), isNotNull);
      expect(ProblemValidator.validate({'text': 'Solve for x: 2(x + 3) = 20', 'answer': 7}), isNotNull);
      expect(ProblemValidator.validate({'text': 'Solve for x: 5x = 2x + 12', 'answer': 4}), isNotNull);
    });

    test('rejects wrong answers', () {
      expect(ProblemValidator.validate({'text': '7 × 8 = ?', 'answer': 54}), isNull);
      expect(ProblemValidator.validate({'text': 'Solve for x: 4x + 7 = 31', 'answer': 7}), isNull);
    });

    test('rejects non-integer results, division by zero and non-linear text', () {
      expect(ProblemValidator.validate({'text': '7 ÷ 2 = ?', 'answer': 3}), isNull);
      expect(ProblemValidator.validate({'text': '7 ÷ 0 = ?', 'answer': 0}), isNull);
      expect(ProblemValidator.validate({'text': 'Solve for x: x × x = 49', 'answer': 7}), isNull);
      expect(ProblemValidator.validate({'text': 'Solve for x: 2x = 2x + 1', 'answer': 0}), isNull);
    });

    test('rejects malformed input', () {
      expect(ProblemValidator.validate(null), isNull);
      expect(ProblemValidator.validate({'text': 'What is the capital of France?', 'answer': 1}), isNull);
      expect(ProblemValidator.validate({'text': '7 × 8 = ?', 'answer': '56'}), isNull);
      expect(ProblemValidator.validate({'text': '7 × 8 = ?', 'answer': 56.5}), isNull);
      expect(ProblemValidator.validate({'text': '1 + 1 = ?', 'answer': 999999999}), isNull);
      expect(ProblemValidator.validate({'text': '1+' * 60 + '1 = ?', 'answer': 61}), isNull);
      expect(ProblemValidator.validate({'text': '', 'answer': 0}), isNull);
    });
  });
}
