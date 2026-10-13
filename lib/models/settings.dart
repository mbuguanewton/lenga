import 'problem.dart';

class LengaSettings {
  const LengaSettings({this.difficulty = Difficulty.medium, this.lockoutMinutes = 15});

  final Difficulty difficulty;
  final int lockoutMinutes;

  static const lockoutOptions = [5, 15, 30];

  LengaSettings copyWith({Difficulty? difficulty, int? lockoutMinutes}) => LengaSettings(
        difficulty: difficulty ?? this.difficulty,
        lockoutMinutes: lockoutMinutes ?? this.lockoutMinutes,
      );

  Map<String, Object?> toJson() =>
      {'difficulty': difficulty.name, 'lockoutMinutes': lockoutMinutes};

  factory LengaSettings.fromJson(Map<String, Object?> j) => LengaSettings(
        difficulty: Difficulty.parse(j['difficulty'] as String?),
        lockoutMinutes: (j['lockoutMinutes'] as num?)?.toInt() ?? 15,
      );
}
