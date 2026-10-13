import 'package:flutter/material.dart';

/// Rounded tonal surface used for lists and cards throughout the mockup.
class LengaCard extends StatelessWidget {
  const LengaCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.radius = 24});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar(this.letter, {super.key, this.size = 40});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(letter,
          style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, this.subtitle, {super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.96,
          color: color ?? Theme.of(context).colorScheme.primary,
        ));
  }
}

/// Outlined pill, e.g. "Try opening".
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onPressed, this.filled = false});

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
    const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    const text = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
                minimumSize: Size.zero, padding: pad, shape: shape, textStyle: text),
            child: Text(label))
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              padding: pad,
              shape: shape,
              textStyle: text,
              foregroundColor: cs.onSurfaceVariant,
              side: BorderSide(color: cs.outline, width: 1.5),
            ),
            child: Text(label));
  }
}

/// Inline notice with an optional action, used for permission/paused states.
class Banner2 extends StatelessWidget {
  const Banner2({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: cs.onErrorContainer, fontWeight: FontWeight.w500)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: cs.onErrorContainer),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
