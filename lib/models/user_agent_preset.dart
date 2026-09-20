enum UaDevice { mac, windows, iphone, android, terminal, custom }

extension UaDeviceX on UaDevice {
  bool get isPhone => this == UaDevice.iphone || this == UaDevice.android;
}

class UserAgentPreset {
  final String name;
  final String value;
  final UaDevice device;
  const UserAgentPreset({required this.name, required this.value, required this.device});

  static const all = <UserAgentPreset>[
    UserAgentPreset(name: 'System default', value: '', device: UaDevice.mac),
    UserAgentPreset(
        name: 'Chrome — macOS',
        value:
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        device: UaDevice.mac),
    UserAgentPreset(
        name: 'Safari — macOS',
        value:
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
        device: UaDevice.mac),
    UserAgentPreset(
        name: 'Firefox — macOS',
        value: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:126.0) Gecko/20100101 Firefox/126.0',
        device: UaDevice.mac),
    UserAgentPreset(
        name: 'Chrome — Windows',
        value:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        device: UaDevice.windows),
    UserAgentPreset(
        name: 'Chrome — Android',
        value:
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
        device: UaDevice.android),
    UserAgentPreset(
        name: 'Safari — iPhone',
        value:
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
        device: UaDevice.iphone),
    UserAgentPreset(name: 'curl', value: 'curl/8.4.0', device: UaDevice.terminal),
  ];

  static UserAgentPreset matching(String value) {
    final v = value.trim();
    for (final p in all) {
      if (p.value == v) return p;
    }
    return UserAgentPreset(name: 'Custom User-Agent', value: v, device: UaDevice.custom);
  }
}
