import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebSearchResult {
  final String title;
  final String url;
  final String? snippet;
  const WebSearchResult({required this.title, required this.url, this.snippet});
}

class WebSearchException implements Exception {
  final String message;
  WebSearchException(this.message);
  @override
  String toString() => message;
}

/// Optional TinyFish CLI integration. Available on desktop where a local CLI can be
/// launched; failures propagate so the composer can surface them.
class WebSearchService {
  static Future<List<WebSearchResult>> search(String query) async {
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      throw WebSearchException(
          'Web search runs the TinyFish CLI, available on desktop. Turn off Web search on this device.');
    }
    final candidates = ['/opt/homebrew/bin/tinyfish', '/usr/local/bin/tinyfish'];
    final executable = candidates.firstWhere(
      (path) => File(path).existsSync(),
      orElse: () => '',
    );
    if (executable.isEmpty) {
      throw WebSearchException(
          'Web search needs the TinyFish CLI in /opt/homebrew/bin or /usr/local/bin. Install it and sign in, or turn off Web search.');
    }

    final environment = Map<String, String>.from(Platform.environment)
      ..['PATH'] = '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin'
      ..remove('TINYFISH_DEBUG');

    ProcessResult result;
    try {
      result = await Process.run(
        executable,
        ['search', 'query', '--', query],
        environment: environment,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw WebSearchException('Web search timed out. Try again, or turn off Web search.');
    } catch (_) {
      throw WebSearchException(
          'Web search failed. Check your TinyFish sign-in and connection, or turn off Web search.');
    }
    if (result.exitCode != 0) {
      throw WebSearchException(
          'Web search failed. Check your TinyFish sign-in and connection, or turn off Web search.');
    }
    return decodeResults(result.stdout as String);
  }

  static List<WebSearchResult> decodeResults(String data) {
    dynamic decoded;
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      throw WebSearchException('Web search failed. Check your TinyFish sign-in and connection.');
    }
    final rawResults = decoded is Map ? decoded['results'] as List? : null;
    if (rawResults == null) {
      throw WebSearchException('Web search failed. Check your TinyFish sign-in and connection.');
    }
    final results = <WebSearchResult>[];
    for (final entry in rawResults) {
      if (entry is! Map) continue;
      final url = entry['url'] as String?;
      if (url == null) continue;
      final parsed = Uri.tryParse(url);
      final scheme = parsed?.scheme.toLowerCase() ?? '';
      if ((scheme != 'http' && scheme != 'https') || (parsed?.host ?? '').isEmpty) continue;
      results.add(WebSearchResult(
        title: (entry['title'] as String?) ?? url,
        url: url,
        snippet: entry['snippet'] as String?,
      ));
    }
    if (results.isEmpty) {
      throw WebSearchException(
          'Web search found no usable results. Try a different question, or turn off Web search.');
    }
    return results.take(6).toList();
  }
}
