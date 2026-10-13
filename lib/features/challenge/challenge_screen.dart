import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../logic/challenge_controller.dart';
import '../../models/stats_event.dart';

/// The challenge UI, shared by the in-app "Try opening" flow and the native
/// overlay activity. Mirrors the three states in the mockup: asking, locked, done.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.packageName,
    required this.appName,
    required this.onClose,
    required this.onContinue,
    this.closeLabel = 'Back to Lenga',
    this.calendarTitle,
    this.calendarEnd,
  });

  final String packageName;
  final String appName;

  /// Leave without opening the app (X button, Back, "Back to ...").
  final VoidCallback onClose;

  /// Success: open the app.
  final VoidCallback onContinue;
  final String closeLabel;

  /// Set when a calendar event, not a problem, is what blocks the app.
  final String? calendarTitle;
  final DateTime? calendarEnd;

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  ChallengeController? _controller;
  final _answer = TextEditingController();
  final _focus = FocusNode();

  bool get _calendarBlock => widget.calendarTitle != null;

  @override
  void initState() {
    super.initState();
    if (_calendarBlock) {
      ref.read(bridgeProvider).recordEvent(StatsEvent(
            time: DateTime.now(),
            packageName: widget.packageName,
            appName: widget.appName,
            kind: StatKind.calendar,
            savedMinutes: kDismissCreditMinutes,
          ));
      return;
    }
    final settings = ref.read(settingsProvider);
    _controller = ChallengeController(
      packageName: widget.packageName,
      appName: widget.appName,
      difficulty: settings.difficulty,
      lockoutMinutes: settings.lockoutMinutes,
      source: ref.read(problemSourceProvider),
      store: ref.read(bridgeProvider),
    )..start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _answer.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    await _controller?.dismiss();
    // Refill in the background for the next challenge.
    ref.read(aiGeneratorProvider).refill(ref.read(settingsProvider).difficulty);
    widget.onClose();
  }

  Future<void> _submit() async {
    final c = _controller!;
    await c.submit(_answer.text);
    if (c.phase == ChallengePhase.asking) {
      _answer.clear();
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(backgroundColor: cs.surfaceContainerHigh),
                    onPressed: _leave,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _calendarBlock
                        ? _calendarView(context)
                        : ListenableBuilder(
                            listenable: _controller!,
                            builder: (context, _) => _body(context, _controller!),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ChallengeController c) {
    switch (c.phase) {
      case ChallengePhase.loading:
        return const SizedBox(height: 48, width: 48, child: CircularProgressIndicator());
      case ChallengePhase.asking:
        return _asking(context, c);
      case ChallengePhase.locked:
        return _locked(context, c);
      case ChallengePhase.done:
        return _done(context);
    }
  }

  Widget _badge(BuildContext context, IconData icon, {bool filled = false, Color? bg, Color? fg}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: bg ?? (filled ? cs.primary : cs.primaryContainer),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, size: 26, color: fg ?? (filled ? cs.onPrimary : cs.onPrimaryContainer)),
    );
  }

  Widget _title(String text) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3));

  Widget _sub(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _asking(BuildContext context, ChallengeController c) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _badge(context, Icons.lock_outline),
        _title('${widget.appName} is locked'),
        _sub(context, 'Solve this to open it for ${c.unlockMinutes} minutes.'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(c.problem!.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _answer,
          focusNode: _focus,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Your answer',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (c.wrongFeedback)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Not quite — try the next one.',
                style: TextStyle(fontSize: 13, color: cs.error, fontWeight: FontWeight.w500)),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < c.maxAttempts; i++)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < c.attemptsLeft ? cs.primary : cs.outlineVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _submit, child: const Text('Submit answer')),
      ],
    );
  }

  Widget _locked(BuildContext context, ChallengeController c) {
    final cs = Theme.of(context).colorScheme;
    final m = c.lockSecondsLeft ~/ 60, s = c.lockSecondsLeft % 60;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _badge(context, Icons.schedule, bg: cs.surfaceContainerHigh, fg: cs.onSurface),
        _title('Take a short break'),
        _sub(context,
            "Three tries wasn't quite enough this time. ${widget.appName} unlocks when this reaches zero."),
        Text('$m:${s.toString().padLeft(2, '0')}',
            style: const TextStyle(
                fontSize: 56, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: _leave,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(widget.closeLabel),
        ),
      ],
    );
  }

  Widget _done(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _badge(context, Icons.check, filled: true),
        _title('Nice work'),
        _sub(context, '${widget.appName} is open for the next ${_controller!.unlockMinutes} minutes.'),
        FilledButton(onPressed: widget.onContinue, child: Text('Continue to ${widget.appName}')),
      ],
    );
  }

  Widget _calendarView(BuildContext context) {
    final end = widget.calendarEnd;
    final until = end == null ? '' : ' until ${DateFormat.jm().format(end)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _badge(context, Icons.event_busy),
        _title('${widget.appName} is blocked'),
        _sub(context,
            '"${widget.calendarTitle}" is on, so Lenga is keeping ${widget.appName} closed$until.'),
        FilledButton(onPressed: widget.onClose, child: Text(widget.closeLabel)),
      ],
    );
  }
}
