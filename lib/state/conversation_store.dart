import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/chat_models.dart';
import '../services/app_paths.dart';

/// The single owner of conversation state. A failed load is never overwritten.
class ConversationStore extends ChangeNotifier {
  List<Conversation> _conversations = [];
  final Map<String, String> _drafts = {};
  String? errorText;
  bool isReadBlocked = false;
  bool _loaded = false;
  bool _demo = false;
  File? _file;

  bool get loaded => _loaded;

  /// Demo mode only: replace conversations in memory. Nothing is written to disk
  /// for the rest of the session, so real saved chats are never touched.
  void debugSeed(List<Conversation> conversations) {
    _demo = true;
    _conversations = conversations;
    isReadBlocked = false;
    errorText = null;
    _loaded = true;
    notifyListeners();
  }

  Future<void> init() async {
    _file = await AppPaths.supportFile('conversations.json');
    await _load();
    _loaded = true;
    notifyListeners();
  }

  File get fileForDisplay => _file ?? File('conversations.json');

  /// Every conversation across all providers, most recent first.
  List<Conversation> all() {
    final items = List.of(_conversations);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<Conversation> list(String providerId) {
    final items = _conversations.where((c) => c.providerId == providerId).toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Conversation? conversation(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  Conversation newOrReuseEmpty({required String providerId, required String model}) {
    final existing = list(providerId).where((c) => c.messages.isEmpty);
    if (existing.isNotEmpty) return existing.first;
    final now = DateTime.now();
    final conversation = Conversation(
      providerId: providerId,
      title: '',
      model: model,
      messages: [],
      createdAt: now,
      updatedAt: now,
    );
    _conversations.add(conversation);
    notifyListeners();
    return conversation;
  }

  String draft(String id) => _drafts[id] ?? '';

  void setDraft(String text, String id) {
    if (conversation(id) == null) return;
    if (text.isEmpty) {
      _drafts.remove(id);
    } else {
      _drafts[id] = text;
    }
    notifyListeners();
  }

  void save(Conversation conversation) {
    // A late response must not resurrect a deleted conversation.
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index < 0) return;
    _conversations[index] = conversation;
    _persist();
    notifyListeners();
  }

  void rename(String id, String title) {
    final trimmed = title.trim();
    final index = _conversations.indexWhere((c) => c.id == id);
    if (trimmed.isEmpty || index < 0) return;
    _conversations[index].title = trimmed;
    _persist();
    notifyListeners();
  }

  void delete(String id) {
    _conversations.removeWhere((c) => c.id == id);
    _drafts.remove(id);
    _persist();
    notifyListeners();
  }

  void retryPersistence() {
    if (isReadBlocked) {
      _load().then((_) => notifyListeners());
    } else {
      _persist();
      notifyListeners();
    }
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null) return;
    try {
      if (!await file.exists()) {
        _conversations = [];
        isReadBlocked = false;
        errorText = null;
        return;
      }
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! List) throw const FormatException('corrupt');
      final loaded = decoded
          .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final ids = loaded.map((c) => c.id).toSet();
      final messagesValid = loaded.every((c) => c.messages.map((m) => m.id).toSet().length == c.messages.length);
      if (ids.length != loaded.length || !messagesValid) {
        throw const FormatException('corrupt');
      }
      _conversations = loaded;
      isReadBlocked = false;
      errorText = null;
    } catch (error) {
      isReadBlocked = true;
      errorText = 'Saved chats could not be opened. The existing file has been kept intact. $error';
    }
  }

  Future<void> _persist() async {
    if (isReadBlocked || _demo) return;
    final file = _file;
    if (file == null) return;
    try {
      final data = _conversations.where((c) => c.messages.isNotEmpty).map((c) => c.toJson()).toList();
      const encoder = JsonEncoder.withIndent('  ');
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(encoder.convert(data), flush: true);
      await tmp.rename(file.path);
      if (Platform.isMacOS || Platform.isLinux) {
        try {
          Process.runSync('chmod', ['600', file.path]);
        } catch (_) {}
      }
      errorText = null;
    } catch (error) {
      errorText = 'Your latest chat changes have not been saved. $error';
    }
  }
}
