import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_models.dart';
import 'markdown_render.dart';
import 'theme.dart';
import 'widgets.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isLive;
  final bool isSearching;
  const MessageBubble({super.key, required this.message, this.isLive = false, this.isSearching = false});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  static const _tail = 8000;
  int _visibleLimit = 8000;
  bool _copied = false;

  bool get _isUser => widget.message.role == Role.user;

  String get _displayText {
    final text = widget.message.text;
    if (widget.isLive && text.length > _tail) return '…${text.substring(text.length - _tail)}';
    return widget.isLive ? text : (text.length > _visibleLimit ? text.substring(0, _visibleLimit) : text);
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _showActions() async {
    final text = widget.message.text;
    if (text.isEmpty || widget.isLive) return;
    HapticFeedback.selectionClick();
    final blocks = _isUser ? const <(String, String?)>[] : codeBlocks(text);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        void copy(String value, String label) {
          Clipboard.setData(ClipboardData(text: value));
          Navigator.pop(sheet);
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(SnackBar(content: Text(label), duration: const Duration(milliseconds: 1400)));
        }

        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => copy(_isUser ? text : plainMessageText(text), 'Copied'),
            ),
            if (!_isUser)
              ListTile(
                leading: const Icon(Icons.data_object_rounded),
                title: const Text('Copy as Markdown'),
                onTap: () => copy(text, 'Copied Markdown'),
              ),
            for (var i = 0; i < blocks.length; i++)
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: Text('Copy code block ${i + 1}${blocks[i].$2 != null ? ' · ${blocks[i].$2}' : ''}'),
                onTap: () => copy(blocks[i].$1, 'Copied code'),
              ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final incoming = CloakColors.incomingBubble(brightness);
    final text = widget.message.text;
    final compact = isCompact(context);
    final fontSize = compact ? 16.0 : 15.0;
    final maxWidth = compact ? MediaQuery.sizeOf(context).width * (_isUser ? 0.78 : 0.86) : 640.0;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(19),
      topRight: const Radius.circular(19),
      bottomLeft: Radius.circular(_isUser ? 19 : 5),
      bottomRight: Radius.circular(_isUser ? 5 : 19),
    );

    Widget bubble;
    if (text.isEmpty && !_isUser) {
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: incoming, borderRadius: radius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TypingIndicator(),
            if (widget.isSearching) ...[
              const SizedBox(width: 10),
              Text('Searching the web',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      );
    } else {
      final plainStyle = TextStyle(
        fontSize: fontSize,
        height: 1.32,
        color: _isUser ? Colors.white : scheme.onSurface,
      );
      bubble = Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 15, vertical: _isUser ? 9 : 11),
        decoration: BoxDecoration(color: _isUser ? CloakColors.bubbleBlue : incoming, borderRadius: radius),
        child: (_isUser || widget.isLive)
            // Phones use long-press for actions, so text isn't selectable there.
            ? (compact ? Text(_displayText, style: plainStyle) : SelectableText(_displayText, style: plainStyle))
            : MarkdownText(_displayText, color: scheme.onSurface, selectable: !compact, fontSize: fontSize),
      );
      if (compact) bubble = GestureDetector(onLongPress: _showActions, child: bubble);
    }

    final actions = <Widget>[];
    if (text.isNotEmpty && !widget.isLive && !compact) {
      actions.add(_ActionButton(
        icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
        label: _copied ? 'Copied' : 'Copy',
        onTap: () => _copy(_isUser ? text : plainMessageText(text)),
      ));
      if (!_isUser) {
        actions.add(_ActionButton(
          icon: Icons.data_object_rounded,
          label: 'Markdown',
          onTap: () => _copy(text),
        ));
        final blocks = codeBlocks(text);
        if (blocks.isNotEmpty) {
          actions.add(_CodeCopyMenu(blocks: blocks));
        }
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5, horizontal: compact ? 0 : 4),
      child: Align(
        alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              bubble,
              if (!widget.isLive && text.length > _visibleLimit)
                TextButton(
                  onPressed: () => setState(() => _visibleLimit += 8000),
                  child: Text('Show more · ${text.length - _visibleLimit} characters remaining'),
                ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Wrap(spacing: 14, children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _CodeCopyMenu extends StatelessWidget {
  final List<(String, String?)> blocks;
  const _CodeCopyMenu({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return PopupMenuButton<int>(
      tooltip: 'Copy a code block',
      itemBuilder: (context) => [
        for (var i = 0; i < blocks.length; i++)
          PopupMenuItem(
            value: i,
            child: Text('Block ${i + 1}${blocks[i].$2 != null ? ' · ${blocks[i].$2}' : ''}'),
          ),
      ],
      onSelected: (i) => Clipboard.setData(ClipboardData(text: blocks[i].$1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.code_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text('Copy code', style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
