import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

// MARK: - Block model & parser

enum MdKind { paragraph, heading, code, bullet, ordered, quote, rule, image }

class MdBlock {
  final MdKind kind;
  final String text; // paragraph/quote/code/image-url
  final int level; // heading level or ordered start
  final String? language;
  final String? imageAlt;
  final List<String> items;

  const MdBlock({
    required this.kind,
    this.text = '',
    this.level = 0,
    this.language,
    this.imageAlt,
    this.items = const [],
  });
}

/// A small, dependency-free Markdown block parser covering what chat models commonly
/// emit: paragraphs, fenced code, headings, lists, quotes, rules, images.
List<MdBlock> parseMarkdown(String input) {
  final blocks = <MdBlock>[];
  final lines = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  var index = 0;
  final paragraph = <String>[];

  void flushParagraph() {
    final joined = paragraph.join('\n').trim();
    if (joined.isNotEmpty) blocks.add(MdBlock(kind: MdKind.paragraph, text: joined));
    paragraph.clear();
  }

  while (index < lines.length) {
    final line = lines[index];
    final trimmed = line.trim();

    // fenced code
    if (trimmed.isNotEmpty && (trimmed[0] == '`' || trimmed[0] == '~')) {
      final marker = trimmed[0];
      var fenceLen = 0;
      while (fenceLen < trimmed.length && trimmed[fenceLen] == marker) {
        fenceLen++;
      }
      if (fenceLen >= 3) {
        flushParagraph();
        final language = trimmed.substring(fenceLen).trim();
        final code = <String>[];
        index++;
        while (index < lines.length) {
          final candidate = lines[index].trim();
          if (candidate.length >= fenceLen && candidate.split('').every((c) => c == marker)) break;
          code.add(lines[index]);
          index++;
        }
        if (index < lines.length) index++;
        blocks.add(MdBlock(
          kind: MdKind.code,
          text: code.join('\n'),
          language: language.isEmpty ? null : language,
        ));
        continue;
      }
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      index++;
      continue;
    }

    final image = _parseImage(trimmed);
    if (image != null) {
      flushParagraph();
      blocks.add(MdBlock(kind: MdKind.image, imageAlt: image.$1, text: image.$2));
      index++;
      continue;
    }

    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      flushParagraph();
      blocks.add(const MdBlock(kind: MdKind.rule));
      index++;
      continue;
    }

    final heading = _parseHeading(trimmed);
    if (heading != null) {
      flushParagraph();
      blocks.add(MdBlock(kind: MdKind.heading, level: heading.$1, text: heading.$2));
      index++;
      continue;
    }

    if (trimmed.startsWith('>')) {
      flushParagraph();
      final quote = <String>[];
      while (index < lines.length && lines[index].trim().startsWith('>')) {
        quote.add(lines[index].trim().substring(1).trim());
        index++;
      }
      blocks.add(MdBlock(kind: MdKind.quote, text: quote.join('\n')));
      continue;
    }

    if (_isBullet(trimmed)) {
      flushParagraph();
      final items = <String>[];
      while (index < lines.length && _isBullet(lines[index].trim())) {
        items.add(lines[index].trim().substring(2));
        index++;
      }
      blocks.add(MdBlock(kind: MdKind.bullet, items: items));
      continue;
    }

    final drop = _orderedPrefix(trimmed);
    if (drop != null) {
      flushParagraph();
      final start = int.tryParse(trimmed.substring(0, drop - 2)) ?? 1;
      final items = <String>[];
      while (index < lines.length) {
        final d = _orderedPrefix(lines[index].trim());
        if (d == null) break;
        items.add(lines[index].trim().substring(d));
        index++;
      }
      blocks.add(MdBlock(kind: MdKind.ordered, level: start, items: items));
      continue;
    }

    paragraph.add(line);
    index++;
  }
  flushParagraph();
  return blocks;
}

(int, String)? _parseHeading(String line) {
  var level = 0;
  for (final c in line.split('')) {
    if (c == '#') {
      level++;
    } else {
      break;
    }
  }
  if (level < 1 || level > 6 || line.length <= level) return null;
  if (line[level] != ' ') return null;
  return (level, line.substring(level).trim());
}

