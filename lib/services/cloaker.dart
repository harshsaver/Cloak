import 'package:uuid/uuid.dart';

import '../models/alt_identity.dart';

const _uuid = Uuid();

final RegExp _wordChar = RegExp(r'[\p{L}\p{M}\p{N}_]', unicode: true);
final RegExp _spaces = RegExp(r'\s+');

bool _isWhitespace(String ch) => ch.isNotEmpty && ch.trim().isEmpty;

/// A resolved real → alt (or alt → real) pairing.
class _Mapping {
  final String real;
  final String alt;
  final bool isName;
  final String? realGiven;
  final String? altGiven;

  _Mapping({required this.real, required this.alt, this.isName = false})
      : realGiven = isName ? AltIdentity.givenName(real) : null,
        altGiven = isName ? AltIdentity.givenName(alt) : null;

  @override
  bool operator ==(Object other) =>
      other is _Mapping && other.real == real && other.alt == alt && other.isName == isName;
  @override
  int get hashCode => Object.hash(real, alt, isName);
}

class _Rule {
  final String source;
  final String value;
  final _Mapping mapping;
  final bool isShortName;
  final RegExp match;
  final String foldedSource;
  final bool requiresWordStart;

  _Rule({
    required this.source,
    required this.value,
    required this.mapping,
    required this.isShortName,
    required this.match,
    required this.foldedSource,
    required this.requiresWordStart,
  });
}

class _Replacement {
  final int start;
  final int end;
  final String value;
  final _Mapping mapping;
  _Replacement(this.start, this.end, this.value, this.mapping);
}

class _Detector {
  final RegExp regex;
  final String kind;
  final bool Function(String value, String text, int start) accepts;
  _Detector(this.regex, this.kind, [bool Function(String, String, int)? accepts])
      : accepts = accepts ?? _always;
  static bool _always(String a, String b, int c) => true;
}

/// Records used substitutions so replies can be restored. Metadata stays stable if
/// Alt ID is edited later in the conversation.
class Vault {
  final Map<String, _Mapping> _mappings = {};
  List<_Rule> _restorationRules = [];

  /// Sorted (real, alt) pairs that have been used.
  List<(String, String)> get substitutions {
    final list = _mappings.values.map((m) => (m.real, m.alt)).toList();
    list.sort((a, b) => a.$1.compareTo(b.$1));
    return list;
  }

  Vault copy() {
    final v = Vault();
    v._mappings.addAll(_mappings);
    v._restorationRules = List.of(_restorationRules);
    return v;
  }

  void hide(String value, {required String kind, required String inText}) {
    if (_mappings.containsKey(value)) return;
    _record(_Mapping(real: value, alt: _placeholder(kind, inText)));
  }

  String _placeholder(String kind, String text) {
    final reserved = _mappings.values.map((m) => m.alt.toLowerCase()).toSet();
    final lowerText = text.toLowerCase();
    var number = 1;
    while (reserved.contains('[${kind}_$number]'.toLowerCase()) ||
        lowerText.contains('[${kind}_$number]'.toLowerCase())) {
      number += 1;
    }
    return '[${kind}_$number]';
  }

  void _record(_Mapping mapping) {
    if (_mappings[mapping.real] == mapping) return;
    _mappings[mapping.real] = mapping;
    _restorationRules = Cloaker._rules(_mappings.values.toList(), restoring: true);
  }
}

/// Best-effort substitutions for declared values and recognized structured personal
/// data. Ranges are resolved against the original text so replacements never cascade.
class Cloaker {
  static String cloak(String text, {required AltIdentity identity, required Vault vault}) {
    final name = identity.realName.trim();
    final pairs = identity.altPairs.map((p) => _Mapping(real: p.$1, alt: p.$2, isName: p.$1 == name)).toList();
    // Vault mappings override declared pairs with the same real value.
    for (final m in vault._mappings.values) {
      pairs.removeWhere((p) => p.real.toLowerCase() == m.real.toLowerCase());
      pairs.add(m);
    }

    final outboundRules = _rules(pairs, restoring: false);
    final replacements = _matches(text, outboundRules);

    // A name embedded in a link must not leak or turn the URL into a name with
    // spaces. Substitute the whole link and restore it as one value.
    for (final link in _httpLink.allMatches(text)) {
      if (replacements.any((r) => _intersects(r.start, r.end, link.start, link.end))) continue;
      final real = text.substring(link.start, link.end);
      final isNameLink = outboundRules.any((r) => r.mapping.isName && r.match.hasMatch(real));
      if (!isNameLink) continue;
      final alt = vault._mappings[real]?.alt ?? 'https://example.com/${_uuid.v4().toLowerCase()}';
      replacements.add(_Replacement(link.start, link.end, alt, _Mapping(real: real, alt: alt)));
    }

    for (final detector in _detectors) {
      for (final m in detector.regex.allMatches(text)) {
        if (replacements.any((r) => _intersects(r.start, r.end, m.start, m.end))) continue;
        final real = text.substring(m.start, m.end);
        if (!detector.accepts(real, text, m.start)) continue;
        final reservedText = text + pairs.map((p) => p.alt).join(' ');
        final fake = vault._mappings[real]?.alt ?? vault._placeholder(detector.kind, reservedText);
        final mapping = _Mapping(real: real, alt: fake);
        vault._record(mapping);
        replacements.add(_Replacement(m.start, m.end, fake, mapping));
      }
    }

    final selected = _nonOverlapping(replacements);
    for (final item in selected) {
      vault._record(item.mapping);
    }

    // Activate connected pairs (full / first / middle name) even when that exact
    // spelling did not appear, so a reply can restore them. Never invent a variant.
    final active = selected.map((s) => s.mapping).toList();
    final remaining = pairs.where((c) => !active.contains(c)).toList();
    while (true) {
      final index = remaining.indexWhere((c) => active.any((a) => _related(c, a)));
      if (index < 0) break;
      final mapping = remaining.removeAt(index);
      vault._record(mapping);
      active.add(mapping);
    }

    return _replacing(text, selected);
  }

