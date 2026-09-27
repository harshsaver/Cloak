import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat_models.dart';
import '../models/conversation_portrait.dart';
import '../models/provider.dart';
import '../state/conversation_store.dart';
import 'markdown_render.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

class ConversationSidebar extends StatefulWidget {
  final AiProvider provider;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<AiProvider> onSwitchProvider;
  final VoidCallback onAllProviders;

  /// The provider switcher + settings footer. Phones move these into the app bar.
  final bool showFooter;
  const ConversationSidebar({
    super.key,
    required this.provider,
    required this.selectedId,
    required this.onSelect,
    required this.onSwitchProvider,
    required this.onAllProviders,
    this.showFooter = true,
  });

  @override
  State<ConversationSidebar> createState() => _ConversationSidebarState();
}

class _ConversationSidebarState extends State<ConversationSidebar> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String get _currentModel {
    final store = context.read<ConversationStore>();
    final id = widget.selectedId;
    if (id != null) return store.conversation(id)?.model ?? '';
    return '';
  }

  void _newChat() {
    final store = context.read<ConversationStore>();
    _query.clear();
    final conversation = store.newOrReuseEmpty(providerId: widget.provider.id, model: _currentModel);
    widget.onSelect(conversation.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<ConversationStore>();
    final query = _query.text.trim().toLowerCase();
    final items = store
        .list(widget.provider.id)
        .where((c) =>
            query.isEmpty || c.title.toLowerCase().contains(query) || c.model.toLowerCase().contains(query))
        .toList();

    final compact = isCompact(context);
    return Container(
      color: compact ? Colors.transparent : scheme.surface.withValues(alpha: 0.6),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 20 : 18, compact ? 4 : 14, 10, 8),
            child: Row(children: [
              Text('Messages', style: TextStyle(fontSize: compact ? 32 : 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'New chat',
                icon: Icon(Icons.edit_square, size: compact ? 24 : 20, color: CloakColors.accent),
                onPressed: store.isReadBlocked ? null : _newChat,
              ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 14, 0, compact ? 16 : 14, 10),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: scheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 16),
                        onPressed: () => setState(() => _query.clear()),
                      ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(query.isEmpty ? Icons.forum_outlined : Icons.search_off_rounded,
                            size: 26, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(query.isEmpty ? 'Your conversations start here' : 'No matching conversations',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final conversation = items[i];
                      return _ConversationRow(
                        conversation: conversation,
                        draft: store.draft(conversation.id),
                        selected: conversation.id == widget.selectedId,
                        onTap: () => widget.onSelect(conversation.id),
                        onRename: () => _rename(conversation),
                        onDelete: () => _delete(conversation),
                      );
                    },
                  ),
          ),
          if (widget.showFooter) ...[
            const Divider(height: 1),
            _footer(scheme),
          ],
        ],
      ),
    );
  }

  Widget _footer(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        ProviderSwitcher(
          provider: widget.provider,
          onSwitch: widget.onSwitchProvider,
          onAllProviders: widget.onAllProviders,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_rounded, size: 18),
          onPressed: () => showSettingsSheet(context),
        ),
      ]),
    );
  }

  Future<void> _rename(Conversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      context.read<ConversationStore>().rename(conversation.id, result);
    }
  }

  Future<void> _delete(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: const Text('This removes the conversation from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete chat'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final store = context.read<ConversationStore>();
      store.delete(conversation.id);
      if (widget.selectedId == conversation.id) {
        final next = store.list(widget.provider.id);
        if (next.isNotEmpty) widget.onSelect(next.first.id);
      }
    }
  }
}

class _ConversationRow extends StatelessWidget {
  final Conversation conversation;
  final String draft;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ConversationRow({
    required this.conversation,
    required this.draft,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  String get _preview {
    if (draft.isNotEmpty) return 'Draft: $draft';
    final latest = conversation.messages.lastWhere(
      (m) => m.text.isNotEmpty,
      orElse: () => ChatMessage(role: Role.assistant, text: ''),
    );
    if (latest.text.isEmpty) return 'Start a conversation';
    return plainMessageText(latest.text.length > 180 ? latest.text.substring(0, 180) : latest.text)
        .split(RegExp(r'\s+'))
        .join(' ')
        .trim();
  }

  String get _dateLabel {
    final date = conversation.updatedAt;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
    if (isToday) return DateFormat.jm().format(date);
    if (isYesterday) return 'Yesterday';
    return DateFormat.MMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = isCompact(context);
    final avatar = compact ? 52.0 : 38.0;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortraitAvatar(number: portraitNumber(conversation.id), size: avatar),
        SizedBox(width: compact ? 12 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: compact ? 2 : 0),
              Row(children: [
                Expanded(
                  child: Text(
                    conversation.title.isEmpty ? 'New message' : conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 16.5 : 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Text(_dateLabel,
                    style: TextStyle(fontSize: compact ? 13.5 : 10, color: scheme.onSurfaceVariant)),
                if (compact) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ],
              ]),
              SizedBox(height: compact ? 3 : 3),
              Text(
                _preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 14.5 : 12,
                  height: 1.3,
                  color: draft.isEmpty ? scheme.onSurfaceVariant : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (compact) {
      // Phone: edge-to-edge row, inset divider under the text, no selection tint.
      return InkWell(
        onTap: onTap,
        onLongPress: () => _showSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
          child: Column(children: [
            content,
            const SizedBox(height: 10),
            Divider(height: 1, indent: avatar + 12, color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ]),
        ),
      );
    }

    return GestureDetector(
      onSecondaryTapDown: (details) => _showMenu(context, details.globalPosition),
      onLongPress: () => _showMenu(context, null),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: content),
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              conversation.title.isEmpty ? 'New message' : conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
            title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (value == 'rename') onRename();
    if (value == 'delete') onDelete();
  }

  void _showMenu(BuildContext context, Offset? position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final origin = position ?? overlay.localToGlobal(overlay.size.center(Offset.zero));
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(origin.dx, origin.dy, origin.dx, origin.dy),
      items: const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (value == 'rename') onRename();
    if (value == 'delete') onDelete();
  }
}