bool _isBullet(String line) => line.startsWith('- ') || line.startsWith('* ') || line.startsWith('+ ');

int? _orderedPrefix(String line) {
  var i = 0;
  while (i < line.length && _isDigit(line[i])) {
    i++;
  }
  if (i == 0 || i >= line.length || line[i] != '.') return null;
  if (i + 1 >= line.length || line[i + 1] != ' ') return null;
  return i + 2;
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

(String, String)? _parseImage(String line) {
  if (!line.startsWith('![')) return null;
  final close = line.indexOf(']');
  if (close < 0) return null;
  final alt = line.substring(2, close);
  final rest = line.substring(close + 1);
  if (!rest.startsWith('(') || !rest.endsWith(')')) return null;
  return (alt, rest.substring(1, rest.length - 1));
}

/// Extracts fenced code blocks as (code, language) for the "Copy code" menu.
List<(String, String?)> codeBlocks(String md) => parseMarkdown(md)
    .where((b) => b.kind == MdKind.code)
    .map((b) => (b.text, b.language))
    .toList();

/// A plain-text rendering used for the Copy button (markers stripped).
String plainMessageText(String md) {
  final out = StringBuffer();
  for (final block in parseMarkdown(md)) {
    if (out.isNotEmpty) out.write('\n\n');
    switch (block.kind) {
      case MdKind.paragraph:
      case MdKind.heading:
      case MdKind.quote:
        out.write(_stripInline(block.text));
      case MdKind.code:
        out.write(block.text);
      case MdKind.bullet:
        out.write(block.items.map((i) => '•  ${_stripInline(i)}').join('\n'));
      case MdKind.ordered:
        out.write([
          for (var i = 0; i < block.items.length; i++) '${block.level + i}.  ${_stripInline(block.items[i])}'
        ].join('\n'));
      case MdKind.rule:
        out.write('──────────');
      case MdKind.image:
        out.write(block.imageAlt!.isEmpty ? block.text : block.imageAlt!);
    }
  }
  return out.toString();
}

String _stripInline(String text) => text
    .replaceAll(RegExp(r'\*\*|__|~~|`'), '')
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\(([^)\s]+)\)'), (m) => m.group(1)!);

// MARK: - Rich text widget

class MarkdownText extends StatefulWidget {
  final String text;
  final Color color;
  final bool selectable;
  final double fontSize;
  const MarkdownText(this.text,
      {super.key, required this.color, this.selectable = true, this.fontSize = 15});

  @override
  State<MarkdownText> createState() => _MarkdownTextState();
}