  static String uncloak(String text, {required Vault vault, bool isStreaming = false}) {
    final rules = vault._restorationRules;
    var end = text.length;
    if (isStreaming) {
      for (final rule in rules) {
        final start = _incompleteStart(text, rule);
        if (start != null && start < end) end = start;
      }
    }
    final visible = text.substring(0, end);
    return _replacing(visible, _nonOverlapping(_matches(visible, rules)));
  }

  static bool _related(_Mapping lhs, _Mapping rhs) {
    bool contains(String whole, String part) {
      final expr = _rule(source: part, value: '', mapping: lhs, isShortName: false).match;
      return expr.hasMatch(whole);
    }

    return contains(lhs.real, rhs.real) || contains(rhs.real, lhs.real);
  }

  static List<_Rule> _rules(List<_Mapping> mappings, {required bool restoring}) {
    final candidates = <_Rule>[];
    for (final m in mappings) {
      final source = restoring ? m.alt : m.real;
      final value = restoring ? m.real : m.alt;
      candidates.add(_rule(source: source, value: value, mapping: m, isShortName: false));
      if (m.isName) {
        final givenSource = restoring ? m.altGiven : m.realGiven;
        final givenValue = restoring ? m.realGiven : m.altGiven;
        if (givenSource != null &&
            givenValue != null &&
            givenSource.isNotEmpty &&
            givenValue.isNotEmpty &&
            _canonical(givenSource) != _canonical(source)) {
          candidates.add(_rule(source: givenSource, value: givenValue, mapping: m, isShortName: true));
        }
      }
    }
    final groups = <String, List<_Rule>>{};
    for (final r in candidates) {
      groups.putIfAbsent(_canonical(r.source), () => []).add(r);
    }
    final result = <_Rule>[];
    for (final group in groups.values) {
      final explicit = group.where((r) => !r.isShortName).toList();
      final available = (!restoring && explicit.isNotEmpty) ? explicit : group;
      final distinct = available.map((r) => _canonical(r.value)).toSet();
      if (distinct.length != 1) continue;
      available.sort((a, b) => a.mapping.real.compareTo(b.mapping.real));
      result.add(available.first);
    }
    return result;
  }

  static _Rule _rule({
    required String source,
    required String value,
    required _Mapping mapping,
    required bool isShortName,
  }) {
    final runes = source.runes.toList();
    final firstChar = runes.isEmpty ? '' : String.fromCharCode(runes.first);
    final lastChar = runes.isEmpty ? '' : String.fromCharCode(runes.last);
    final requiresWordStart = _wordChar.hasMatch(firstChar);
    final start = requiresWordStart ? r'(?<![\p{L}\p{M}\p{N}_])' : '';
    final end = _wordChar.hasMatch(lastChar) ? r'(?![\p{L}\p{M}\p{N}_])' : '';

    final buffer = StringBuffer();
    String? lastPart;
    void add(String part) {
      buffer.write(part);
      lastPart = part;
    }

    for (final rune in runes) {
      final ch = String.fromCharCode(rune);
      if (mapping.isName && _isWhitespace(ch)) {
        if (lastPart != r'\s+') add(r'\s+');
      } else if (mapping.isName && (ch == "'" || ch == '’')) {
        add("['’]");
      } else {
        add(RegExp.escape(ch));
      }
    }

    return _Rule(
      source: source,
      value: value,
      mapping: mapping,
      isShortName: isShortName,
      match: RegExp('$start${buffer.toString()}$end', caseSensitive: false, unicode: true),
      foldedSource: _folded(source, mapping.isName),
      requiresWordStart: requiresWordStart,
    );
  }

