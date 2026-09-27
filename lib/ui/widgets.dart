import 'package:flutter/material.dart';

import '../models/provider.dart';
import 'theme.dart';

/// Phone-sized layout. Everything below this width gets the mobile treatment.
bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

/// "OrcaRouter ▾" — switch between providers or go back to the provider list.
class ProviderSwitcher extends StatelessWidget {
  final AiProvider provider;
  final ValueChanged<AiProvider> onSwitch;
  final VoidCallback onAllProviders;
  final bool showGlyph;
  const ProviderSwitcher({
    super.key,
    required this.provider,
    required this.onSwitch,
    required this.onAllProviders,
    this.showGlyph = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Switch provider',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in AiProvider.all)
          PopupMenuItem(
            value: option.id,
            child: Row(children: [
              ProviderGlyph(provider: option, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(option.name)),
              if (option == provider) const Icon(Icons.check_rounded, size: 18),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '__all__', child: Text('All providers')),
      ],
      onSelected: (value) {
        if (value == '__all__') {
          onAllProviders();
        } else {
          final option = AiProvider.byId(value);
          if (option != null && option != provider) onSwitch(option);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (showGlyph) ...[ProviderGlyph(provider: provider, size: 26), const SizedBox(width: 8)],
          Text(provider.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more_rounded, size: 20),
        ]),
      ),
    );
  }
}

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

const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// The disguised Cloak mascot as a status glyph: full colour when [on], greyscale when off.
class CloakMascot extends StatelessWidget {
  final bool on;
  final double size;
  const CloakMascot({super.key, required this.on, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset('assets/brand/app_icon_1024.png', width: size, height: size, fit: BoxFit.cover);
    return ClipOval(
      child: on ? image : Opacity(opacity: 0.7, child: ColorFiltered(colorFilter: _greyscale, child: image)),
    );
  }
}
