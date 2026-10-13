import 'dart:convert';

import 'package:flutter/services.dart';

import '../logic/block_status.dart';
import '../logic/challenge_controller.dart';
import '../logic/problem_source.dart';
import '../models/blocked_app.dart';
import '../models/calendar_event.dart';
import '../models/problem.dart';
import '../models/stats_event.dart';

class LengaPermissions {
  const LengaPermissions({
    required this.usageAccess,
    required this.overlay,
    required this.notifications,
  });

  final bool usageAccess;
  final bool overlay;
  final bool notifications;

  bool get blockingReady => usageAccess && overlay;

  static const none = LengaPermissions(usageAccess: false, overlay: false, notifications: false);
}

/// Why the challenge overlay was opened by the native blocker.
class ChallengeContext {
  const ChallengeContext({
    required this.packageName,
    required this.appName,
    this.calendarTitle,
    this.calendarEnd,
  });

  final String packageName;
  final String appName;

  /// Set when the app is blocked by a calendar event rather than a problem.
  final String? calendarTitle;
  final DateTime? calendarEnd;

  bool get isCalendarBlock => calendarTitle != null;
}

/// Everything Dart needs from the Android side. The real implementation talks
/// to `BlockerPlugin.kt`; [MemoryPlatformBridge] is used in tests and on
/// platforms without a blocker.
abstract class PlatformBridge implements ChallengeStore, ProblemQueue, AiBackend {
  Future<List<InstalledApp>> installedApps();
  Future<LengaPermissions> permissions();
  Future<void> openUsageAccessSettings();
  Future<void> openOverlaySettings();
  Future<void> requestNotifications();
  Future<void> openBatterySettings();

  /// Pushes what the service needs: block list, difficulty, lockout length.
  Future<void> syncConfig({
    required List<BlockedApp> blocked,
    required Difficulty difficulty,
    required int lockoutMinutes,
  });

  /// Starts or stops the foreground blocking service.
  Future<void> setBlockingEnabled(bool enabled);

  /// True if blocking should be running but the service has stopped (OEM kill).
  Future<bool> blockingPaused();

  Future<List<StatsEvent>> statsEvents();

  /// Current lockout, calendar block and unlock windows for [packages].
  Future<BlockStatus> blockStatus(List<String> packages);

  /// Replaces the set of calendar windows during which blocked apps are locked.
  Future<void> syncCalendarWindows(List<CalendarEvent> blockedEvents);

  /// Starts or stops the periodic background calendar refresh.
  Future<void> setCalendarSync(bool enabled);

  /// Called by the background sync entrypoint when it is finished.
  Future<void> finishBackgroundSync();

  /// Non-null only inside the native challenge activity.
  Future<ChallengeContext?> challengeContext();
  Future<void> launchApp(String packageName);

  /// Leaves the challenge activity and shows the home screen.
  Future<void> exitToHome();
}

class AndroidPlatformBridge implements PlatformBridge {
  AndroidPlatformBridge([MethodChannel? channel])
      : _ch = channel ?? const MethodChannel('com.lenga/blocker');

  final MethodChannel _ch;

  Future<T> _call<T>(String method, [Object? args]) async => (await _ch.invokeMethod<T>(method, args)) as T;

