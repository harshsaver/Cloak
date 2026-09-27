import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/provider.dart';
import '../state/app_state.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';
import 'workspace_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, AiProvider provider) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkspaceScreen(provider: provider)));
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact(context)) return _PhoneHome(onOpen: (p) => _open(context, p));
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 2 : 1;
            final pad = columns == 1 ? 18.0 : 28.0;
            const gap = 16.0;
            final innerW = constraints.maxWidth.clamp(0.0, 1120.0) - pad * 2;
            final cardW = columns == 1 ? innerW : (innerW - gap) / 2;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset('assets/brand/logo.png', width: 60, height: 60, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Cloak', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Big ideas. Fewer personal details. Choose a provider to start a conversation.',
                                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Settings',
                              icon: const Icon(Icons.settings_rounded),
                              onPressed: () => showSettingsSheet(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final provider in AiProvider.all)
                              SizedBox(
                                width: cardW,
                                child: _ProviderCard(provider: provider, onTap: () => _open(context, provider)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Phone home: large title, a short Cloak intro, and an iOS-style grouped list.
class _PhoneHome extends StatelessWidget {
  final ValueChanged<AiProvider> onOpen;
  const _PhoneHome({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final app = context.watch<AppState>();
    final group = CloakColors.surface(brightness);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(children: [
              const SizedBox(width: 4),
              const Expanded(
                child: Text('Cloak', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => showSettingsSheet(context),
              ),
            ]),
            const SizedBox(height: 14),

            // Intro card: what Cloak does, with the mascot.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: group, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/brand/app_icon_1024.png', width: 64, height: 64, fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Share less of yourself',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Cloak gives your personal details a stand-in before they reach the AI.',
                      style: TextStyle(fontSize: 14, height: 1.3, color: scheme.onSurfaceVariant),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 26),

            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text('CHOOSE A PROVIDER',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: scheme.onSurfaceVariant)),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: group, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                for (var i = 0; i < AiProvider.all.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 70, color: scheme.outlineVariant.withValues(alpha: 0.35)),
                  _ProviderRow(provider: AiProvider.all[i], app: app, onTap: () => onOpen(AiProvider.all[i])),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'Bring your own API key. Add or change keys in Settings.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final AiProvider provider;
  final AppState app;
  final VoidCallback onTap;
  const _ProviderRow({required this.provider, required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasKey = app.hasKey(provider);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [provider.tint, Color.lerp(provider.tint, Colors.black, 0.18)!],
              ),
            ),
            child: Icon(provider.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(provider.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
                ),
                if (hasKey)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Ready',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(provider.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        ]),
      ),
    );
  }
}

class _ProviderCard extends StatefulWidget {
  final AiProvider provider;
  final VoidCallback onTap;
  const _ProviderCard({required this.provider, required this.onTap});

  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = context.watch<AppState>();
    final hasKey = app.hasKey(widget.provider);
    final status = hasKey ? 'Ready' : (app.keyError(widget.provider) != null ? 'Retry' : 'Add key');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CloakColors.surface(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? widget.provider.tint.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [widget.provider.tint, Color.lerp(widget.provider.tint, Colors.black, 0.18)!],
                      ),
                    ),
                    child: Icon(widget.provider.icon, color: Colors.white, size: 23),
                  ),
                  const Spacer(),
                  if (app.hasLoadedKey(widget.provider))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: (hasKey ? Colors.green : scheme.onSurface).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasKey ? Colors.green : scheme.onSurfaceVariant)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.provider.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(widget.provider.tagline,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Open chat',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
