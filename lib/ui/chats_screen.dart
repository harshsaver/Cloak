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

/// The app's home: every conversation from every provider in one list.
/// Providers are a per-chat setting (in the model picker), not a destination.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String? _selectedId; // wide layout only

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      for (final p in AiProvider.all) {
        await app.loadKeyIfNeeded(p);
      }
      if (!mounted) return;
      final recent = context.read<ConversationStore>().all().where((c) => c.messages.isNotEmpty);
      if (recent.isNotEmpty) setState(() => _selectedId ??= recent.first.id);
    });
  }

  /// New chats use the provider (and model) you used most recently.
  AiProvider _defaultProvider(AppState app, ConversationStore store) {
    for (final c in store.all()) {
      final p = AiProvider.byId(c.providerId);
      if (p != null && app.hasKey(p) && c.messages.isNotEmpty) return p;
    }
    return AiProvider.all.firstWhere(app.hasKey, orElse: () => AiProvider.orcarouter);
  }

  String? _newChat() {
    final app = context.read<AppState>();
    final store = context.read<ConversationStore>();
    if (!AiProvider.all.any(app.hasKey)) {
      showSettingsSheet(context);
      return null;
    }
    final provider = _defaultProvider(app, store);
    final lastModel = store.list(provider.id).map((c) => c.model).firstWhere((m) => m.isNotEmpty, orElse: () => '');
    return store.newOrReuseEmpty(providerId: provider.id, model: lastModel).id;
  }

  void _openPhone(String id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(body: SafeArea(child: ChatHost(conversationId: id, showBack: true))),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    context.watch<ConversationStore>();
    final keysLoaded = AiProvider.all.every(app.hasLoadedKey);
    final needsKey = keysLoaded && !AiProvider.all.any(app.hasKey);

    if (isCompact(context)) {
      final bg = CloakColors.surface(Theme.of(context).brightness);
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          scrolledUnderElevation: 0,
          leadingWidth: 60,
          leading: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Center(child: CloakMascot(on: true, size: 32)),
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
        body: Column(children: [
          if (needsKey) const _AddKeyCard(),
          Expanded(
            child: ConversationSidebar(
              selectedId: null,
              onSelect: _openPhone,
              onNewChat: () {
                final id = _newChat();
                if (id != null) _openPhone(id);
              },
              showFooter: false,
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          SizedBox(
            width: 300,
            child: Column(children: [
              if (needsKey) const _AddKeyCard(),
              Expanded(
                child: ConversationSidebar(
                  selectedId: _selectedId,
                  onSelect: (id) => setState(() => _selectedId = id),
                  onNewChat: () {
                    final id = _newChat();
                    if (id != null) setState(() => _selectedId = id);
                  },
                ),
              ),
            ]),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedId == null
                ? const _Placeholder()
                : ChatHost(key: ValueKey(_selectedId), conversationId: _selectedId!),
          ),
        ]),
      ),
    );
  }
}

/// Resolves a conversation's provider and API key, then shows the chat.
class ChatHost extends StatelessWidget {
  final String conversationId;
  final bool showBack;
  const ChatHost({super.key, required this.conversationId, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConversationStore>();
    final app = context.watch<AppState>();
    final conversation = store.conversation(conversationId);
    if (conversation == null) return const Center(child: Text('This chat was deleted.'));
    final provider = AiProvider.byId(conversation.providerId) ?? AiProvider.orcarouter;

    if (!app.hasLoadedKey(provider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => app.loadKeyIfNeeded(provider));
      return const Center(child: CircularProgressIndicator());
    }
    final key = app.apiKey(provider);
    if (key == null) return _MissingKey(provider: provider, showBack: showBack);

    return ChatScreen(
      key: ValueKey('${conversation.id}-${provider.id}'),
      provider: provider,
      apiKey: key,
      conversationId: conversation.id,
      showBack: showBack,
      onProviderChange: (p) {
        conversation.providerId = p.id;
        conversation.model = '';
        store.save(conversation);
      },
    );
  }
}

class _AddKeyCard extends StatelessWidget {
  const _AddKeyCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CloakColors.canvas(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CloakMascot(on: true, size: 44),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Add an API key to start chatting',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          'Cloak works with OrcaRouter, OpenRouter, Featherless and Concurred. Bring your own key — '
          'your personal details get a stand-in before they reach the AI.',
          style: TextStyle(fontSize: 14, height: 1.35, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => showSettingsSheet(context),
          icon: const Icon(Icons.key_rounded, size: 18),
          label: const Text('Add a key'),
        ),
      ]),
    );
  }
}

class _MissingKey extends StatelessWidget {
  final AiProvider provider;
  final bool showBack;
  const _MissingKey({required this.provider, required this.showBack});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      if (showBack) const Align(alignment: Alignment.centerLeft, child: BackButton()),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ProviderGlyph(provider: provider, size: 56),
              const SizedBox(height: 16),
              Text('Add your ${provider.name} key', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('This chat uses ${provider.name}. Add its API key in Settings to continue.',
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => showSettingsSheet(context),
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Open Settings'),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CloakMascot(on: true, size: 72),
        const SizedBox(height: 12),
        Text('Pick a chat or start a new one',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