class _MarkdownTextState extends State<MarkdownText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final scheme = Theme.of(context).colorScheme;
    final fs = widget.fontSize;
    final base = TextStyle(fontSize: fs, height: 1.32, color: widget.color);
    final linkColor = widget.color == Colors.white ? Colors.white : CloakColors.accent;
    final codeBg = widget.color == Colors.white
        ? Colors.white.withValues(alpha: 0.18)
        : scheme.onSurface.withValues(alpha: 0.08);

    final children = <InlineSpan>[];
    var first = true;
    for (final block in parseMarkdown(widget.text)) {
      // Half-height gap between blocks (a full blank line reads too airy on phones).
      if (!first) children.add(TextSpan(text: '\n\n', style: base.copyWith(fontSize: fs * 0.55, height: 1.0)));
      first = false;
      switch (block.kind) {
        case MdKind.paragraph:
          children.addAll(_inline(block.text, base, linkColor, codeBg));
        case MdKind.heading:
          final size = block.level == 1 ? fs + 3 : (block.level == 2 ? fs + 1.5 : fs + 0.5);
          children.addAll(_inline(block.text, base.copyWith(fontSize: size, fontWeight: FontWeight.w700), linkColor, codeBg));
        case MdKind.code:
          if (block.language != null) {
            children.add(TextSpan(
              text: '${block.language!.toLowerCase()}\n',
              style: base.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: widget.color.withValues(alpha: 0.6)),
            ));
          }
          children.add(TextSpan(
            text: block.text,
            style: base.copyWith(fontFamily: 'monospace', fontSize: fs - 1.5, height: 1.4, backgroundColor: codeBg),
          ));
        case MdKind.bullet:
          for (var i = 0; i < block.items.length; i++) {
            if (i > 0) children.add(TextSpan(text: '\n', style: base));
            children.add(TextSpan(text: '•  ', style: base));
            children.addAll(_inline(block.items[i], base, linkColor, codeBg));
          }
        case MdKind.ordered:
          for (var i = 0; i < block.items.length; i++) {
            if (i > 0) children.add(TextSpan(text: '\n', style: base));
            children.add(TextSpan(text: '${block.level + i}.  ', style: base));
            children.addAll(_inline(block.items[i], base, linkColor, codeBg));
          }
        case MdKind.quote:
          final quoteStyle = base.copyWith(color: widget.color.withValues(alpha: 0.75), fontStyle: FontStyle.italic);
          for (final line in block.text.split('\n')) {
            children.add(TextSpan(text: '│  ', style: quoteStyle));
            children.addAll(_inline(line, quoteStyle, linkColor, codeBg));
            children.add(TextSpan(text: '\n', style: quoteStyle));
          }
        case MdKind.rule:
          children.add(TextSpan(text: '──────────', style: base.copyWith(color: widget.color.withValues(alpha: 0.4))));
        case MdKind.image:
          final label = block.imageAlt!.isEmpty ? block.text : block.imageAlt!;
          children.add(_linkSpan(label, block.text, base, linkColor));
      }
    }

    final root = TextSpan(children: children, style: base);
    if (widget.selectable) {
      return SelectableText.rich(root);
    }
    return Text.rich(root);
  }

  List<InlineSpan> _inline(String text, TextStyle base, Color linkColor, Color codeBg) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString(), style: base));
        buffer.clear();
      }
    }

    var i = 0;
    while (i < text.length) {
      // inline code
      if (text[i] == '`') {
        final end = text.indexOf('`', i + 1);
        if (end > i) {
          flush();
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: base.copyWith(fontFamily: 'monospace', fontSize: base.fontSize! - 1, backgroundColor: codeBg),
          ));
          i = end + 1;
          continue;
        }
      }
      // link
      if (text[i] == '[') {
        final match = _linkPattern.matchAsPrefix(text, i);
        if (match != null) {
          flush();
          spans.add(_linkSpan(match.group(1)!, match.group(2)!, base, linkColor));
          i = match.end;
          continue;
        }
      }
      // bold
      if (text.startsWith('**', i)) {
        final end = text.indexOf('**', i + 2);
        if (end > i) {
          flush();
          spans.addAll(_inline(text.substring(i + 2, end), base.copyWith(fontWeight: FontWeight.w700), linkColor, codeBg));
          i = end + 2;
          continue;
        }
      }
      // strikethrough
      if (text.startsWith('~~', i)) {
        final end = text.indexOf('~~', i + 2);
        if (end > i) {
          flush();
          spans.addAll(_inline(text.substring(i + 2, end), base.copyWith(decoration: TextDecoration.lineThrough), linkColor, codeBg));
          i = end + 2;
          continue;
        }
      }
      // italic
      if (text[i] == '*' || text[i] == '_') {
        final marker = text[i];
        final end = text.indexOf(marker, i + 1);
        if (end > i + 1) {
          flush();
          spans.addAll(_inline(text.substring(i + 1, end), base.copyWith(fontStyle: FontStyle.italic), linkColor, codeBg));
          i = end + 1;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }
    flush();
    return spans;
  }

  InlineSpan _linkSpan(String label, String url, TextStyle base, Color linkColor) {
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    final tappable = scheme == 'http' || scheme == 'https' || scheme == 'mailto';
    if (!tappable) return TextSpan(text: label, style: base);
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        launchUrl(uri!, mode: LaunchMode.externalApplication).catchError((_) => false);
      };
    _recognizers.add(recognizer);
    return TextSpan(
      text: label,
      style: base.copyWith(color: linkColor, decoration: TextDecoration.underline),
      recognizer: recognizer,
    );
  }
}

final RegExp _linkPattern = RegExp(r'\[([^\]]*)\]\(([^)\s]+)\)');
