import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  /// Show a back button in the header (true when pushed as a full page on phones).
  final bool showBack;
  const ChatScreen({
    super.key,
    required this.provider,
    required this.apiKey,
    required this.conversationId,
    this.showBack = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatViewModel _vm;
  late final TextEditingController _composer;
  final ScrollController _scroll = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  bool _follow = true;
  double _lastInset = 0;

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
      if (!mounted) return;
      setState(() {});
      if (_composerFocus.hasFocus) {
        // Keep the newest messages visible once the keyboard has slid up.
        _follow = true;
        Future.delayed(const Duration(milliseconds: 650), () {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          }
        });
      }
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
    // While the keyboard animates in/out the inset changes every frame; stay
    // pinned to the newest message so it never hides behind the composer.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _lastInset) {
      _lastInset = inset;
      if (_follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    }
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Container(
          color: CloakColors.surface(Theme.of(context).brightness),
          child: Column(
            children: [
              _header(store),
              if (_vm.errorText != null) _errorBanner(),
              Expanded(child: _vm.messages.isEmpty ? _emptyState() : _transcript(store)),
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
    final compact = isCompact(context);

    if (compact) return _phoneHeader(title, scheme);

    final avatar = PortraitAvatar(number: portraitNumber(widget.conversationId), size: 30);
    final titleText = Expanded(
      child: Text(
        title.isEmpty ? 'New message' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

    final Widget bar = Row(children: [
            if (widget.showBack) _backButton(),
            avatar,
            const SizedBox(width: 9),
            titleText,
            const SizedBox(width: 10),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: ModelPickerButton(vm: _vm)),
            const SizedBox(width: 4),
            ..._inlineTools(),
          ]);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: CloakColors.chrome(Theme.of(context).brightness),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: bar,
    );
  }

  /// iMessage-style header: back · (avatar over title, model line) · more.
  Widget _phoneHeader(String title, ColorScheme scheme) {
    final model = _vm.selectedModel;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
      decoration: BoxDecoration(
        color: CloakColors.chrome(Theme.of(context).brightness),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: widget.showBack ? _backButton() : null),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _vm.isStreaming ? null : () => showModelPicker(context, _vm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PortraitAvatar(number: portraitNumber(widget.conversationId), size: 40),
                  const SizedBox(height: 5),
                  Text(
                    title.isEmpty ? 'New message' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(
                        model.isEmpty ? 'Choose a model' : model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: model.isEmpty ? CloakColors.accent : scheme.onSurfaceVariant),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, size: 15, color: scheme.onSurfaceVariant),
                  ]),
                ]),
              ),
            ),
          ),
          SizedBox(width: 48, child: _toolsMenu()),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PortraitAvatar(number: portraitNumber(widget.conversationId), size: 72),
          const SizedBox(height: 14),
          const Text('Start a conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _vm.cloak
                ? 'Cloak is on — your details get a stand-in before they reach ${widget.provider.name}.'
                : 'Ask anything. Turn on Cloak to give your personal details a stand-in first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.35, color: scheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }

  Widget _backButton() => IconButton(
        tooltip: 'Back',
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).maybePop(),
      );

  Widget _toolButton(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  List<Widget> _inlineTools() => [
        _toolButton(Icons.person_outline_rounded, 'Alt ID', _openAltId),
        _toolButton(Icons.lan_outlined, 'Network', _openNetwork),
        _toolButton(Icons.help_outline_rounded, 'Provider docs',
            () => launchUrl(Uri.parse(widget.provider.docsUrl), mode: LaunchMode.externalApplication)),
        _toolButton(Icons.settings_outlined, 'Settings', () => showSettingsSheet(context)),
      ];

  Widget _toolsMenu() => PopupMenuButton<String>(
        tooltip: 'More',
        icon: const Icon(Icons.more_horiz_rounded, size: 22),
        onSelected: (v) {
          switch (v) {
            case 'altid':
              _openAltId();
            case 'network':
              _openNetwork();
            case 'docs':
              launchUrl(Uri.parse(widget.provider.docsUrl), mode: LaunchMode.externalApplication);
            case 'settings':
              showSettingsSheet(context);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
              value: 'altid',
              child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_outline_rounded), title: Text('Alt ID'))),
          PopupMenuItem(
              value: 'network',
              child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.lan_outlined), title: Text('Network'))),
          PopupMenuItem(
              value: 'docs',
              child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.help_outline_rounded), title: Text('Provider docs'))),
          PopupMenuItem(
              value: 'settings',
              child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.settings_outlined), title: Text('Settings'))),
        ],
      );

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
        padding: isCompact(context)
            ? const EdgeInsets.fromLTRB(12, 4, 12, 12)
            : const EdgeInsets.fromLTRB(20, 10, 20, 10),
        itemCount: _vm.messages.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final created = conversation?.createdAt;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  created == null ? '' : _dateLabel(created),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    return sameDay ? 'Today ${DateFormat.jm().format(date)}' : DateFormat('EEE, d MMM · h:mm a').format(date);
  }

  Widget _inputBar() {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final compact = isCompact(context);

    Widget field = TextField(
      controller: _composer,
      focusNode: _composerFocus,
      minLines: 1,
      maxLines: compact ? 5 : 6,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: compact ? 16 : 14),
      onChanged: (v) => _vm.input = v,
      decoration: InputDecoration.collapsed(hintText: compact ? 'Message' : 'Message ${widget.provider.name}'),
    );
    if (!compact) {
      // Desktop: Return sends, Shift+Return adds a line. Phones use the send button.
      field = Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              !HardwareKeyboard.instance.isShiftPressed) {
            if (_vm.canSend) _send();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: field,
      );
    }

    final fieldBox = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 14, vertical: compact ? 9 : 6),
      decoration: BoxDecoration(
        color: CloakColors.canvas(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _composerFocus.hasFocus ? CloakColors.accent.withValues(alpha: 0.45) : scheme.outlineVariant,
        ),
      ),
      child: field,
    );

    if (compact) {
      final chips = _activeChips();
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: CloakColors.chrome(brightness),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: 32,
                child: ListView(scrollDirection: Axis.horizontal, children: chips),
              ),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _circleButton(
              Icons.add_rounded,
              scheme.onSurface.withValues(alpha: 0.08),
              _openOptions,
              iconColor: scheme.onSurface,
              size: 38,
              iconSize: 24,
            ),
            const SizedBox(width: 8),
            Expanded(child: fieldBox),
            const SizedBox(width: 8),
            _sendButton(size: 38),
          ]),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      color: CloakColors.surface(brightness),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: fieldBox),
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

  /// Phone: small chips above the composer that show (and toggle off) active modes.
  List<Widget> _activeChips() {
    final chips = <Widget>[];
    Widget chip(IconData icon, String label, {VoidCallback? onTap, VoidCallback? onClose, bool accent = true}) {
      final color = accent ? CloakColors.accent : Theme.of(context).colorScheme.onSurfaceVariant;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: color.withValues(alpha: 0.12),
          shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.3))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 0, onClose == null ? 12 : 4, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
                if (onClose != null)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 15, color: color),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
    }

    if (_vm.selectedModel.isEmpty) {
      chips.add(chip(Icons.tune_rounded, 'Choose a model', onTap: () => showModelPicker(context, _vm)));
    }
    if (_vm.cloak) {
      chips.add(chip(Icons.visibility_off_rounded, 'Cloak on', onClose: () => _vm.cloak = false));
      if (_vm.canSend) chips.add(chip(Icons.visibility_rounded, 'Review', onTap: _reviewCloak));
    }
    if (_vm.groundWithSearch) {
      chips.add(chip(Icons.public_rounded, 'Web search', onClose: () => _vm.groundWithSearch = false));
    }
    if (!_follow && _vm.messages.isNotEmpty) {
      chips.add(chip(Icons.vertical_align_bottom_rounded, 'Latest', accent: false, onTap: () {
        setState(() => _follow = true);
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }));
    }
    return chips;
  }

  /// Phone: every composer option in one sheet instead of a crowded toolbar.
  Future<void> _openOptions() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => AnimatedBuilder(
        animation: _vm,
        builder: (sheet, _) {
          void then(VoidCallback action) {
            Navigator.pop(sheet);
            action();
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_rounded),
                  title: const Text('Cloak'),
                  subtitle: const Text('Swap your details for your Alt ID before sending'),
                  value: _vm.cloak,
                  onChanged: (v) => _vm.cloak = v,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.public_rounded),
                  title: const Text('Web search'),
                  subtitle: const Text('Ground the reply with live results'),
                  value: _vm.groundWithSearch,
                  onChanged: (v) => _vm.groundWithSearch = v,
                ),
                ListTile(
                  enabled: _vm.cloak && _vm.canSend,
                  leading: const Icon(Icons.visibility_rounded),
                  title: const Text('Review Cloak'),
                  subtitle: const Text('Preview exactly what will be sent'),
                  onTap: () => then(_reviewCloak),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  enabled: !_vm.isStreaming,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Model'),
                  subtitle: Text(_vm.selectedModel.isEmpty ? 'Choose a model' : _vm.selectedModel,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => then(() => showModelPicker(context, _vm)),
                ),
                ListTile(
                  enabled: _vm.canRetry,
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Retry last reply'),
                  onTap: () => then(_vm.retry),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Alt ID'),
                  onTap: () => then(_openAltId),
                ),
                ListTile(
                  leading: const Icon(Icons.lan_outlined),
                  title: const Text('Network'),
                  onTap: () => then(_openNetwork),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _sendButton({double size = 34}) {
    if (_vm.isStreaming) {
      return _circleButton(Icons.stop_rounded, CloakColors.accent, () => _vm.stop(), size: size);
    }
    final enabled = _vm.canSend;
    return _circleButton(
      Icons.arrow_upward_rounded,
      enabled ? CloakColors.accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      enabled ? _send : null,
      iconColor: enabled ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
      size: size,
    );
  }

  Widget _circleButton(IconData icon, Color bg, VoidCallback? onTap,
      {Color iconColor = Colors.white, double size = 34, double? iconSize}) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: iconSize ?? size * 0.53, color: iconColor)),
      ),
    );
  }

  Widget _optionsRow() {
    final scheme = Theme.of(context).colorScheme;
    // Wrap so a narrow phone flows controls to a second line instead of overflowing.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChatOptionToggle(
          label: 'Web search',
          icon: Icons.public_rounded,
          value: _vm.groundWithSearch,
          tooltip: 'Ground this reply with TinyFish web search.',
          onChanged: (v) => _vm.groundWithSearch = v,
        ),
        ChatOptionToggle(
          label: 'Cloak',
          icon: Icons.visibility_off_rounded,
          value: _vm.cloak,
          tooltip: 'Replace configured and recognized personal values before sending.',
          onChanged: (v) => _vm.cloak = v,
        ),
        if (_vm.cloak)
          TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: _vm.canSend ? _reviewCloak : null,
            icon: const Icon(Icons.visibility_rounded, size: 14),
            label: const Text('Review Cloak', style: TextStyle(fontSize: 12)),
          ),
        if (_vm.messages.isNotEmpty) ...[
          TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: _vm.canRetry ? () => _vm.retry() : null,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: _follow ? CloakColors.accent : scheme.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() => _follow = true);
              if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
            },
            icon: const Icon(Icons.vertical_align_bottom_rounded, size: 14),
            label: Text(_follow ? 'Following' : 'Latest', style: const TextStyle(fontSize: 12)),
          ),
        ] else if (_vm.selectedModel.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text('Choose a model above', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
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
  if (isCompact(context)) {
    // Phones: a regular full-screen page with a back button.
    return Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (page) => Scaffold(
        appBar: AppBar(title: Text(title), scrolledUnderElevation: 0),
        body: SafeArea(top: false, child: Builder(builder: builder)),
      ),
    ));
  }
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
