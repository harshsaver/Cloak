import 'package:uuid/uuid.dart';

import '../models/alt_identity.dart';
import '../models/chat_models.dart';
import 'cloaker.dart';

const _uuid = Uuid();

/// A locally proposed identifier. Detection proposes exact source text; it never
/// rewrites a message or sends it out.
class DetectorCandidate {
  final String text;
  final String kind;
  const DetectorCandidate(this.text, this.kind);

  @override
  bool operator ==(Object other) => other is DetectorCandidate && other.text == text;
  @override
  int get hashCode => text.hashCode;
}

/// On-device heuristics for names, places, organizations and addresses. This is a
/// best-effort helper for the Review Cloak sheet — it may miss personal information.
class LocalIdentifierDetector {
  static final RegExp _name =
      RegExp(r"\b[A-Z][\p{L}'’.\-]+(?:\s+[A-Z][\p{L}'’.\-]+){0,3}\b", unicode: true);
  static final RegExp _address = RegExp(
      r'\b\d{1,5}\s+(?:[A-Z][a-z]+\.?\s+){1,4}(?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Boulevard|Blvd|Drive|Dr|Court|Ct|Way|Terrace|Place|Pl|Square|Sq)\b');

  static const _stopWords = {
    'The', 'A', 'An', 'I', 'You', 'We', 'They', 'It', 'He', 'She', //
    'This', 'That', 'These', 'Those', 'My', 'Your', 'Our', 'Their', 'His', 'Her',
    'And', 'But', 'Or', 'If', 'When', 'While', 'Please', 'Thanks', 'Hello', 'Hi',
  };

  static List<DetectorCandidate> candidates(String text) {
    final result = <DetectorCandidate>[];
    final seen = <String>{};

    for (final m in _address.allMatches(text)) {
      final value = m.group(0)!.trim();
      if (seen.add(value.toLowerCase())) result.add(DetectorCandidate(value, 'ADDRESS'));
    }
    for (final m in _name.allMatches(text)) {
      final value = m.group(0)!.trim();
      final words = value.split(RegExp(r'\s+'));
      if (words.length == 1 && _stopWords.contains(words.first)) continue;
      if (seen.add(value.toLowerCase())) result.add(DetectorCandidate(value, 'PERSON'));
    }
    return result;
  }
}

/// A local snapshot: sending it uses these exact substitutions, not another random pass.
class CloakReview {
  final String id;
  final List<WireMessage> original;
  final AltIdentity identity;
  final Vault _initialVault;
  Vault vault;
  List<WireMessage> outgoing = [];
  final List<DetectorCandidate> hidden = [];

  CloakReview({required this.original, required this.identity, required Vault vault})
      : id = _uuid.v4(),
        _initialVault = vault.copy(),
        vault = vault.copy() {
    _rebuild();
  }

  List<DetectorCandidate> get available {
    final text = original.map((m) => m.content).join('\n\n');
    return LocalIdentifierDetector.candidates(text).where((c) => needsReview(c.text)).toList();
  }

  void toggle(DetectorCandidate candidate) {
    if (hidden.contains(candidate)) {
      hidden.removeWhere((c) => c == candidate);
    } else {
      hidden.add(candidate);
    }
    _rebuild();
  }

  bool isHidden(DetectorCandidate candidate) => hidden.contains(candidate);

  bool needsReview(String value) {
    final copy = vault.copy();
    return Cloaker.cloak(value, identity: identity, vault: copy) == value;
  }

  void _rebuild() {
    vault = _initialVault.copy();
    final text = original.map((m) => m.content).join('\n\n') + identity.altPairs.map((p) => p.$2).join(' ');
    for (final candidate in hidden) {
      vault.hide(candidate.text, kind: candidate.kind, inText: text);
    }
    outgoing = original
        .map((m) => WireMessage(m.role, Cloaker.cloak(m.content, identity: identity, vault: vault)))
        .toList();
  }
}
