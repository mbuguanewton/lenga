# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Layout

- Repo root — the Flutter app (Android only; Flutter 3.47, Dart 3.13, Riverpod 3). The Dart package is still named `lenga_app` (see `pubspec.yaml`), so imports read `package:lenga_app/...`.
- `Social media blocker with AI/` — read-only design prototype, due to be deleted; keep the app independent of it. `Lenga.dc.html` is the spec for screens and behaviour (`genProblem`, `submitAnswer`, `startLockTimer` are what the Dart code ports). `support.js` is generated/vendored; `android-frame.jsx` is a scaffold; `_ds/modernist-*` is an unrelated design system, don't use it. Do not edit these.

## Commands (run from the repo root)

```
flutter pub get
flutter analyze
flutter test                              # all
flutter test test/challenge_controller_test.dart   # one file
flutter run                               # needs an Android device/emulator
flutter build apk --release --target-platform android-arm64   # small APK; debug APK is ~160 MB
```

Emulator grants for the special permissions: `adb shell appops set com.lenga.lenga_app GET_USAGE_STATS allow` and `... SYSTEM_ALERT_WINDOW allow`. Google Calendar needs the web client ID at build time: copy `env.example.json` to the git-ignored `env.json` and add `--dart-define-from-file=env.json` to `flutter run`/`flutter build` (see `README.md`). Builds without it silently get the placeholder ID. The "sample events" calendar button only exists in debug builds (`kDebugMode`).

## Architecture

Two halves joined by one MethodChannel, `com.lenga/blocker`:

- **Dart** (`lib/`): `logic/` is pure and unit-tested (`problem_generator`, `problem_validator`, `problem_source` incl. AI queue refill, `challenge_controller`, `stats_summary`). `services/platform_bridge.dart` defines the abstract `PlatformBridge` (also the `ChallengeStore`, `ProblemQueue` and `AiBackend` interfaces), with `AndroidPlatformBridge` (channel) and `MemoryPlatformBridge` (tests / non-Android). `data/providers.dart` and `calendar_provider.dart` hold Riverpod state, persisted in `shared_preferences` as JSON. `features/*` are screens.
- **Kotlin** (`android/app/src/main/kotlin/com/lenga/lenga_app/`): `BlockerService` polls `UsageStatsManager` and starts `ChallengeActivity` over blocked apps; `ChallengeActivity` is a `FlutterActivity` running the Dart entrypoint `challengeMain` (in `lib/main.dart`) in its own engine and finishes itself on stop; `BlockerPlugin` implements the channel; `NativeStore` is the shared SharedPreferences store (block list, lockout end, per-app unlock windows, stats events, calendar windows, AI problem queue, heartbeat); `CalendarSyncWorker` (WorkManager, 30 min) refreshes events in a headless engine, so `BlockerPlugin` must keep working with a null Activity; `CalendarBlockScheduler` sets exact alarms at event starts (the service itself enforces windows from stored data); `BootReceiver` restarts everything; `AiProblemService` wraps ML Kit GenAI Prompt API (`genai-prompt:1.0.0-beta4`, needs minSdk 26).

Things that are easy to get wrong:

- The in-app "Try opening" screen and the overlay use the same `ChallengeScreen`/`ChallengeController`; lockout and unlock state go through the native store so both agree. The challenge engine is a separate Flutter engine in the same process, which is why shared state is native, not `shared_preferences`.
- Riverpod 3: `Ref` and `WidgetRef` are distinct types (hence `nativeSyncProvider`), and providers must not be mutated during build (defer with a post-frame callback, as `Shell` does).
- AI-generated problems are untrusted: always route through `ProblemValidator.validate`. The challenge must never wait on the model; `QueuedProblemSource` falls back to `LocalGenerator`.
- Permissions are deliberately Usage access + overlay (no accessibility service, no `QUERY_ALL_PACKAGES`) for Play eligibility. Keep it that way unless asked.

## Known gaps

Background calendar refresh (`CalendarSyncWorker` -> headless engine -> `calendarSyncMain`) relies on a silent Google token (`GoogleSignIn.instance.authorizationClient`, which works without an Activity; `authenticate` does not) and has not been verified on a device. The AI queue is unverified: the emulator has no Gemini Nano.
