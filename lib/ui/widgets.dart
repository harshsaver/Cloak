import 'package:flutter/material.dart';

import '../models/provider.dart';
import 'theme.dart';

/// A circular illustrated portrait (10–44) used as a conversation avatar.
class PortraitAvatar extends StatelessWidget {
  final int number;
  final double size;
  const PortraitAvatar({super.key, required this.number, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        image: DecorationImage(
          image: AssetImage('assets/portraits/$number.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// The tinted glyph that identifies a routing provider.
class ProviderGlyph extends StatelessWidget {
  final AiProvider provider;
  final double size;
  const ProviderGlyph({super.key, required this.provider, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [provider.tint, Color.lerp(provider.tint, Colors.black, 0.18)!],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(provider.icon, color: Colors.white, size: size * 0.44),
    );
  }
}

/// The three-dot "receiving a reply" indicator.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = (_controller.value * 3).floor() % 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active = i == phase;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(0, active ? -2 : 0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: active ? 0.75 : 0.3),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// The pill-style toggle used for Web search / Cloak in the composer.
class ChatOptionToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? tooltip;
  const ChatOptionToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value ? CloakColors.accent.withValues(alpha: 0.14) : scheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: value ? CloakColors.accent.withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: value ? CloakColors.accent : scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: value ? CloakColors.accent : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

/// A subtle rounded card used across panels.
class PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PanelCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