  @override
  Future<List<InstalledApp>> installedApps() async {
    final list = await _call<List<Object?>>('installedApps');
    return [for (final m in list) InstalledApp.fromMap(m! as Map)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<LengaPermissions> permissions() async {
    final m = await _call<Map<Object?, Object?>>('permissions');
    return LengaPermissions(
      usageAccess: m['usageAccess'] == true,
      overlay: m['overlay'] == true,
      notifications: m['notifications'] == true,
    );
  }

  @override
  Future<void> openUsageAccessSettings() => _call('openUsageAccessSettings');
  @override
  Future<void> openOverlaySettings() => _call('openOverlaySettings');
  @override
  Future<void> requestNotifications() => _call('requestNotifications');
  @override
  Future<void> openBatterySettings() => _call('openBatterySettings');

  @override
  Future<void> syncConfig({
    required List<BlockedApp> blocked,
    required Difficulty difficulty,
    required int lockoutMinutes,
  }) =>
      _call('syncConfig', {
        'blocked': [for (final a in blocked) a.packageName],
        'difficulty': difficulty.name,
        'lockoutMinutes': lockoutMinutes,
      });

  @override
  Future<void> setBlockingEnabled(bool enabled) => _call('setBlockingEnabled', enabled);

  @override
  Future<bool> blockingPaused() async => await _call<bool?>('blockingPaused') ?? false;

  @override
  Future<List<StatsEvent>> statsEvents() async {
    final raw = await _call<String>('statsEvents');
    final list = jsonDecode(raw) as List;
    return [for (final e in list) StatsEvent.fromJson((e as Map).cast<String, Object?>())];
  }

  @override
  Future<BlockStatus> blockStatus(List<String> packages) async =>
      BlockStatus.fromMap(await _call<Map<Object?, Object?>>('blockStatus', packages));

  @override
  Future<void> syncCalendarWindows(List<CalendarEvent> blockedEvents) => _call(
        'syncCalendarWindows',
        jsonEncode([for (final e in blockedEvents) e.toJson()]),
      );

  @override
  Future<void> setCalendarSync(bool enabled) => _call('setCalendarSync', enabled);
  @override
  Future<void> finishBackgroundSync() => _call('finishBackgroundSync');

  @override
  Future<ChallengeContext?> challengeContext() async {
    final m = await _call<Map<Object?, Object?>?>('challengeContext');
    if (m == null) return null;
    final end = m['calendarEnd'] as int?;
    return ChallengeContext(
      packageName: m['package']! as String,
      appName: m['name']! as String,
      calendarTitle: m['calendarTitle'] as String?,
      calendarEnd: end == null ? null : DateTime.fromMillisecondsSinceEpoch(end),
    );
  }

  @override
  Future<void> launchApp(String packageName) => _call('launchApp', packageName);
  @override
  Future<void> exitToHome() => _call('exitToHome');

  // ChallengeStore

  @override
  Future<DateTime?> lockedUntil() async {
    final ms = await _call<int>('getLockedUntil');
    return ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  Future<void> setLockedUntil(DateTime? until) =>
      _call('setLockedUntil', until?.millisecondsSinceEpoch ?? 0);

  @override
  Future<void> setUnlockedUntil(String packageName, DateTime until) =>
      _call('setUnlockedUntil', {'package': packageName, 'until': until.millisecondsSinceEpoch});

  @override
  Future<void> recordEvent(StatsEvent event) => _call('recordEvent', jsonEncode(event.toJson()));

  // ProblemQueue

  @override
  Future<Problem?> pop(Difficulty difficulty) async {
    final raw = await _call<String?>('popProblem', difficulty.name);
    if (raw == null) return null;
    return Problem.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  @override
  Future<int> size(Difficulty difficulty) => _call<int>('problemQueueSize', difficulty.name);

  @override
  Future<void> push(Difficulty difficulty, List<Problem> problems) => _call('pushProblems', {
        'difficulty': difficulty.name,
        'problems': jsonEncode([for (final p in problems) p.toJson()]),
      });

  // AiBackend

  @override
  Future<AiAvailability> availability() async {
    final s = await _call<String>('aiAvailability');
    return AiAvailability.values.firstWhere((a) => a.name == s, orElse: () => AiAvailability.unavailable);
  }

  @override
  Future<String> generate(String prompt) => _call<String>('aiGenerate', prompt);
}

/// In-memory stand-in for tests and non-Android platforms.
class MemoryPlatformBridge implements PlatformBridge {
  MemoryPlatformBridge({
    this.apps = const [],
    this.perms = const LengaPermissions(usageAccess: true, overlay: true, notifications: true),
    this.aiAvailability = AiAvailability.unavailable,
  });

  List<InstalledApp> apps;
  LengaPermissions perms;
  AiAvailability aiAvailability;
  String aiResponse = '[]';

  DateTime? locked;
  final Map<String, DateTime> unlocked = {};
  final List<StatsEvent> events = [];
  final Map<Difficulty, List<Problem>> queue = {};
  List<BlockedApp> syncedBlocked = [];
  List<CalendarEvent> syncedWindows = [];
  bool blockingEnabled = false;
  bool paused = false;
  ChallengeContext? context;

  @override
  Future<List<InstalledApp>> installedApps() async => apps;
  @override
  Future<LengaPermissions> permissions() async => perms;
  @override
  Future<void> openUsageAccessSettings() async {}
  @override
  Future<void> openOverlaySettings() async {}
  @override
  Future<void> requestNotifications() async {}
  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<void> syncConfig({
    required List<BlockedApp> blocked,
    required Difficulty difficulty,
    required int lockoutMinutes,
  }) async =>
      syncedBlocked = blocked;

  @override
  Future<void> setBlockingEnabled(bool enabled) async => blockingEnabled = enabled;
  @override
  Future<bool> blockingPaused() async => paused;
  @override
  Future<List<StatsEvent>> statsEvents() async => List.of(events);
  @override
  Future<BlockStatus> blockStatus(List<String> packages) async {
    final now = DateTime.now();
    final active = syncedWindows.where((e) => !e.start.isAfter(now) && e.end.isAfter(now));
    return BlockStatus(
      lockedUntil: locked,
      calendarTitle: active.isEmpty ? null : active.first.title,
      calendarEnd: active.isEmpty ? null : active.first.end,
      unlockedUntil: Map.of(unlocked),
    );
  }

  @override
  Future<void> syncCalendarWindows(List<CalendarEvent> blockedEvents) async =>
      syncedWindows = blockedEvents;
  bool calendarSync = false;
  @override
  Future<void> setCalendarSync(bool enabled) async => calendarSync = enabled;
  @override
  Future<void> finishBackgroundSync() async {}
  @override
  Future<ChallengeContext?> challengeContext() async => context;
  @override
  Future<void> launchApp(String packageName) async {}
  @override
  Future<void> exitToHome() async {}

  @override
  Future<DateTime?> lockedUntil() async => locked;
  @override
  Future<void> setLockedUntil(DateTime? until) async => locked = until;
  @override
  Future<void> setUnlockedUntil(String packageName, DateTime until) async =>
      unlocked[packageName] = until;
  @override
  Future<void> recordEvent(StatsEvent event) async => events.add(event);

  @override
  Future<Problem?> pop(Difficulty difficulty) async {
    final q = queue[difficulty];
    return q == null || q.isEmpty ? null : q.removeAt(0);
  }

  @override
  Future<int> size(Difficulty difficulty) async => queue[difficulty]?.length ?? 0;
  @override
  Future<void> push(Difficulty difficulty, List<Problem> problems) async =>
      (queue[difficulty] ??= []).addAll(problems);

  @override
  Future<AiAvailability> availability() async => aiAvailability;
  @override
  Future<String> generate(String prompt) async => aiResponse;
}
