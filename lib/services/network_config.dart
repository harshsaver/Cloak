import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socks5_proxy/socks_client.dart';

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

class NetworkSettings {
  String userAgent;
  bool proxyEnabled;
  bool proxyIsSocks;
  String proxyHost;
  int proxyPort;

  NetworkSettings({
    this.userAgent = '',
    this.proxyEnabled = false,
    this.proxyIsSocks = false,
    this.proxyHost = '',
    this.proxyPort = 0,
  });

  static const _key = 'network.settings';

  NetworkSettings clone() => NetworkSettings(
        userAgent: userAgent,
        proxyEnabled: proxyEnabled,
        proxyIsSocks: proxyIsSocks,
        proxyHost: proxyHost,
        proxyPort: proxyPort,
      );

  Map<String, dynamic> toJson() => {
        'userAgent': userAgent,
        'proxyEnabled': proxyEnabled,
        'proxyIsSOCKS': proxyIsSocks,
        'proxyHost': proxyHost,
        'proxyPort': proxyPort,
      };

  factory NetworkSettings.fromJson(Map<String, dynamic> j) => NetworkSettings(
        userAgent: (j['userAgent'] as String?) ?? '',
        proxyEnabled: (j['proxyEnabled'] as bool?) ?? false,
        proxyIsSocks: (j['proxyIsSOCKS'] ?? j['proxyIsSocks'] as bool?) as bool? ?? false,
        proxyHost: (j['proxyHost'] as String?) ?? '',
        proxyPort: (j['proxyPort'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is NetworkSettings &&
      other.userAgent == userAgent &&
      other.proxyEnabled == proxyEnabled &&
      other.proxyIsSocks == proxyIsSocks &&
      other.proxyHost == proxyHost &&
      other.proxyPort == proxyPort;

  @override
  int get hashCode => Object.hash(userAgent, proxyEnabled, proxyIsSocks, proxyHost, proxyPort);

  String? get validationError {
    if (userAgent.runes.any((r) => r < 0x20 || r == 0x7f)) {
      return 'The User-Agent must be a single line without control characters.';
    }
    if (!proxyEnabled) return null;
    if (proxyHost.isEmpty || proxyHost.contains(RegExp(r'\s'))) {
      return 'Enter a proxy hostname or IP address, without a scheme, path, or credentials.';
    }
    final parsed = Uri.tryParse('http://$proxyHost');
    if (parsed == null ||
        (parsed.host.isEmpty) ||
        parsed.userInfo.isNotEmpty ||
        parsed.path.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      return 'Enter a proxy hostname or IP address, without a scheme, path, or credentials.';
    }
    if (parsed.hasPort) return 'Enter the proxy port in the Port field.';
    if (proxyPort < 1 || proxyPort > 65535) return 'Enter a proxy port between 1 and 65535.';
    return null;
  }

  static Future<NetworkSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return NetworkSettings();
    return NetworkSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save() async {
    final error = validationError;
    if (error != null) throw NetworkException(error);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}

/// Provider requests never silently bypass an enabled, invalid proxy.
class NetworkConfig {
  static Future<http.Client> client() async {
    NetworkSettings settings;
    try {
      settings = await NetworkSettings.load();
    } catch (_) {
      throw NetworkException(
          'Network settings could not be read. Open Network and save valid settings before retrying.');
    }
    return clientFor(settings);
  }

  static Future<http.Client> clientFor(NetworkSettings settings) async {
    final error = settings.validationError;
    if (error != null) throw NetworkException(error);

    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 60);
    httpClient.idleTimeout = const Duration(seconds: 30);
    if (settings.userAgent.isNotEmpty) httpClient.userAgent = settings.userAgent;

    if (settings.proxyEnabled) {
      if (settings.proxyIsSocks) {
        final address =
            InternetAddress.tryParse(settings.proxyHost) ?? (await InternetAddress.lookup(settings.proxyHost)).first;
        SocksTCPClient.assignToHttpClient(httpClient, [
          ProxySettings(address, settings.proxyPort),
        ]);
      } else {
        httpClient.findProxy = (uri) => 'PROXY ${settings.proxyHost}:${settings.proxyPort}';
      }
    }
    return IOClient(httpClient);
  }
}
