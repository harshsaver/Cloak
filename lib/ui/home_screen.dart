import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/provider.dart';
import '../state/app_state.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'workspace_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, AiProvider provider) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkspaceScreen(provider: provider)));
  }

  @override
  Widget build(BuildContext context) {
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
