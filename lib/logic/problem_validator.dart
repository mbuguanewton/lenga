import '../models/problem.dart';

/// Checks problems from an untrusted source (the on-device model) by
/// recomputing the answer from the problem text. Anything that doesn't parse,
/// isn't an integer answer or disagrees with the claimed answer is rejected.
class ProblemValidator {
  const ProblemValidator._();

  static const maxTextLength = 80;
  static const maxAnswer = 100000;

  /// Returns a [Problem] if [json] is a well-formed, correct problem, else null.
  static Problem? validate(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    final answer = json['answer'];
    if (text is! String || answer is! num) return null;
    if (answer != answer.truncate() || answer.abs() > maxAnswer) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxTextLength) return null;
    final computed = solve(trimmed);
    if (computed == null || computed != answer.toInt()) return null;
    return Problem(trimmed, computed);
  }

  /// Solves either an arithmetic problem ("7 × 8 = ?") or a one-variable
  /// linear equation ("Solve for x: 3x + 4 = 19"). Returns null if the text
  /// isn't one of those or the result isn't a whole number.
  static int? solve(String text) {
    var s = text.replaceAll(RegExp(r'^\s*solve( for)?\s*x\s*:?', caseSensitive: false), '');
    s = s.replaceAll('?', '').replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return null;
    try {
      final eq = s.split('=');
      if (eq.length == 2 && eq[0].isEmpty == false && eq[1].isEmpty) {
        // "7×8=" — arithmetic with trailing "= ?"
        return _asInt(_Parser(eq[0]).parseAll().constantOrNull);
      }
      if (eq.length == 2) {
        final l = _Parser(eq[0]).parseAll();
        final r = _Parser(eq[1]).parseAll();
        final a = l.a - r.a;
        final b = r.b - l.b;
        if (a == 0) {
          return null; // not an equation in x
        }
        return _asInt(b / a);
      }
      if (eq.length == 1) {
        return _asInt(_Parser(eq[0]).parseAll().constantOrNull);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static int? _asInt(double? v) {
    if (v == null || v.isNaN || v.isInfinite) return null;
    final rounded = v.roundToDouble();
    if ((v - rounded).abs() > 1e-9) return null;
    return rounded.toInt();
  }
}

/// a·x + b
class _Lin {
  const _Lin(this.a, this.b);
  final double a;
  final double b;
  double? get constantOrNull => a == 0 ? b : null;
}

/// Tiny recursive-descent parser over linear expressions in `x`.
class _Parser {
  _Parser(this._s);

  final String _s;
  int _i = 0;

  _Lin parseAll() {
    final v = _expr();
    if (_i != _s.length) throw const FormatException('trailing input');
    return v;
  }

  String? get _peek => _i < _s.length ? _s[_i] : null;

  _Lin _expr() {
    var v = _term();
    while (_peek == '+' || _peek == '-') {
      final op = _s[_i++];
      final t = _term();
      v = op == '+' ? _Lin(v.a + t.a, v.b + t.b) : _Lin(v.a - t.a, v.b - t.b);
    }
    return v;
  }

  _Lin _term() {
    var v = _factor();
    while (true) {
      final c = _peek;
      if (c == '×' || c == '*') {
        _i++;
        v = _mul(v, _factor());
      } else if (c == '÷' || c == '/') {
        _i++;
        final d = _factor();
        if (d.a != 0 || d.b == 0) throw const FormatException('bad divisor');
        v = _Lin(v.a / d.b, v.b / d.b);
      } else if (c != null && (c == '(' || c == 'x' || _isDigit(c))) {
        // implicit multiplication: "3x", "2(x+1)"
        v = _mul(v, _factor());
      } else {
        return v;
      }
    }
  }

  _Lin _factor() {
    final c = _peek;
    if (c == '-') {
      _i++;
      final f = _factor();
      return _Lin(-f.a, -f.b);
    }
    if (c == '+') {
      _i++;
      return _factor();
    }
    if (c == '(') {
      _i++;
      final v = _expr();
      if (_peek != ')') throw const FormatException('missing )');
      _i++;
      return v;
    }
    if (c == 'x') {
      _i++;
      return const _Lin(1, 0);
    }
    if (c != null && _isDigit(c)) {
      final start = _i;
      while (_peek != null && _isDigit(_peek!)) {
        _i++;
      }
      return _Lin(0, double.parse(_s.substring(start, _i)));
    }
    throw const FormatException('unexpected token');
  }

  _Lin _mul(_Lin p, _Lin q) {
    if (p.a != 0 && q.a != 0) throw const FormatException('non-linear');
    return _Lin(p.a * q.b + q.a * p.b, p.b * q.b);
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}
