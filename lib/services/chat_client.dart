import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import 'network_config.dart';

class ChatClientException implements Exception {
  final String message;
  ChatClientException(this.message);
  @override
  String toString() => message;
}

typedef ClientFactory = Future<http.Client> Function();

/// Streaming chat and model catalogs for the configured provider.
/// Uses `POST {base}/chat/completions` (SSE) and `GET {base}/models`.
class ChatClient {
  final String baseUrl;
  final String apiKey;
  final Map<String, String> extraHeaders;
  final ClientFactory makeClient;

  ChatClient({
    required this.baseUrl,
    required this.apiKey,
    this.extraHeaders = const {},
    ClientFactory? makeClient,
  }) : makeClient = makeClient ?? NetworkConfig.client;

  Map<String, String> _headers({bool sse = false}) => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        if (sse) 'Accept': 'text/event-stream',
        ...extraHeaders,
      };

  Uri _url(String path) => Uri.parse('$baseUrl/$path');

  /// Fetches the live model catalog.
  Future<List<String>> listModels() async {
    final client = await makeClient();
    try {
      final request = http.Request('GET', _url('models'))
        ..headers.addAll(_headers())
        ..followRedirects = false;
      final response = await client.send(request).timeout(const Duration(seconds: 60));
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChatClientException(_httpMessage(response.statusCode, body));
      }
      final decoded = jsonDecode(body);
      final data = (decoded is Map ? decoded['data'] as List? : null) ?? const [];
      final ids = <String>{};
      for (final entry in data) {
        final id = (entry is Map ? entry['id'] as String? : null)?.trim();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      final list = ids.toList()..sort();
      return list;
    } finally {
      client.close();
    }
  }

  /// Streams a chat completion, yielding assistant content deltas as they arrive (SSE).
  Stream<String> chatStream({required String model, required List<WireMessage> messages}) async* {
    final client = await makeClient();
    try {
      final request = http.Request('POST', _url('chat/completions'))
        ..headers.addAll(_headers(sse: true))
        ..followRedirects = false
        ..body = jsonEncode({
          'model': model,
          'messages': messages.map((m) => m.toJson()).toList(),
          'stream': true,
        });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await _readCapped(response.stream, 16384);
        throw ChatClientException(_httpMessage(response.statusCode, body));
      }
      final contentType = (response.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('text/event-stream')) {
        throw ChatClientException('The server returned an unexpected response.');
      }

      var finished = false;
      await for (final payload in _sseEvents(response.stream)) {
        if (payload.trim().isEmpty) continue;
        if (payload.trim() == '[DONE]') {
          finished = true;
          break;
        }
        final event = decodeEvent(payload);
        if (event.$1 != null) yield event.$1!;
        if (event.$2) finished = true;
      }
      if (!finished) {
        throw ChatClientException('The response ended unexpectedly. You can retry the reply.');
      }
    } finally {
      client.close();
    }
  }

  /// (content, finished) for one SSE data payload.
  static (String?, bool) decodeEvent(String payload) {
    dynamic json;
    try {
      json = jsonDecode(payload);
    } catch (_) {
      throw ChatClientException('The server returned an unexpected response.');
    }
    if (json is Map && json['error'] != null) {
      final error = json['error'];
      final message = error is Map ? error['message'] as String? : null;
      throw ChatClientException(message ?? 'The provider could not complete the response.');
    }
    final choices = (json is Map ? json['choices'] as List? : null) ?? const [];
    Map? choice;
    for (final c in choices) {
      if (c is! Map) continue;
      final index = c['index'];
      if (index == null || index == 0) {
        choice = c;
        break;
      }
    }
    if (choice == null) return (null, false); // usage-only event
    if (choice['finish_reason'] == 'error') {
      throw ChatClientException('The provider could not complete the response.');
    }
    final delta = choice['delta'];
    final content = delta is Map ? delta['content'] as String? : null;
    return (content, choice['finish_reason'] != null);
  }

  static Stream<String> _sseEvents(Stream<List<int>> byteStream) async* {
    final lines = byteStream.transform(utf8.decoder).transform(const LineSplitter());
    final buffer = StringBuffer();
    await for (final line in lines) {
      if (line.isEmpty) {
        if (buffer.isNotEmpty) {
          yield buffer.toString();
          buffer.clear();
        }
        continue;
      }
      if (line.startsWith(':')) continue; // comment
      if (line.startsWith('data:')) {
        var value = line.substring(5);
        if (value.startsWith(' ')) value = value.substring(1);
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(value);
      }
      // event:, id:, retry: fields are ignored.
    }
    if (buffer.isNotEmpty) yield buffer.toString();
  }

  static Future<String> _readCapped(Stream<List<int>> stream, int limit) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
      if (bytes.length >= limit) break;
    }
    return utf8.decode(bytes.take(limit).toList(), allowMalformed: true);
  }

  static String _httpMessage(int status, String body) {
    final clean = cleanMessage(body);
    if (status >= 300 && status < 400) {
      return 'The provider redirected the request. Check the configured provider endpoint.';
    }
    switch (status) {
      case 401:
        return 'Invalid or missing API key. Check it in Settings.';
      case 402:
        return 'Payment required — check your account credit.';
      case 403:
        return 'Access denied. Check your API key permissions and model access.';
      case 404:
        return clean.isEmpty ? 'Model not found. Check the model ID.' : clean;
      case 429:
        return 'Rate limited — please slow down and try again.';
      case 500:
      case 502:
      case 503:
      case 504:
        return clean.isEmpty
            ? 'The provider is temporarily unavailable. Try again, or switch model/provider.'
            : clean;
      default:
        return clean.isEmpty ? 'Request failed ($status).' : clean;
    }
  }

  /// Pulls the human-readable message out of an OpenAI-style error body
  /// (`{"error":{"message":"…"}}`), dropping request-id noise.
  static String cleanMessage(String body) {
    try {
      final object = jsonDecode(body);
      if (object is Map && object['error'] is Map) {
        final message = (object['error'] as Map)['message'];
        if (message is String) {
          final idx = message.indexOf(' (request id:');
          return idx >= 0 ? message.substring(0, idx) : message;
        }
      }
    } catch (_) {
      // fall through to a trimmed excerpt
    }
    final trimmed = body.trim();
    return trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
  }
}
