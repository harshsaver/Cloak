import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/provider.dart';
import '../services/secret_store.dart';
import '../state/app_state.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 620;
    return Dialog(
      insetPadding: wide ? const EdgeInsets.all(40) : const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: wide ? 620 : double.infinity),
        child: const _SettingsForm(),
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm();
  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final Map<String, TextEditingController> _controllers = {
    for (final p in AiProvider.all) p.id: TextEditingController(),
  };
  final Map<String, String?> _errors = {};
  final Map<String, bool> _obscure = {for (final p in AiProvider.all) p.id: true};

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final provider in AiProvider.all) {
        await app.loadKeyIfNeeded(provider);
        final key = app.apiKey(provider);
        if (key != null && _controllers[provider.id]!.text.isEmpty) {
          _controllers[provider.id]!.text = key;
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _trimmed(AiProvider p) => _controllers[p.id]!.text.trim();
  bool _changed(AppState app, AiProvider p) => _trimmed(p) != (app.apiKey(p) ?? '');

  Future<void> _save(AppState app, AiProvider p) async {
    final value = _trimmed(p);
    if (value.isEmpty) return;
    try {
      await app.setKey(value, p);
      setState(() => _errors[p.id] = null);
    } catch (error) {
      setState(() => _errors[p.id] = error.toString());
    }
  }

  Future<void> _clear(AppState app, AiProvider p) async {
    try {
      await app.setKey(null, p);
      _controllers[p.id]!.clear();
      setState(() => _errors[p.id] = null);
    } catch (error) {
      setState(() => _errors[p.id] = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Text('API KEY STORAGE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              SegmentedButton<KeyStorageMode>(
                segments: const [
                  ButtonSegment(value: KeyStorageMode.keychain, label: Text('System keystore')),
                  ButtonSegment(value: KeyStorageMode.local, label: Text('Local file')),
                ],
                selected: {app.keyStorage},
                onSelectionChanged: (s) {
                  app.changeKeyStorage(s.first);
                  for (final c in _controllers.values) {
                    c.clear();
                  }
                  setState(() => _errors.clear());
                },
              ),
              const SizedBox(height: 8),
              Text(
                app.keyStorage == KeyStorageMode.keychain
                    ? 'The system keystore protects your API keys. Each key is sent only to its provider.'
                    : 'No keystore prompts. API keys are saved in an unencrypted file, readable by your account. Each key is sent only to its provider.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              for (final provider in AiProvider.all) _providerSection(app, provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _providerSection(AppState app, AiProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final error = _errors[provider.id] ?? app.keyError(provider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(provider.icon, size: 18, color: provider.tint),
            const SizedBox(width: 8),
            Text(provider.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _controllers[provider.id],
            obscureText: _obscure[provider.id]!,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(app, provider),
            decoration: InputDecoration(
              isDense: true,
              hintText: provider.keyPlaceholder,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure[provider.id]! ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                onPressed: () => setState(() => _obscure[provider.id] = !_obscure[provider.id]!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(
                _status(app, provider),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            if (provider.apiKeysUrl != null)
              TextButton(
                onPressed: () => launchUrl(Uri.parse(provider.apiKeysUrl!), mode: LaunchMode.externalApplication),
                child: const Text('Get a key'),
              ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: (_trimmed(provider).isEmpty || !_changed(app, provider)) ? null : () => _save(app, provider),
              child: const Text('Save'),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: (!app.hasKey(provider) && _trimmed(provider).isEmpty) ? null : () => _clear(app, provider),
              child: Text('Clear', style: TextStyle(color: scheme.error)),
            ),
          ]),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error, style: TextStyle(fontSize: 12, color: scheme.error)),
            ),
        ],
      ),
    );
  }

  String _status(AppState app, AiProvider provider) {
    if (_changed(app, provider)) return 'Unsaved changes';
    if (app.hasKey(provider)) return 'Saved';
    if (app.keyError(provider) != null) return 'Key unavailable';
    return app.hasLoadedKey(provider) ? 'No key saved' : 'Enter a key or load one';
  }
}
