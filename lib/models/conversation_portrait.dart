import 'dart:convert';

/// Chooses a stable portrait (10–44) for a conversation from its id.
///
/// Portraits 20–44 each get four tickets; portraits 10–19 each get one, so the
/// friendlier illustrations show up more often. The FNV-1a hash reproduces the
/// native app's choice for the same id.
int portraitNumber(String conversationId) {
  final mask = (BigInt.one << 64) - BigInt.one;
  var hash = BigInt.parse('14695981039346656037');
  for (final b in utf8.encode(conversationId)) {
    hash = (hash ^ BigInt.from(b)) & mask;
    hash = (hash * BigInt.from(1099511628211)) & mask;
  }
  final ticket = (hash % BigInt.from(110)).toInt();
  return ticket < 10 ? 10 + ticket : 20 + (ticket - 10) ~/ 4;
}
