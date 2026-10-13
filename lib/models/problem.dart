enum Difficulty {
  easy,
  medium,
  hard,
  adaptive;

  String get label => name[0].toUpperCase() + name.substring(1);

  static Difficulty parse(String? s) =>
      Difficulty.values.firstWhere((d) => d.name == s, orElse: () => Difficulty.medium);
}

class Problem {
  const Problem(this.text, this.answer);

  final String text;
  final int answer;

  Map<String, Object?> toJson() => {'text': text, 'answer': answer};

  factory Problem.fromJson(Map<String, Object?> j) =>
      Problem(j['text']! as String, (j['answer']! as num).toInt());

  @override
  bool operator ==(Object other) =>
      other is Problem && other.text == text && other.answer == answer;

  @override
  int get hashCode => Object.hash(text, answer);
}
