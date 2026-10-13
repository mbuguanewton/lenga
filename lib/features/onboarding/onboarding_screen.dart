import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../services/platform_bridge.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: i == _step ? 28 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i == _step ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_step) {
                    0 => const _Welcome(),
                    1 => const _HowItWorks(),
                    _ => const _Permissions(),
                  },
                ),
              ),
              if (_step < 2)
                FilledButton(onPressed: () => setState(() => _step++), child: const Text('Continue'))
              else
                const _FinishButtons(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 72),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(24)),
          child: Icon(Icons.lens_outlined, size: 34, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 28),
        const Text('Lenga',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1)),
        const SizedBox(height: 12),
        Text(
          'A calm way to put distance between you and your social apps. '
          'Solve a quick problem before you can open them.',
          style: TextStyle(fontSize: 16, height: 1.5, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const steps = [
      ('01', 'Pick the apps you want out of easy reach.'),
      ('02', "Open one, and we'll ask you to solve a short problem first."),
      ('03', "Can't solve it? You wait out a short timer instead. Either way, you've paused."),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 56),
        const Text('How it works',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(height: 24),
        for (final (n, text) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(n,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.primary)),
                ),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.45))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Step 3. The mockup asks for one "accessibility" permission; Lenga uses two
/// lighter grants instead (Usage access + Display over other apps).
class _Permissions extends ConsumerStatefulWidget {
  const _Permissions();

  @override
  ConsumerState<_Permissions> createState() => _PermissionsState();
}

class _PermissionsState extends ConsumerState<_Permissions> with WidgetsBindingObserver {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Settings pages don't report back, so poll until granted.
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => ref.invalidate(permissionsProvider));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(permissionsProvider);
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bridge = ref.read(bridgeProvider);
    final perms = ref.watch(permissionsProvider).value ?? LengaPermissions.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 56),
        const Text('Two permissions',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Text(
          'Lenga needs these to notice when you open a blocked app and to show the challenge over it. '
          'Nothing leaves your phone.',
          style: TextStyle(fontSize: 15, height: 1.5, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        PermissionTile(
          title: 'Usage access',
          subtitle: 'Required to detect app launches',
          granted: perms.usageAccess,
          onGrant: bridge.openUsageAccessSettings,
        ),
        PermissionTile(
          title: 'Display over other apps',
          subtitle: 'Required to show the challenge',
          granted: perms.overlay,
          onGrant: bridge.openOverlaySettings,
        ),
        PermissionTile(
          title: 'Notifications',
          subtitle: 'Keeps blocking running in the background',
          granted: perms.notifications,
          onGrant: bridge.requestNotifications,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: bridge.openBatterySettings,
          icon: const Icon(Icons.battery_saver_outlined),
          label: const Text('Battery settings (set to Unrestricted)'),
        ),
        Text(
          'Some phones stop background apps to save battery. Allowing Lenga to run unrestricted keeps blocking reliable.',
          style: TextStyle(fontSize: 12, height: 1.4, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class PermissionTile extends StatelessWidget {
  const PermissionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (granted)
            Icon(Icons.check_circle, color: cs.primary)
          else
            FilledButton.tonal(
              onPressed: onGrant,
              style: FilledButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: const Text('Grant'),
            ),
        ],
      ),
    );
  }
}

class _FinishButtons extends ConsumerWidget {
  const _FinishButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(permissionsProvider).value?.blockingReady ?? false;
    Future<void> finish() => ref.read(onboardedProvider.notifier).finish();
    return Column(
      children: [
        FilledButton(onPressed: ready ? finish : null, child: const Text('Get started')),
        if (!ready)
          TextButton(onPressed: finish, child: const Text('Skip for now — blocking stays off')),
      ],
    );
  }
}
