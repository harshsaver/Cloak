import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider.dart';
import '../services/secret_store.dart';

/// Owns provider API keys and app-wide preferences. Keys are loaded lazily, one
/// provider at a time — never every secret at launch.
class AppState extends ChangeNotifier {
  final SecretStore _keychain;
  final SecretStore _local;
  SharedPreferences? _prefs;

  KeyStorageMode _keyStorage = KeyStorageMode.keychain;
  final Map<String, String> _keys = {};
  final Set<String> _loaded = {};
  final Map<String, String> _keyErrors = {};
  bool ready = false;

  AppState({SecretStore? keychain, SecretStore? local})
      : _keychain = keychain ?? KeychainSecretStore(),
        _local = local ?? LocalSecretStore();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _keyStorage = KeyStorageModeX.fromRaw(_prefs?.getString('keyStorage'));
    ready = true;
    notifyListeners();
  }

  KeyStorageMode get keyStorage => _keyStorage;
  SecretStore get _active => _keyStorage == KeyStorageMode.keychain ? _keychain : _local;

  void changeKeyStorage(KeyStorageMode mode) {
    if (mode == _keyStorage) return;
    _keyStorage = mode;
    _prefs?.setString('keyStorage', mode.raw);
    // Stores are independent. Switching never unlocks, copies, or deletes keys.
    _keys.clear();
    _loaded.clear();
    _keyErrors.clear();
    notifyListeners();
  }

  bool hasKey(AiProvider provider) => _keys.containsKey(provider.id);
  bool hasLoadedKey(AiProvider provider) => _loaded.contains(provider.id);
  String? apiKey(AiProvider provider) => _keys[provider.id];
  String? keyError(AiProvider provider) => _keyErrors[provider.id];

  Future<void> loadKeyIfNeeded(AiProvider provider) async {
    if (hasLoadedKey(provider)) return;
    await reloadKey(provider);
  }

  Future<void> reloadKey(AiProvider provider) async {
    _loaded.add(provider.id);
    try {
      final value = await _active.value(provider.id);
      if (value != null && value.isNotEmpty) {
        _keys[provider.id] = value;
      } else {
        _keys.remove(provider.id);
      }
      _keyErrors.remove(provider.id);
    } catch (error) {
      _keyErrors[provider.id] = error.toString();
    }
    notifyListeners();
  }

  Future<void> setKey(String? value, AiProvider provider) async {
    final trimmed = value?.trim();
    final key = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    await _active.set(provider.id, key);
    if (key == null) {
      _keys.remove(provider.id);
    } else {
      _keys[provider.id] = key;
    }
    _loaded.add(provider.id);
    _keyErrors.remove(provider.id);
    notifyListeners();
  }
}
