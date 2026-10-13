import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/calendar_provider.dart';
import 'data/providers.dart';
import 'features/challenge/challenge_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell.dart';
import 'services/platform_bridge.dart';
import 'theme/lenga_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(lengaSystemUi);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const LengaApp(),
  ));
}

/// Entry point for `ChallengeActivity`: the full-screen challenge shown over a
/// blocked app. Runs in its own Flutter engine.
@pragma('vm:entry-point')
Future<void> challengeMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(lengaSystemUi);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const ChallengeApp(),
  ));
}

/// Entry point for `CalendarSyncWorker`: refreshes calendar events and the
/// blocking windows in a headless engine (no UI, no Activity).
@pragma('vm:entry-point')
Future<void> calendarSyncMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  try {
    await container.read(calendarProvider.notifier).refresh(force: true, background: true);
  } catch (_) {
    // Best effort: the next foreground refresh or periodic run retries.
  } finally {
    await container.read(bridgeProvider).finishBackgroundSync();
    container.dispose();
  }
}

class LengaApp extends ConsumerWidget {
  const LengaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Lenga',
      debugShowCheckedModeBanner: false,
      theme: lengaTheme(),
      home: ref.watch(onboardedProvider) ? const Shell() : const OnboardingScreen(),
    );
  }
}

class ChallengeApp extends ConsumerWidget {
  const ChallengeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bridge = ref.read(bridgeProvider);
    return MaterialApp(
      title: 'Lenga',
      debugShowCheckedModeBanner: false,
      theme: lengaTheme(),
      home: FutureBuilder<ChallengeContext?>(
        future: bridge.challengeContext(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final c = snap.data;
          if (c == null) {
            // Launched without a target: nothing to block, leave.
            WidgetsBinding.instance.addPostFrameCallback((_) => bridge.exitToHome());
            return const Scaffold();
          }
          return ChallengeScreen(
            packageName: c.packageName,
            appName: c.appName,
            calendarTitle: c.calendarTitle,
            calendarEnd: c.calendarEnd,
            closeLabel: 'Back to home',
            onClose: bridge.exitToHome,
            onContinue: () => bridge.launchApp(c.packageName),
          );
        },
      ),
    );
  }
}
