import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/conversation_portrait.dart';
import '../models/provider.dart';
import '../services/cloak_review.dart';
import '../state/chat_view_model.dart';
import '../state/conversation_store.dart';
import 'alt_id_panel.dart';
import 'cloak_review_sheet.dart';
import 'message_bubble.dart';
import 'model_picker.dart';
import 'network_panel.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

class ChatScreen extends StatefulWidget {
  final AiProvider provider;
  final String apiKey;
  final String conversationId;
  const ChatScreen({super.key, required this.provider, required this.apiKey, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatViewModel _vm;
  late final TextEditingController _composer;
  final ScrollController _scroll = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _vm = ChatViewModel(
      provider: widget.provider,
      apiKey: widget.apiKey,
      conversationId: widget.conversationId,
      store: context.read<ConversationStore>(),
    );
    _composer = TextEditingController(text: _vm.input);
    _vm.addListener(_onVmChanged);
    _composerFocus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _vm.loadModels());
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiKey != widget.apiKey) {
      _vm.updateApiKey(widget.apiKey);
      _vm.loadModels();
    }
  }

  void _onVmChanged() {
    if (_follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _composer.dispose();
    _scroll.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _send({CloakReview? review}) {
    _vm.send(review: review);
    _composer.clear();
    _follow = true;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConversationStore>();
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Container(
          color: CloakColors.surface(Theme.of(context).brightness),
          child: Column(
            children: [
              _header(store),
              if (_vm.errorText != null) _errorBanner(),
              Expanded(child: _vm.messages.isEmpty ? const SizedBox.shrink() : _transcript(store)),
              _inputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _header(ConversationStore store) {
    final scheme = Theme.of(context).colorScheme;
    final title = store.conversation(widget.conversationId)?.title ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CloakColors.chrome(Theme.of(context).brightness),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          PortraitAvatar(number: portraitNumber(widget.conversationId), size: 30),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title.isEmpty ? 'New message' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 210, child: ModelPickerButton(vm: _vm)),
          const SizedBox(width: 8),
          _toolButton(Icons.person_outline_rounded, 'Alt ID', _openAltId),
          _toolButton(Icons.lan_outlined, 'Network', _openNetwork),
          _toolButton(Icons.help_outline_rounded, 'Provider docs',
              () => launchUrl(Uri.parse(widget.provider.docsUrl), mode: LaunchMode.externalApplication)),
          _toolButton(Icons.settings_outlined, 'Settings', () => showSettingsSheet(context)),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  Widget _errorBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.error.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(_vm.errorText!, style: const TextStyle(fontSize: 12))),
          if (_vm.canRetry)
            TextButton(onPressed: () => _vm.retry(), child: const Text('Retry')),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => setState(() => _vm.errorText = null),
          ),
        ],
      ),
    );
  }

  Widget _transcript(ConversationStore store) {
    final conversation = store.conversation(widget.conversationId);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification && notification.direction == ScrollDirection.forward) {
          if (_follow) setState(() => _follow = false);
        }
        if (notification is ScrollEndNotification && _scroll.hasClients) {
          final atBottom = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 40;
          if (atBottom && !_follow) setState(() => _follow = true);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        itemCount: _vm.messages.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final created = conversation?.createdAt;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  created == null ? '' : 'Started ${_dateLabel(created)}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          final message = _vm.messages[index - 1];
          final isLast = index - 1 == _vm.messages.length - 1;
          return MessageBubble(
            message: message,
            isLive: _vm.isStreaming && message.role.name == 'assistant' && isLast,
            isSearching: _vm.isSearching,
          );
        },
      ),
    );
  }

  String _dateLabel(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _inputBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      color: CloakColors.surface(Theme.of(context).brightness),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: CloakColors.canvas(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _composerFocus.hasFocus
                          ? CloakColors.accent.withValues(alpha: 0.45)
                          : scheme.outlineVariant,
                    ),
                  ),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        if (_vm.canSend) _send();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _composer,
                      focusNode: _composerFocus,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      onChanged: (v) => _vm.input = v,
                      decoration: InputDecoration.collapsed(hintText: 'Message ${widget.provider.name}'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(),
            ],
          ),
          const SizedBox(height: 8),
          _optionsRow(),
        ],
      ),
    );
  }

  Widget _sendButton() {
    if (_vm.isStreaming) {
      return _circleButton(Icons.stop_rounded, CloakColors.accent, () => _vm.stop());
    }
    final enabled = _vm.canSend;
    return _circleButton(
      Icons.arrow_upward_rounded,
      enabled ? CloakColors.accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      enabled ? _send : null,
      iconColor: enabled ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  Widget _circleButton(IconData icon, Color bg, VoidCallback? onTap, {Color iconColor = Colors.white}) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: iconColor)),
      ),
    );
  }

  Widget _optionsRow() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ChatOptionToggle(
          label: 'Web search',
          icon: Icons.public_rounded,
          value: _vm.groundWithSearch,
          tooltip: 'Ground this reply with TinyFish web search.',
          onChanged: (v) => _vm.groundWithSearch = v,
        ),
        const SizedBox(width: 7),
        ChatOptionToggle(
          label: 'Cloak',
          icon: Icons.visibility_off_rounded,
          value: _vm.cloak,
          tooltip: 'Replace configured and recognized personal values before sending.',
          onChanged: (v) => _vm.cloak = v,
        ),
        if (_vm.cloak) ...[
          const SizedBox(width: 7),
          TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: _vm.canSend ? _reviewCloak : null,
            icon: const Icon(Icons.visibility_rounded, size: 14),
            label: const Text('Review Cloak', style: TextStyle(fontSize: 12)),
          ),
        ],
        const Spacer(),
        if (_vm.messages.isNotEmpty) ...[
          TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: _vm.canRetry ? () => _vm.retry() : null,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
          IconButton(
            tooltip: _follow ? 'Following' : 'Jump to latest',
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            color: _follow ? CloakColors.accent : scheme.onSurfaceVariant,
            icon: const Icon(Icons.vertical_align_bottom_rounded),
            onPressed: () {
              setState(() => _follow = true);
              if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
            },
          ),
        ] else if (_vm.selectedModel.isEmpty)
          Text('Choose a model above', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))
        else
          Text('Return to send · ⇧Return for a new line', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  // MARK: - Panels & sheets

  void _openAltId() {
    showRightPanel(
      context,
      title: 'Alt ID',
      builder: (context) => AltIdPanel(
        cloakEnabled: _vm.cloak,
        onCloakChanged: (v) => _vm.cloak = v,
      ),
    );
  }

  void _openNetwork() {
    showRightPanel(context, title: 'Network', builder: (context) => const NetworkPanel());
  }

  Future<void> _reviewCloak() async {
    try {
      final review = await _vm.makeCloakReview();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => CloakReviewSheet(
          review: review,
          usesSearch: _vm.groundWithSearch,
          onSend: (r) => _send(review: r),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _vm.errorText = error.toString());
    }
  }
}

/// Slides a card-style panel in from the trailing edge, sized for desktop and phone.
Future<void> showRightPanel(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Listenable? listenable,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) {
      final width = MediaQuery.of(context).size.width;
      final panelWidth = width < 520 ? width : (width * 0.42).clamp(360.0, 460.0);
      final scheme = Theme.of(context).colorScheme;
      Widget content = Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: Builder(builder: builder)),
        ],
      );
      if (listenable != null) {
        content = AnimatedBuilder(animation: listenable, builder: (context, _) => content);
      }
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: scheme.surface,
          elevation: 16,
          child: SizedBox(width: panelWidth, height: double.infinity, child: SafeArea(child: content)),
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}
