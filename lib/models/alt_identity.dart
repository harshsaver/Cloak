import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../services/app_paths.dart';

const _uuid = Uuid();

class CustomPair {
  final String id;
  String real;
  String alt;
  CustomPair({String? id, this.real = '', this.alt = ''}) : id = id ?? _uuid.v4();

  CustomPair clone() => CustomPair(id: id, real: real, alt: alt);

  Map<String, dynamic> toJson() => {'id': id, 'real': real, 'alt': alt};
  factory CustomPair.fromJson(Map<String, dynamic> j) =>
      CustomPair(id: j['id'] as String?, real: (j['real'] as String?) ?? '', alt: (j['alt'] as String?) ?? '');

  @override
  bool operator ==(Object other) => other is CustomPair && other.real == real && other.alt == alt;
  @override
  int get hashCode => Object.hash(real, alt);
}

class IdentityException implements Exception {
  final String message;
  IdentityException(this.message);
  @override
  String toString() => message;
}

/// A paired real/alt identity used by Cloak. The `real*` fields hold genuine PII;
/// the `alt*` fields hold a realistic-but-fake stand-in. When Cloak is on, outgoing
/// text swaps real → alt and the reply swaps alt → real for display.
///
/// Stored locally for the current account; opening Alt ID never asks for a password.
/// The file is not separately encrypted by the app.
class AltIdentity {
  String realName;
  String altName;
  String realEmail;
  String altEmail;
  String realPhone;
  String altPhone;
  String realAddress;
  String altAddress;
  String realDOB;
  String altDOB;
  List<CustomPair> customPairs;

  AltIdentity({
    this.realName = '',
    this.altName = '',
    this.realEmail = '',
    this.altEmail = '',
    this.realPhone = '',
    this.altPhone = '',
    this.realAddress = '',
    this.altAddress = '',
    this.realDOB = '',
    this.altDOB = '',
    List<CustomPair>? customPairs,
  }) : customPairs = customPairs ?? [];

  factory AltIdentity.empty() => AltIdentity();

