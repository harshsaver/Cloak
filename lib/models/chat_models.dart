import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum Role { system, user, assistant }

/// A single message rendered in the chat transcript.
class ChatMessage {
  final String id;
  final Role role;
  String text;

  ChatMessage({String? id, required this.role, required this.text}) : id = id ?? _uuid.v4();

  ChatMessage copy() => ChatMessage(id: id, role: role, text: text);

  Map<String, dynamic> toJson() => {'id': id, 'role': role.name, 'text': text};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String?,
        role: Role.values.byName(json['role'] as String),
        text: (json['text'] as String?) ?? '',
      );
}

/// A saved conversation with one provider.
class Conversation {
  final String id;
  String providerId;
  String title;
  String model;
  List<ChatMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;

  Conversation({
    String? id,
    required this.providerId,
    required this.title,
    required this.model,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  }) : id = id ?? _uuid.v4();

  Conversation clone() => Conversation(
        id: id,
        providerId: providerId,
        title: title,
        model: model,
        messages: messages.map((m) => m.copy()).toList(),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerID': providerId,
        'title': title,
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String?,
        providerId: (json['providerID'] ?? json['providerId']) as String,
        title: (json['title'] as String?) ?? '',
        model: (json['model'] as String?) ?? '',
        messages: ((json['messages'] as List?) ?? [])
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );
}

/// Wire type sent to the OpenAI-compatible provider.
class WireMessage {
  final String role;
  final String content;
  const WireMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
