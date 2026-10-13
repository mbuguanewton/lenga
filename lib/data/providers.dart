import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/block_status.dart';
import '../logic/problem_source.dart';
import '../logic/stats_summary.dart';
import '../models/blocked_app.dart';
import '../models/settings.dart';
import '../services/platform_bridge.dart';

final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

final bridgeProvider = Provider<PlatformBridge>((ref) =>
    defaultTargetPlatform == TargetPlatform.android ? AndroidPlatformBridge() : MemoryPlatformBridge());

final problemSourceProvider = Provider<ProblemSource>(
    (ref) => QueuedProblemSource(ref.watch(bridgeProvider), LocalGenerator()));

final aiGeneratorProvider = Provider<OnDeviceAiGenerator>((ref) {
  final bridge = ref.watch(bridgeProvider);
  return OnDeviceAiGenerator(bridge, bridge);
});

final aiStatusProvider = FutureProvider.autoDispose<AiAvailability>(
    (ref) => ref.watch(aiGeneratorProvider).status());

class OnboardedNotifier extends Notifier<bool> {
  static const _key = 'onboarded';

  @override
  bool build() => ref.read(prefsProvider).getBool(_key) ?? false;

  Future<void> finish() async {
    state = true;
    await ref.read(prefsProvider).setBool(_key, true);
  }
}

final onboardedProvider = NotifierProvider<OnboardedNotifier, bool>(OnboardedNotifier.new);

class SettingsNotifier extends Notifier<LengaSettings> {
  static const _key = 'settings';

  @override
  LengaSettings build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const LengaSettings();
    return LengaSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<void> update(LengaSettings s) async {
    state = s;
    await ref.read(prefsProvider).setString(_key, jsonEncode(s.toJson()));
    await ref.read(nativeSyncProvider)();
    // The queue is per difficulty, so top up the new one.
    ref.read(aiGeneratorProvider).refill(s.difficulty);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, LengaSettings>(SettingsNotifier.new);

class BlockedAppsNotifier extends Notifier<List<BlockedApp>> {
  static const _key = 'blocked_apps';

  @override
  List<BlockedApp> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const [];
    return [
      for (final e in jsonDecode(raw) as List) BlockedApp.fromJson((e as Map).cast<String, Object?>()),
    ];
  }

  Future<void> _save(List<BlockedApp> apps) async {
    state = apps;
    await ref.read(prefsProvider).setString(_key, jsonEncode([for (final a in apps) a.toJson()]));
    await ref.read(nativeSyncProvider)();
  }

  Future<void> addAll(Iterable<BlockedApp> apps) => _save([...state, ...apps]);

  Future<void> remove(String packageName) =>
      _save([for (final a in state) if (a.packageName != packageName) a]);
}

final blockedAppsProvider =
    NotifierProvider<BlockedAppsNotifier, List<BlockedApp>>(BlockedAppsNotifier.new);

/// Pushes block list + settings to native and starts/stops the service.
/// Call as `ref.read(nativeSyncProvider)()`.
final nativeSyncProvider = Provider<Future<void> Function()>((ref) => () async {
      final bridge = ref.read(bridgeProvider);
      final blocked = ref.read(blockedAppsProvider);
      final settings = ref.read(settingsProvider);
      try {
        await bridge.syncConfig(
          blocked: blocked,
          difficulty: settings.difficulty,
          lockoutMinutes: settings.lockoutMinutes,
        );
        await bridge.setBlockingEnabled(blocked.isNotEmpty);
      } catch (e) {
        debugPrint('Lenga: native sync failed: $e');
      }
    });

final installedAppsProvider =
    FutureProvider.autoDispose<List<InstalledApp>>((ref) => ref.watch(bridgeProvider).installedApps());

final permissionsProvider = FutureProvider.autoDispose<LengaPermissions>(
    (ref) => ref.watch(bridgeProvider).permissions());

final blockingPausedProvider =
    FutureProvider.autoDispose<bool>((ref) => ref.watch(bridgeProvider).blockingPaused());

final statsProvider = FutureProvider.autoDispose<StatsSummary>((ref) async {
  final events = await ref.watch(bridgeProvider).statsEvents();
  return StatsSummary.compute(events, DateTime.now());
});

/// Lockout / unlock / calendar state for the Home list, polled while watched.
final blockStatusProvider = StreamProvider.autoDispose<BlockStatus>((ref) async* {
  final bridge = ref.watch(bridgeProvider);
  final packages = [for (final a in ref.watch(blockedAppsProvider)) a.packageName];
  while (true) {
    try {
      yield await bridge.blockStatus(packages);
    } catch (e) {
      debugPrint('Lenga: block status failed: $e');
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});
