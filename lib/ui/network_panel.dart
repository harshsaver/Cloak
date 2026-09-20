import 'package:flutter/material.dart';

import '../models/user_agent_preset.dart';
import '../services/network_config.dart';
import 'widgets.dart';

class NetworkPanel extends StatefulWidget {
  const NetworkPanel({super.key});

  @override
  State<NetworkPanel> createState() => _NetworkPanelState();
}

class _NetworkPanelState extends State<NetworkPanel> {
  NetworkSettings _settings = NetworkSettings();
  NetworkSettings? _saved;
  String? _errorText;
  int _uaVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await NetworkSettings.load();
      setState(() {
        _settings = settings;
        _saved = settings.clone();
        _uaVersion++;
      });
    } catch (error) {
      setState(() =>
          _errorText = 'Saved network settings could not be read. Enter valid settings and save to replace them.');
    }
  }

  bool get _dirty => _saved == null || _settings != _saved;

  Future<void> _save() async {
    try {
      await _settings.save();
      setState(() {
        _saved = _settings.clone();
        _errorText = null;
      });
    } catch (error) {
      setState(() => _errorText = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preset = UserAgentPreset.matching(_settings.userAgent);
    final validation = _errorText ?? _settings.validationError;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NetworkHeader(settings: _settings, hasChanges: _dirty),
          const SizedBox(height: 18),

          // User-Agent
          _sectionLabel('User-Agent'),
          const SizedBox(height: 8),
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: preset.value,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  items: [
                    for (final p in UserAgentPreset.all)
                      DropdownMenuItem(value: p.value, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) => setState(() {
                    _settings.userAgent = value ?? '';
                    _uaVersion++;
                  }),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: ValueKey('ua-$_uaVersion'),
                  initialValue: _settings.userAgent,
                  onChanged: (v) => setState(() => _settings.userAgent = v),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Enter a value or choose a preset',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Choose a preset or enter your own value, then save. Leave empty to use the system default.',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Proxy
          _sectionLabel('Proxy'),
          const SizedBox(height: 8),
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Route provider requests through a proxy'),
                  value: _settings.proxyEnabled,
                  onChanged: (v) => setState(() => _settings.proxyEnabled = v),
                ),
                if (_settings.proxyEnabled) ...[
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('HTTP')),
                      ButtonSegment(value: true, label: Text('SOCKS5')),
                    ],
                    selected: {_settings.proxyIsSocks},
                    onSelectionChanged: (s) => setState(() => _settings.proxyIsSocks = s.first),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('proxy-host'),
                    initialValue: _settings.proxyHost,
                    onChanged: (v) => setState(() => _settings.proxyHost = v),
                    decoration: const InputDecoration(
                        isDense: true, labelText: 'Host', hintText: '127.0.0.1', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('proxy-port'),
                    initialValue: _settings.proxyPort > 0 ? _settings.proxyPort.toString() : '',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _settings.proxyPort = int.tryParse(v.trim()) ?? 0),
                    decoration: const InputDecoration(
                        isDense: true, labelText: 'Port', hintText: '9050', border: OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Applies to model catalogs and chat requests after saving. TinyFish web searches use their own network '
            'connection and do not use this proxy.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (validation != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: scheme.error, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(validation, style: TextStyle(color: scheme.error))),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Text(_dirty ? 'Unsaved changes' : 'Saved',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const Spacer(),
            FilledButton(
              onPressed: (!_dirty || _settings.validationError != null) ? null : _save,
              child: const Text('Save'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant));
}

class _NetworkHeader extends StatelessWidget {
  final NetworkSettings settings;
  final bool hasChanges;
  const _NetworkHeader({required this.settings, required this.hasChanges});

  int get _portrait => settings.proxyEnabled ? 43 : (settings.userAgent.isEmpty ? 31 : 20);
  String get _route => settings.proxyEnabled ? (settings.proxyIsSocks ? 'SOCKS5 proxy' : 'HTTP proxy') : 'Direct connection';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PortraitAvatar(number: _portrait, size: 68),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
                child: Icon(settings.proxyEnabled ? Icons.lan_rounded : Icons.public_rounded,
                    color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Network', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_route, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(UserAgentPreset.matching(settings.userAgent).name,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (hasChanges)
                const Text('Preview · Save to apply',
                    style: TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ),
        ),
      ],
    );
  }
}
