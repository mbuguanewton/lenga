import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/calendar_event.dart';

class CalendarException implements Exception {
  const CalendarException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class CalendarService {
  /// Interactive sign-in. Throws [CalendarException] with a user-facing message.
  Future<void> connect();

  /// Restores a previous sign-in without UI. Returns whether it succeeded.
  Future<bool> restore();

  Future<void> disconnect();

  /// Timed events from the start of today through the next 7 days.
  Future<List<CalendarEvent>> fetchEvents();
}

class GoogleCalendarService implements CalendarService {
  static const _scope = 'https://www.googleapis.com/auth/calendar.readonly';

  Future<void>? _init;
  GoogleSignInAccount? _account;

  Future<void> _ensureInit() {
    if (!LengaConfig.googleConfigured) {
      throw const CalendarException(LengaConfig.missingClientIdMessage);
    }
    return _init ??=
        GoogleSignIn.instance.initialize(serverClientId: LengaConfig.googleServerClientId);
  }

  @override
  Future<void> connect() async {
    await _ensureInit();
    try {
      _account = await GoogleSignIn.instance.authenticate(scopeHint: const [_scope]);
      await _account!.authorizationClient.authorizeScopes(const [_scope]);
    } on GoogleSignInException catch (e) {
      _account = null;
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const CalendarException('Sign-in was cancelled.');
      }
      throw CalendarException('Google sign-in failed (${e.code.name}). ${e.description ?? ''}'.trim());
    }
  }

  /// Access token for the calendar scope without any UI. Works from a
  /// background engine (no Activity) as long as the user granted access before.
  Future<String?> _silentToken() async {
    final client = _account?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
    final authz = await client.authorizationForScopes(const [_scope]);
    return authz?.accessToken;
  }

  @override
  Future<bool> restore() async {
    if (!LengaConfig.googleConfigured) return false;
    try {
      await _ensureInit();
      if (await _silentToken() != null) return true;
      // Foreground-only fallback; throws "no activity" in a background engine.
      _account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      return _account != null && await _silentToken() != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _account = null;
    if (!LengaConfig.googleConfigured) return;
    await _ensureInit();
    await GoogleSignIn.instance.signOut();
  }

  @override
  Future<List<CalendarEvent>> fetchEvents() async {
    await _ensureInit();
    final token = await _silentToken();
    if (token == null) throw const CalendarException('Calendar access was revoked. Reconnect to continue.');

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final uri = Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events', {
      'timeMin': from.toUtc().toIso8601String(),
      'timeMax': from.add(const Duration(days: 8)).toUtc().toIso8601String(),
      'singleEvents': 'true',
      'orderBy': 'startTime',
      'maxResults': '100',
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw CalendarException(describeAuthFailure(res.statusCode, res.body));
    }
    if (res.statusCode != 200) {
      throw CalendarException('Could not load events (HTTP ${res.statusCode}).');
    }
    return parseEvents(res.body);
  }

  /// Turns a 401/403 from the Calendar API into something actionable, using
  /// Google's own error reason when the body has one.
  static String describeAuthFailure(int status, String body) {
    var reason = '';
    var message = '';
    try {
      final err = (jsonDecode(body) as Map)['error'] as Map?;
      message = (err?['message'] as String?) ?? '';
      final errors = err?['errors'] as List?;
      reason = errors != null && errors.isNotEmpty ? ((errors.first as Map)['reason'] as String? ?? '') : '';
      final details = err?['details'] as List?;
      if (reason.isEmpty && details != null) {
        for (final d in details) {
          final r = (d as Map)['reason'];
          if (r is String) reason = r;
        }
      }
    } catch (_) {}
    if (reason == 'accessNotConfigured' || reason == 'SERVICE_DISABLED') {
      return 'The Google Calendar API is not enabled for this Google Cloud project. '
          'Enable it under APIs & Services > Library, wait a minute, then refresh.';
    }
    if (reason == 'insufficientPermissions' || reason == 'ACCESS_TOKEN_SCOPE_INSUFFICIENT') {
      return 'Calendar permission was not granted. Disconnect, reconnect and allow calendar access.';
    }
    if (status == 401) return 'Google sign-in expired. Disconnect and reconnect your calendar.';
    return 'Google refused the request (HTTP $status${reason.isEmpty ? '' : ', $reason'}). '
        '${message.isEmpty ? '' : message}'.trim();
  }

  /// Parses a Calendar API `events.list` body, skipping all-day and cancelled events.
  static List<CalendarEvent> parseEvents(String body) {
    final items = (jsonDecode(body) as Map)['items'] as List? ?? const [];
    final events = <CalendarEvent>[];
    for (final raw in items) {
      final m = raw as Map;
      if (m['status'] == 'cancelled') continue;
      final start = (m['start'] as Map?)?['dateTime'] as String?;
      final end = (m['end'] as Map?)?['dateTime'] as String?;
      if (start == null || end == null) continue; // all-day
      events.add(CalendarEvent(
        id: m['id'] as String,
        title: (m['summary'] as String?)?.trim().isNotEmpty == true ? m['summary'] as String : '(No title)',
        start: DateTime.parse(start).toLocal(),
        end: DateTime.parse(end).toLocal(),
      ));
    }
    return events;
  }
}

/// Debug-only sample events so the Calendar screen is usable without OAuth.
/// Includes an event starting in two minutes to test blocking end to end.
class FakeCalendarService implements CalendarService {
  @override
  Future<void> connect() async {}
  @override
  Future<bool> restore() async => true;
  @override
  Future<void> disconnect() async {}

  @override
  Future<List<CalendarEvent>> fetchEvents() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    CalendarEvent at(String id, String title, int h, int m, int minutes) => CalendarEvent(
          id: id,
          title: title,
          start: today.add(Duration(hours: h, minutes: m)),
          end: today.add(Duration(hours: h, minutes: m + minutes)),
        );
    return [
      CalendarEvent(
        id: 'fake-soon',
        title: 'Test block (starts in 2 min)',
        start: now.add(const Duration(minutes: 2)),
        end: now.add(const Duration(minutes: 5)),
      ),
      at('fake-1', 'Team Standup', 9, 0, 15),
      at('fake-2', 'Design Review', 10, 0, 60),
      at('fake-3', 'Deep Work Block', 14, 0, 120),
      at('fake-4', '1:1 with Sam', 16, 30, 30),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }
}
