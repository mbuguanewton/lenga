import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import 'providers.dart';

final calendarServiceProvider = Provider<CalendarService>((ref) => GoogleCalendarService());

class CalendarState {
  const CalendarState({
    this.connected = false,
    this.usingSamples = false,
    this.events = const [],
    this.blockedIds = const {},
    this.loading = false,
    this.error,
  });

  final bool connected;
  final bool usingSamples;
  final List<CalendarEvent> events;
  final Set<String> blockedIds;
  final bool loading;
  final String? error;

  CalendarState copyWith({
    bool? connected,
    bool? usingSamples,
    List<CalendarEvent>? events,
    Set<String>? blockedIds,
    bool? loading,
    Object? error = _keep,
  }) =>
      CalendarState(
        connected: connected ?? this.connected,
        usingSamples: usingSamples ?? this.usingSamples,
        events: events ?? this.events,
        blockedIds: blockedIds ?? this.blockedIds,
        loading: loading ?? this.loading,
        error: identical(error, _keep) ? this.error : error as String?,
      );

  static const _keep = Object();

  /// Events that will block apps and haven't finished yet.
  List<CalendarEvent> activeBlockedEvents(DateTime now) =>
      [for (final e in events) if (blockedIds.contains(e.id) && e.end.isAfter(now)) e];
}

class CalendarNotifier extends Notifier<CalendarState> {
  static const _connectedKey = 'calendar_connected';
  static const _samplesKey = 'calendar_samples';
  static const _eventsKey = 'calendar_events';
  static const _blockedKey = 'calendar_blocked_ids';

  CalendarService? _samples;
  bool _refreshing = false;
  DateTime? _lastRefresh;

  /// Foreground refreshes are throttled so returning from Google's own UI
  /// can't trigger another sign-in prompt in a loop.
  static const _minRefreshGap = Duration(minutes: 2);

  CalendarService get _service => state.usingSamples
      ? (_samples ??= FakeCalendarService())
      : ref.read(calendarServiceProvider);

  @override
  CalendarState build() {
    final p = ref.read(prefsProvider);
    final cached = p.getString(_eventsKey);
    return CalendarState(
      connected: p.getBool(_connectedKey) ?? false,
      usingSamples: p.getBool(_samplesKey) ?? false,
      blockedIds: (p.getStringList(_blockedKey) ?? const []).toSet(),
      events: cached == null
          ? const []
          : [
              for (final e in jsonDecode(cached) as List)
                CalendarEvent.fromJson((e as Map).cast<String, Object?>()),
            ],
    );
  }

  Future<void> connect() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await ref.read(calendarServiceProvider).connect();
      await _persistConnection(connected: true, samples: false);
      state = state.copyWith(connected: true, usingSamples: false);
      await _setBackgroundSync(true);
      await refresh(force: true);
    } on CalendarException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Could not connect: $e');
    }
  }

  /// Debug builds only: skip OAuth and use [FakeCalendarService].
  Future<void> useSamples() async {
    assert(kDebugMode);
    await _persistConnection(connected: true, samples: true);
    state = state.copyWith(connected: true, usingSamples: true, error: null);
    await refresh(force: true);
  }

  Future<void> disconnect() async {
    try {
      await _service.disconnect();
    } catch (_) {}
    final p = ref.read(prefsProvider);
    await _persistConnection(connected: false, samples: false);
    await p.remove(_eventsKey);
    state = const CalendarState();
    await _setBackgroundSync(false);
    await _syncWindows();
  }

  /// [force] is for explicit user actions (connect, pull to refresh).
  /// [background] is true inside the headless sync engine: never touch UI-ish state.
  Future<void> refresh({bool force = false, bool background = false}) async {
    if (!state.connected || _refreshing) return;
    if (!state.usingSamples && !LengaConfig.googleConfigured) {
      // Don't try (and fail) to reach Google; keep cached events and toggles.
      if (!background) state = state.copyWith(error: LengaConfig.missingClientIdMessage);
      return;
    }
    if (!background && !state.usingSamples) _setBackgroundSync(true);
    final last = _lastRefresh;
    if (!force && last != null && DateTime.now().difference(last) < _minRefreshGap) return;
    _refreshing = true;
    _lastRefresh = DateTime.now();
    state = state.copyWith(loading: true, error: null);
    try {
      if (!state.usingSamples && !await ref.read(calendarServiceProvider).restore()) {
        state = state.copyWith(loading: false, error: 'Sign in again to refresh your calendar.');
        return;
      }
      final events = await _service.fetchEvents();
      // Forget toggles for events that no longer exist.
      final ids = {for (final e in events) e.id};
      final blocked = state.blockedIds.intersection(ids);
      state = state.copyWith(events: events, blockedIds: blocked, loading: false);
      await _persistEvents();
      await _syncWindows();
    } on CalendarException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Could not refresh events: $e');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> toggle(String eventId) async {
    final next = {...state.blockedIds};
    if (!next.remove(eventId)) next.add(eventId);
    state = state.copyWith(blockedIds: next);
    await ref.read(prefsProvider).setStringList(_blockedKey, next.toList());
    await _syncWindows();
  }

  Future<void> _setBackgroundSync(bool on) async {
    try {
      await ref.read(bridgeProvider).setCalendarSync(on);
    } catch (e) {
      debugPrint('Lenga: background calendar sync toggle failed: $e');
    }
  }

  Future<void> _syncWindows() async {
    try {
      await ref.read(bridgeProvider).syncCalendarWindows(state.activeBlockedEvents(DateTime.now()));
    } catch (e) {
      debugPrint('Lenga: calendar window sync failed: $e');
    }
  }

  Future<void> _persistConnection({required bool connected, required bool samples}) async {
    final p = ref.read(prefsProvider);
    await p.setBool(_connectedKey, connected);
    await p.setBool(_samplesKey, samples);
  }

  Future<void> _persistEvents() => ref
      .read(prefsProvider)
      .setString(_eventsKey, jsonEncode([for (final e in state.events) e.toJson()]));
}

final calendarProvider = NotifierProvider<CalendarNotifier, CalendarState>(CalendarNotifier.new);
