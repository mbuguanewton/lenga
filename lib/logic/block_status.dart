/// What a blocked app's door looks like right now.
enum AppBlockKind { blocked, open, locked, calendar }

class AppBlockState {
  const AppBlockState(this.kind, [this.until]);

  final AppBlockKind kind;

  /// End of the window for [open], [locked] and [calendar].
  final DateTime? until;
}

/// Snapshot of native lockout / unlock / calendar state.
class BlockStatus {
  const BlockStatus({
    this.lockedUntil,
    this.calendarTitle,
    this.calendarEnd,
    this.unlockedUntil = const {},
  });

  /// One lockout, shared by every blocked app.
  final DateTime? lockedUntil;
  final String? calendarTitle;
  final DateTime? calendarEnd;
  final Map<String, DateTime> unlockedUntil;

  static const empty = BlockStatus();

  /// Same precedence as `BlockerService`: an active calendar event wins, then a
  /// lockout, then a per-app unlock window; otherwise the app is just blocked.
  AppBlockState stateFor(String packageName, DateTime now) {
    final cal = calendarEnd;
    if (cal != null && cal.isAfter(now)) return AppBlockState(AppBlockKind.calendar, cal);
    final lock = lockedUntil;
    if (lock != null && lock.isAfter(now)) return AppBlockState(AppBlockKind.locked, lock);
    final open = unlockedUntil[packageName];
    if (open != null && open.isAfter(now)) return AppBlockState(AppBlockKind.open, open);
    return const AppBlockState(AppBlockKind.blocked);
  }

  factory BlockStatus.fromMap(Map<Object?, Object?> m) {
    DateTime? ms(Object? v) => v is num && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    final unlocked = <String, DateTime>{};
    (m['unlocked'] as Map?)?.forEach((k, v) {
      final t = ms(v);
      if (t != null) unlocked[k as String] = t;
    });
    return BlockStatus(
      lockedUntil: ms(m['lockedUntil']),
      calendarTitle: m['calendarTitle'] as String?,
      calendarEnd: ms(m['calendarEnd']),
      unlockedUntil: unlocked,
    );
  }
}
