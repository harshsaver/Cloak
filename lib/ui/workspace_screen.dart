import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/provider.dart';
import '../state/app_state.dart';
import '../state/conversation_store.dart';
import 'chat_screen.dart';
import 'conversation_sidebar.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

class WorkspaceScreen extends StatefulWidget {
  final AiProvider provider;
  const WorkspaceScreen({super.key, required this.provider});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadKeyIfNeeded(widget.provider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelection());
  }

  void _ensureSelection() {
    final store = context.read<ConversationStore>();
    final existing = store.list(widget.provider.id);
    setState(() {
      _selectedId = existing.isNotEmpty
          ? existing.first.id
          : store.newOrReuseEmpty(providerId: widget.provider.id, model: '').id;
    });
  }

  void _switchProvider(AiProvider option) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => WorkspaceScreen(provider: option)));
  }

  void _selectNarrow(String id) {
    setState(() => _selectedId = id);
    final key = context.read<AppState>().apiKey(widget.provider);
    if (key == null) return;
    // ChatScreen renders its own responsive header (with a back button), so no AppBar.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        body: SafeArea(
          child: ChatScreen(
            key: ValueKey(id),
            provider: widget.provider,
            apiKey: key,
            conversationId: id,
            showBack: true,
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final store = context.watch<ConversationStore>();
    final wide = MediaQuery.of(context).size.width >= 820;

    void allProviders() => Navigator.of(context).popUntil((r) => r.isFirst);

    final sidebar = ConversationSidebar(
      provider: widget.provider,
      selectedId: _selectedId,
      onSelect: wide ? (id) => setState(() => _selectedId = id) : _selectNarrow,
      onSwitchProvider: _switchProvider,
      onAllProviders: allProviders,
      showFooter: wide,
    );

    final errorBar = (store.errorText != null && store.isReadBlocked) ? _storeError(store) : null;

    if (!wide) {
      final bg = CloakColors.surface(Theme.of(context).brightness);
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Providers',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: allProviders,
          ),
          title: ProviderSwitcher(
            provider: widget.provider,
            onSwitch: _switchProvider,
            onAllProviders: allProviders,
          ),
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => showSettingsSheet(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(children: [if (errorBar != null) errorBar, Expanded(child: sidebar)]),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (errorBar != null) errorBar,
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 288, child: sidebar),
                  const VerticalDivider(width: 1),
                  Expanded(child: _detail(app)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(AppState app) {
    if (!app.hasLoadedKey(widget.provider)) {
      return Center(child: Text('Opening ${widget.provider.name}…'));
    }
    final key = app.apiKey(widget.provider);
    if (key == null) return _MissingKey(provider: widget.provider);
    final id = _selectedId;
    if (id == null) return const SizedBox.shrink();
    return ChatScreen(key: ValueKey(id), provider: widget.provider, apiKey: key, conversationId: id);
  }

  Widget _storeError(ConversationStore store) {
    return Container(
      width: double.infinity,
      color: Colors.orange.withValues(alpha: 0.15),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded),
          const SizedBox(width: 8),
          Expanded(child: Text(store.errorText!, style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: () => store.retryPersistence(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _MissingKey extends StatelessWidget {
  final AiProvider provider;
  const _MissingKey({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_rounded, size: 34, color: provider.tint),
            const SizedBox(height: 16),
            Text('Add your ${provider.name} API key',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Cloak needs an API key to talk to ${provider.name}. Add it in Settings.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => showSettingsSheet(context),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
