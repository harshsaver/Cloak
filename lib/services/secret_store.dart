import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_paths.dart';

enum KeyStorageMode { keychain, local }

extension KeyStorageModeX on KeyStorageMode {
  String get title => switch (this) {
        KeyStorageMode.keychain => 'System keystore',
        KeyStorageMode.local => 'Local file',
      };
  String get raw => name;
  static KeyStorageMode fromRaw(String? value) =>
      KeyStorageMode.values.firstWhere((m) => m.name == value, orElse: () => KeyStorageMode.keychain);
}

class SecretStoreException implements Exception {
  final String message;
  SecretStoreException(this.message);
  @override
  String toString() => message;
}

abstract class SecretStore {
  Future<String?> value(String id);
  Future<void> set(String id, String? value);
}

/// System keystore: Keychain on Apple platforms, Keystore / EncryptedSharedPreferences
/// on Android, and the OS credential store on desktop.
class KeychainSecretStore implements SecretStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String _key(String id) => 'cloak.provider.$id';

  @override
  Future<String?> value(String id) => _storage.read(key: _key(id));

  @override
  Future<void> set(String id, String? value) async {
    if (value == null) {
      await _storage.delete(key: _key(id));
    } else {
      await _storage.write(key: _key(id), value: value);
    }
  }
}

/// Unencrypted local file, for people who prefer no keystore prompts. The file lives
/// in the account-scoped application support directory.
class LocalSecretStore implements SecretStore {
  Future<File> _file() => AppPaths.supportFile('provider-keys.json');

  Future<Map<String, dynamic>> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final text = await file.readAsString();
    if (text.trim().isEmpty) return {};
    final decoded = jsonDecode(text);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  @override
  Future<String?> value(String id) async {
    final map = await _read();
    return map[id] as String?;
  }

  @override
  Future<void> set(String id, String? value) async {
    final map = await _read();
    if (value == null) {
      map.remove(id);
    } else {
      map[id] = value;
    }
    final file = await _file();
    await file.writeAsString(jsonEncode(map), flush: true);
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        Process.runSync('chmod', ['600', file.path]);
      } catch (_) {}
    }
  }
}
