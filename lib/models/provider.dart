import 'package:flutter/material.dart';

/// A model-routing provider the app can talk to. These are OpenAI-compatible
/// gateways; Cloak sits in front of whichever one you choose.
class AiProvider {
  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final Color tint;
  final String docsUrl;
  final String? apiKeysUrl;
  final String keyPlaceholder;
  final String baseUrl; // no trailing slash, e.g. https://api.orcarouter.ai/v1
  final Map<String, String> extraHeaders;

  const AiProvider({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.tint,
    required this.docsUrl,
    required this.apiKeysUrl,
    required this.keyPlaceholder,
    required this.baseUrl,
    this.extraHeaders = const {},
  });

  static const orcarouter = AiProvider(
    id: 'orcarouter',
    name: 'OrcaRouter',
    tagline: 'Access models through a single gateway.',
    icon: Icons.hub_rounded,
    tint: Color(0xFF1A8CB8),
    docsUrl: 'https://docs.orcarouter.ai',
    apiKeysUrl: 'https://www.orcarouter.ai',
    keyPlaceholder: 'sk-orca-…',
    baseUrl: 'https://api.orcarouter.ai/v1',
  );

  static const openrouter = AiProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    tagline: 'A unified interface for LLMs.',
    icon: Icons.account_tree_rounded,
    tint: Color(0xFF5E59D9),
    docsUrl: 'https://openrouter.ai/docs',
    apiKeysUrl: 'https://openrouter.ai/keys',
    keyPlaceholder: 'sk-or-…',
    baseUrl: 'https://openrouter.ai/api/v1',
    extraHeaders: {'X-Title': 'Cloak'},
  );

  static const featherless = AiProvider(
    id: 'featherless',
    name: 'Featherless',
    tagline: 'Serverless inference for open models.',
    icon: Icons.air_rounded,
    tint: Color(0xFFE86B8F),
    docsUrl: 'https://featherless.ai/docs',
    apiKeysUrl: 'https://featherless.ai',
    keyPlaceholder: 'rc_…',
    baseUrl: 'https://api.featherless.ai/v1',
  );

  static const concurred = AiProvider(
    id: 'concurred',
    name: 'Concurred',
    tagline: 'Chat through the Concurred gateway.',
    icon: Icons.verified_rounded,
    tint: Color(0xFF33A870),
    docsUrl: 'https://concurred.ai/docs/api',
    apiKeysUrl: 'https://concurred.ai/dashboard',
    keyPlaceholder: 'ck_…',
    baseUrl: 'https://concurred.ai/api/v1',
  );

  static const all = <AiProvider>[orcarouter, openrouter, featherless, concurred];

  static AiProvider? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is AiProvider && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