  static String _folded(String value, bool isName) {
    var v = value.toLowerCase();
    if (isName) {
      v = v.replaceAll('’', "'").replaceAll(_spaces, ' ');
    }
    return v;
  }

  static int? _incompleteStart(String text, _Rule rule) {
    var suffix = '';
    var length = 0;
    final limit = rule.foldedSource.length;
    var index = text.length;
    int? start;
    // Only inspect the tail that could still be an alias, not the whole reply.
    while (index > 0) {
      index -= 1;
      final part = _folded(text[index], rule.mapping.isName);
      if (!(rule.mapping.isName && part == ' ' && suffix.startsWith(' '))) {
        suffix = part + suffix;
        length += part.length;
      }
      if (length > limit) break;
      if (rule.requiresWordStart && index > 0 && _wordChar.hasMatch(text[index - 1])) {
        continue;
      }
      if (rule.foldedSource.startsWith(suffix)) start = index;
    }
    return start;
  }

  static String _canonical(String value) => value
      .toLowerCase()
      .replaceAll('’', "'")
      .split(_spaces)
      .where((s) => s.isNotEmpty)
      .join(' ');

  static List<_Replacement> _matches(String text, List<_Rule> rules) {
    final protected = <(int, int)>[];
    for (final l in _anyLink.allMatches(text)) {
      protected.add((l.start, l.end));
    }
    for (final e in _detectors[0].regex.allMatches(text)) {
      protected.add((e.start, e.end));
    }
    final result = <_Replacement>[];
    for (final rule in rules) {
      for (final m in rule.match.allMatches(text)) {
        if (rule.mapping.isName && protected.any((p) => _intersects(p.$1, p.$2, m.start, m.end))) {
          continue;
        }
        result.add(_Replacement(m.start, m.end, rule.value, rule.mapping));
      }
    }
    return result;
  }

  static List<_Replacement> _nonOverlapping(List<_Replacement> values) {
    final sorted = List.of(values);
    sorted.sort((a, b) {
      if (a.start != b.start) return a.start - b.start;
      final la = a.end - a.start;
      final lb = b.end - b.start;
      if (la != lb) return lb - la;
      return a.mapping.real.compareTo(b.mapping.real);
    });
    final result = <_Replacement>[];
    var end = 0;
    for (final v in sorted) {
      if (v.start >= end) {
        result.add(v);
        end = v.end;
      }
    }
    return result;
  }

  static String _replacing(String text, List<_Replacement> replacements) {
    final sorted = List.of(replacements)..sort((a, b) => a.start - b.start);
    final buffer = StringBuffer();
    var cursor = 0;
    for (final r in sorted) {
      if (r.start < cursor) continue;
      buffer.write(text.substring(cursor, r.start));
      buffer.write(r.value);
      cursor = r.end;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  static bool _intersects(int aStart, int aEnd, int bStart, int bEnd) => aStart < bEnd && bStart < aEnd;

  // MARK: - Detectors

  static final RegExp _anyLink =
      RegExp(r'\b(?:https?://|www\.)[^\s<>()\[\]]+', caseSensitive: false);
  static final RegExp _httpLink = RegExp(r'\bhttps?://[^\s<>()\[\]]+', caseSensitive: false);

  static final List<_Detector> _detectors = [
    _Detector(RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'), 'EMAIL'),
    _Detector(
        RegExp(r'\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b'), 'IP_ADDRESS'),
    _Detector(RegExp(r'(?<![\p{L}\d_])\d{3}-\d{2}-\d{4}(?![\p{L}\d_])', unicode: true), 'SSN'),
    _Detector(
      RegExp(r'(?<![\p{L}\d_])(?:\d[ -]?){12,18}\d(?![\p{L}\d_])', unicode: true),
      'CARD',
      (value, text, start) => _validCard(value),
    ),
    _Detector(
      RegExp(
          r'(?<![\p{L}\d_+])(?:\+\d{1,3}[ .\-]?)?(?:\(\d{3}\)|\d{3})[ .\-]?\d{3}[ .\-]?\d{4}(?![\p{L}\d_])',
          unicode: true),
      'PHONE',
      (value, text, start) {
        if (value.split('').any((c) => !RegExp(r'\d').hasMatch(c))) return true;
        final from = start - 40 < 0 ? 0 : start - 40;
        final prefix = text.substring(from, start);
        return RegExp(r'\b(phone|mobile|call|tel|telephone|contact|fax)\b[^\n]*$', caseSensitive: false)
            .hasMatch(prefix);
      },
    ),
  ];

  static bool _validCard(String value) {
    final digits = value.split('').where((c) => RegExp(r'\d').hasMatch(c)).map(int.parse).toList();
    if (digits.length < 13 || digits.length > 19 || digits.toSet().length <= 1) return false;
    var sum = 0;
    final reversed = digits.reversed.toList();
    for (var i = 0; i < reversed.length; i++) {
      var d = reversed[i];
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    return sum % 10 == 0;
  }
}