  AltIdentity clone() => AltIdentity(
        realName: realName,
        altName: altName,
        realEmail: realEmail,
        altEmail: altEmail,
        realPhone: realPhone,
        altPhone: altPhone,
        realAddress: realAddress,
        altAddress: altAddress,
        realDOB: realDOB,
        altDOB: altDOB,
        customPairs: customPairs.map((p) => p.clone()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'realName': realName,
        'altName': altName,
        'realEmail': realEmail,
        'altEmail': altEmail,
        'realPhone': realPhone,
        'altPhone': altPhone,
        'realAddress': realAddress,
        'altAddress': altAddress,
        'realDOB': realDOB,
        'altDOB': altDOB,
        'customPairs': customPairs.map((p) => p.toJson()).toList(),
      };

  factory AltIdentity.fromJson(Map<String, dynamic> j) => AltIdentity(
        realName: (j['realName'] as String?) ?? '',
        altName: (j['altName'] as String?) ?? '',
        realEmail: (j['realEmail'] as String?) ?? '',
        altEmail: (j['altEmail'] as String?) ?? '',
        realPhone: (j['realPhone'] as String?) ?? '',
        altPhone: (j['altPhone'] as String?) ?? '',
        realAddress: (j['realAddress'] as String?) ?? '',
        altAddress: (j['altAddress'] as String?) ?? '',
        realDOB: (j['realDOB'] as String?) ?? '',
        altDOB: (j['altDOB'] as String?) ?? '',
        customPairs: ((j['customPairs'] as List?) ?? [])
            .map((p) => CustomPair.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      other is AltIdentity &&
      other.realName == realName &&
      other.altName == altName &&
      other.realEmail == realEmail &&
      other.altEmail == altEmail &&
      other.realPhone == realPhone &&
      other.altPhone == altPhone &&
      other.realAddress == realAddress &&
      other.altAddress == altAddress &&
      other.realDOB == realDOB &&
      other.altDOB == altDOB &&
      _listEq(other.customPairs, customPairs);

  @override
  int get hashCode => Object.hash(realName, altName, realEmail, altEmail, realPhone, altPhone, realAddress,
      altAddress, realDOB, Object.hashAll(customPairs));

  static bool _listEq(List<CustomPair> a, List<CustomPair> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static const _prefixes = {'mr', 'mrs', 'ms', 'miss', 'mx', 'dr', 'prof', 'sir', 'madam'};

  /// The first written given name, given-name-first. Titles are skipped; the first
  /// name token is preserved including hyphens and apostrophes.
  static String? givenName(String name) {
    if (name.contains(',')) return null;
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    for (final w in words) {
      final bare = w.replaceAll(RegExp(r'[.,]'), '').toLowerCase();
      if (_prefixes.contains(bare)) continue;
      if (!RegExp(r'[A-Za-zÀ-ɏ]').hasMatch(w)) continue;
      if (w.endsWith('.')) return null;
      return w;
    }
    return null;
  }

  /// Declared pairs with both a real and an alt value, sorted longest-real-first so
  /// longer strings are replaced before shorter substrings during cloaking.
  List<(String, String)> get altPairs {
    final candidates = <(String, String)>[
      (realName, altName),
      (realEmail, altEmail),
      (realPhone, altPhone),
      (realAddress, altAddress),
      (realDOB, altDOB),
      for (final p in customPairs) (p.real, p.alt),
    ];
    final result = candidates
        .map((c) => (c.$1.trim(), c.$2.trim()))
        .where((c) => c.$1.isNotEmpty && c.$2.isNotEmpty)
        .toList();
    result.sort((a, b) => b.$1.length - a.$1.length);
    return result;
  }

  // MARK: - Realistic-fake generation

  static const _firstNames = [
    'Liam', 'Emma', 'Noah', 'Olivia', 'Ethan', 'Ava', 'Mason', 'Sophia', //
    'Lucas', 'Isla', 'Hugo', 'Mila', 'Leo', 'Chloe', 'Adam',
  ];
  static const _lastNames = [
    'Bennett', 'Carter', 'Dumont', 'Ellis', 'Fischer', 'Girard', 'Holt', //
    'Ivarsson', 'Keller', 'Laurent', 'Moreau', 'Novak', 'Petit', 'Renaud', 'Stone',
  ];
  static const _streets = [
    'Maple Avenue', 'Rue des Lilas', 'Birch Lane', 'Kingsway', 'Elm Street', //
    'Rue du Marché', 'Cedar Court', 'Highfield Road', 'Rue Bellevue', 'Park Terrace',
  ];
  static const _cities = [
    'Portland', 'Lyon', 'Bristol', 'Utrecht', 'Aarhus', //
    'Nantes', 'Leeds', 'Ghent', 'Turku', 'Rennes',
  ];
  static const _countries = [
    'USA', 'France', 'United Kingdom', 'Netherlands', //
    'Denmark', 'Belgium', 'Finland', 'Ireland',
  ];
  static const _emailDomains = ['example.com', 'example.net', 'example.org'];

  /// Regenerates only the alt values, preserving whatever real values are set.
  void refreshAlt() {
    final rng = Random();
    T pick<T>(List<T> xs) => xs[rng.nextInt(xs.length)];
    String pad(int value, int width) => value.toString().padLeft(width, '0');

    final first = pick(_firstNames);
    final last = pick(_lastNames);
    altName = '$first $last';

    final tag = 10 + rng.nextInt(990);
    altEmail = '${first.toLowerCase()}.${last.toLowerCase()}$tag@${pick(_emailDomains)}';

    altPhone = '+1 (202) 555-0${pad(100 + rng.nextInt(100), 3)}';

    final number = 12 + rng.nextInt(9976);
    final postal = pad(10000 + rng.nextInt(89999), 5);
    altAddress = '$number ${pick(_streets)}, ${pick(_cities)} $postal, ${pick(_countries)}';

    final month = 1 + rng.nextInt(12);
    final day = 1 + rng.nextInt(28);
    final year = 1960 + rng.nextInt(40);
    altDOB = '${pad(year, 4)}-${pad(month, 2)}-${pad(day, 2)}';
  }

  // MARK: - Validation

  String? get validationError {
    final fields = <(String, String)>[
      (realName, altName),
      (realEmail, altEmail),
      (realPhone, altPhone),
      (realAddress, altAddress),
      (realDOB, altDOB),
      for (final p in customPairs) (p.real, p.alt),
    ];
    if (fields.any((f) => f.$1.trim().isNotEmpty && f.$2.trim().isEmpty)) {
      return 'Every real value needs an alt value.';
    }
    final pairs = altPairs;
    final real = pairs.map((p) => p.$1.toLowerCase()).toList();
    final alt = pairs.map((p) => p.$2.toLowerCase()).toList();
    if (real.toSet().length != real.length || alt.toSet().length != alt.length) {
      return 'Use a unique real value and alt value for each pair.';
    }
    if (alt.any((replacement) => real.any((r) => replacement.contains(r)))) {
      return 'Alt values must not contain a real value from any pair.';
    }
    final given = givenName(realName);
    if (given != null) {
      final pattern = RegExp(
        r'(?<![\p{L}\p{M}\p{N}_])' + RegExp.escape(given) + r'(?![\p{L}\p{M}\p{N}_])',
        caseSensitive: false,
        unicode: true,
      );
      if (alt.any(pattern.hasMatch)) {
        return 'Alt values must not contain your real first name.';
      }
    }
    return null;
  }

  // MARK: - Local persistence

  static Future<AltIdentity> load() async {
    final file = await AppPaths.supportFile('alt-identity.json');
    if (!await file.exists()) return AltIdentity.empty();
    final data = await file.readAsString();
    if (data.trim().isEmpty) return AltIdentity.empty();
    return AltIdentity.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> save() async {
    final error = validationError;
    if (error != null) throw IdentityException(error);
    final file = await AppPaths.supportFile('alt-identity.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()), flush: true);
    _tightenPermissions(file);
  }

  static void _tightenPermissions(File file) {
    if (!(Platform.isMacOS || Platform.isLinux)) return;
    try {
      Process.runSync('chmod', ['600', file.path]);
    } catch (_) {
      // Best-effort; the containing directory is already account-scoped.
    }
  }
}
