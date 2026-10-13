# Lenga

Android app that blocks chosen apps behind a short math challenge. Three wrong answers start a timed lockout; calendar events can block the same apps for their duration. Flutter UI, Kotlin blocking layer. The design spec is `../Social media blocker with AI/Lenga.dc.html`.

## Run

```
flutter pub get
flutter run                      # device or emulator (Android only)
flutter analyze && flutter test
```

Blocking needs two special grants, which the onboarding sends you to: **Usage access** and **Display over other apps**. On an emulator you can grant them without the Settings UI:

```
adb shell appops set com.lenga.lenga_app GET_USAGE_STATS allow
adb shell appops set com.lenga.lenga_app SYSTEM_ALERT_WINDOW allow
```

## Google Calendar setup

The Connect button shows "not configured" until a real OAuth client exists.

1. In Google Cloud Console, enable the **Google Calendar API** and configure the OAuth consent screen (scope `calendar.readonly`).
2. Create an **Android** OAuth client: package `com.lenga.lenga_app` plus your signing SHA-1 (`cd android && ./gradlew signingReport`).
3. Create a **Web application** OAuth client. google_sign_in 7 on Android authenticates through it.
4. Put the web client ID in a local, git-ignored file and run with it:
   ```
   cp env.example.json env.json      # then edit the ID inside
   flutter run --release --dart-define-from-file=env.json
   ```
   The ID is a build-time value, not stored in the app: any build made without the file (for example a plain `flutter build apk`) has no ID, and Calendar will ask for one. Your events, toggles and other data are kept.

Debug builds also offer "Use sample events", including an event that starts two minutes from now, for testing blocking without OAuth.

## How blocking works

`BlockerService` (foreground service) polls `UsageStatsManager` every 400 ms. When the foreground app is on the block list and has no unlock window (or a lockout / calendar window is active), it starts `ChallengeActivity`: a Flutter activity running the `challengeMain` entrypoint in its own engine. The blocked app may flash briefly before the challenge covers it. Back, Home and Recents all finish the challenge and return to the launcher.

Lockout end time, per-app unlock windows, stats events, calendar windows and the AI problem queue live in native SharedPreferences (`NativeStore.kt`) so both Flutter engines share them. Dart reaches them through the `com.lenga/blocker` channel.

Problems come from a local generator (`lib/logic/problem_generator.dart`). Where Gemini Nano is available through ML Kit GenAI, the queue is topped up in the background; every AI problem is re-solved in code (`problem_validator.dart`) and dropped on mismatch. The challenge never waits on the model.

## Play Store declarations to prepare

- `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW`: explain they detect a user-selected app opening and show the unlock challenge over it.
- Foreground service type `specialUse` (subtype text is in the manifest).
- `SCHEDULE_EXACT_ALARM`: alarms at the start of user-enabled calendar blocks.
- No accessibility service and no `QUERY_ALL_PACKAGES` (apps are listed via a `<queries>` launcher intent).

## Limitations

- Polling-based detection: brief flash of the blocked app, and OEM battery optimisers can stop the service. Onboarding/Settings link to the app's settings page; Home shows a "Blocking is paused" banner if the heartbeat goes stale.
- Calendar events refresh when the app is opened, on pull-to-refresh, and every ~30 minutes in the background (WorkManager boots a headless engine, `calendarSyncMain`). Background refresh needs a silent Google token: if Google can't hand one out without UI, it skips quietly and the next time you open Lenga recovers. Android may delay periodic jobs (Doze, battery saver), so treat 30 minutes as a minimum, not a guarantee.
- Gemini Nano only works on supported physical devices; elsewhere Settings shows "Unavailable" and local problems are used.
- "Saved time" is an estimate (lockout length, or 5 minutes per abandoned challenge / calendar block).
