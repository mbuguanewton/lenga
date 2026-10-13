import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/services/calendar_service.dart';

void main() {
  test('names the disabled Calendar API instead of a generic error', () {
    const body = '{"error":{"code":403,"message":"Google Calendar API has not been used in project 1 before or it is disabled.",'
        '"errors":[{"reason":"accessNotConfigured"}]}}';
    expect(GoogleCalendarService.describeAuthFailure(403, body), contains('not enabled'));
  });

  test('reads the reason from error details too', () {
    const body = '{"error":{"code":403,"message":"x","details":[{"reason":"SERVICE_DISABLED"}]}}';
    expect(GoogleCalendarService.describeAuthFailure(403, body), contains('not enabled'));
  });

  test('insufficient scope and expired token get their own advice', () {
    expect(
      GoogleCalendarService.describeAuthFailure(403, '{"error":{"errors":[{"reason":"insufficientPermissions"}]}}'),
      contains('permission'),
    );
    expect(GoogleCalendarService.describeAuthFailure(401, '{}'), contains('expired'));
  });

  test('unknown failures include the status and survive a non-JSON body', () {
    expect(GoogleCalendarService.describeAuthFailure(403, 'oops'), contains('HTTP 403'));
  });
}
