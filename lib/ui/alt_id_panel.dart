import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alt_identity.dart';
import 'widgets.dart';

class AltIdPanel extends StatefulWidget {
  final bool cloakEnabled;
  final ValueChanged<bool> onCloakChanged;
  const AltIdPanel({super.key, required this.cloakEnabled, required this.onCloakChanged});

  @override
  State<AltIdPanel> createState() => _AltIdPanelState();
}

class _AltIdPanelState extends State<AltIdPanel> {
  AltIdentity _identity = AltIdentity.empty();
  AltIdentity _saved = AltIdentity.empty();
  String? _errorText;
  bool _loaded = false;
  bool _detailsOpen = false;
  late bool _cloak;

  /// Bumped when alt fields change programmatically (refresh/clear/reset) so the
  /// uncontrolled text fields rebuild from the new model values.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _cloak = widget.cloakEnabled;
    _load();
  }

  Future<void> _load() async {
    try {
      final identity = await AltIdentity.load();
      setState(() {
        _identity = identity;
        _saved = identity.clone();
        _loaded = true;
        _errorText = null;
        _version++;
      });
    } catch (error) {
      setState(() => _errorText = error.toString());
    }
  }

  Future<void> _save() async {
    try {
      await _identity.save();
      setState(() {
        _saved = _identity.clone();
        _errorText = null;
      });
    } catch (error) {
      setState(() => _errorText = error.toString());
    }
  }

  bool get _dirty => _identity != _saved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = _errorText ?? _identity.validationError;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 16),
          _altCard(),
          const SizedBox(height: 16),
          _manageCard(),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error, style: TextStyle(color: scheme.error)),
          ],
          if (!_loaded)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(onPressed: _load, child: const Text('Retry loading')),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Text(
              !_loaded ? 'Identity unavailable' : (_dirty ? 'Unsaved changes' : 'Saved'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            FilledButton(
              onPressed: (!_loaded || !_dirty || _identity.validationError != null) ? null : _save,
              child: const Text('Save identity'),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'Alt ID is saved locally for your account and opens without a password. The identity file is not '
            'separately encrypted. Cloak replaces configured values and recognized emails, phone numbers, '
            'checksum-valid card numbers, SSNs and IPv4 addresses before chat and web search. Use Review Cloak '
            'beside the composer toggle to inspect outgoing text and locally detect additional names, places and '
            'addresses. It may miss personal information. Saved chats contain the original text on this device.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        PortraitAvatar(number: _cloak ? 43 : 44, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alt ID + Cloak', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                Switch(
                  value: _cloak,
                  onChanged: (v) {
                    setState(() => _cloak = v);
                    widget.onCloakChanged(v);
                  },
                ),
                const SizedBox(width: 6),
                Text(_cloak ? 'Cloak on' : 'Cloak off', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              Text(
                _cloak
                    ? 'Your next message uses your alt identity.'
                    : 'Your next message uses your original details.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _altCard() {
    final rows = <Widget>[
      if (_identity.altDOB.isNotEmpty) _iconLine(Icons.calendar_today_rounded, _identity.altDOB),
      if (_identity.altAddress.isNotEmpty) _iconLine(Icons.home_rounded, _identity.altAddress),
      if (_identity.altEmail.isNotEmpty) _iconLine(Icons.mail_rounded, _identity.altEmail),
      if (_identity.altPhone.isNotEmpty) _iconLine(Icons.phone_rounded, _identity.altPhone),
    ];
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _identity.altName.isEmpty ? 'No alt identity yet' : _identity.altName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (rows.isNotEmpty) ...[const SizedBox(height: 8), ...rows],
          const Divider(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _identity.refreshAlt();
                  _version++;
                }),
                icon: const Icon(Icons.autorenew_rounded, size: 16),
                label: const Text('Refresh'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _identity = AltIdentity.empty();
                  _version++;
                }),
                child: const Text('Clear fields'),
              ),
              OutlinedButton.icon(
                onPressed: _copyAll,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy all'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
        ],
      ),
    );
  }

  Widget _manageCard() {
    final scheme = Theme.of(context).colorScheme;
    return PanelCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _detailsOpen,
          onExpansionChanged: (v) => _detailsOpen = v,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.tune_rounded),
          title: const Text('Manage details', style: TextStyle(fontWeight: FontWeight.w700)),
          children: [
            _pair('Name', 'realName', () => _identity.realName, (v) => _identity.realName = v,
                () => _identity.altName, (v) => _identity.altName = v),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Enter names first-name-first. Cloak matches full names and first names, and restores both in '
                'replies. Add custom pairs for first, two-part and middle-name forms.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
            _pair('Email', 'realEmail', () => _identity.realEmail, (v) => _identity.realEmail = v,
                () => _identity.altEmail, (v) => _identity.altEmail = v),
            _pair('Phone', 'realPhone', () => _identity.realPhone, (v) => _identity.realPhone = v,
                () => _identity.altPhone, (v) => _identity.altPhone = v),
            _pair('Address', 'realAddress', () => _identity.realAddress, (v) => _identity.realAddress = v,
                () => _identity.altAddress, (v) => _identity.altAddress = v),
            _pair('Date of birth', 'realDOB', () => _identity.realDOB, (v) => _identity.realDOB = v,
                () => _identity.altDOB, (v) => _identity.altDOB = v),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Custom pairs', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 6),
            for (final pair in _identity.customPairs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _realAlt(
                  _field(ValueKey('${pair.id}-real'), 'Real', pair.real, (v) => setState(() => pair.real = v)),
                  _field(ValueKey('${pair.id}-alt'), 'Alt', pair.alt, (v) => setState(() => pair.alt = v)),
                  trailing: IconButton(
                    tooltip: 'Remove pair',
                    icon: const Icon(Icons.remove_circle_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => setState(() => _identity.customPairs.removeWhere((p) => p.id == pair.id)),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _identity.customPairs.add(CustomPair())),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add pair'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pair(String label, String key, String Function() getReal, void Function(String) setReal,
      String Function() getAlt, void Function(String) setAlt) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          _realAlt(
            _field(ValueKey('$key-real-$_version'), 'Real', getReal(), (v) => setState(() => setReal(v))),
            _field(ValueKey('$key-alt-$_version'), 'Alt', getAlt(), (v) => setState(() => setAlt(v))),
          ),
        ],
      ),
    );
  }

  /// Real → Alt side by side on desktop; stacked on phones where each needs full width.
  Widget _realAlt(Widget real, Widget alt, {Widget? trailing}) {
    if (isCompact(context)) {
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(children: [
            real,
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Icon(Icons.arrow_downward_rounded, size: 14),
            ),
            alt,
          ]),
        ),
        if (trailing != null) trailing,
      ]);
    }
    return Row(children: [
      Expanded(child: real),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward_rounded, size: 14),
      ),
      Expanded(child: alt),
      if (trailing != null) trailing,
    ]);
  }

  Widget _field(Key key, String hint, String initial, ValueChanged<String> onChanged) {
    return TextFormField(
      key: key,
      initialValue: initial,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _copyAll() {
    final block = 'Name: ${_identity.altName}\n'
        'Date of birth: ${_identity.altDOB}\n'
        'Address: ${_identity.altAddress}\n'
        'Email: ${_identity.altEmail}\n'
        'Phone: ${_identity.altPhone}';
    Clipboard.setData(ClipboardData(text: block));
  }
}
