import 'models/chat_models.dart';
import 'models/provider.dart';
import 'state/app_state.dart';
import 'state/conversation_store.dart';

/// Compile-time demo switch: `flutter run --dart-define=CLOAK_DEMO=true`.
/// Seeds in-memory sample chats and a placeholder key so every screen can be
/// previewed and screenshotted. Release builds never define it.
const bool kCloakDemo = bool.fromEnvironment('CLOAK_DEMO');

void applyDemo(AppState app, ConversationStore store) {
  app.debugSetKey(AiProvider.orcarouter, 'demo-key');
  store.debugSeed(_conversations());
}

List<Conversation> _conversations() {
  final now = DateTime.now();
  Conversation chat(String title, Duration ago, List<(Role, String)> turns, {String model = 'openai/gpt-4o-mini'}) {
    final at = now.subtract(ago);
    return Conversation(
      providerId: AiProvider.orcarouter.id,
      title: title,
      model: model,
      messages: [for (final t in turns) ChatMessage(role: t.$1, text: t.$2)],
      createdAt: at,
      updatedAt: at,
    );
  }

  return [
    chat('A weekend in Kyoto', const Duration(minutes: 12), [
      (Role.user, 'Plan a relaxed two-day weekend in Kyoto. I like temples, good coffee and quiet walks.'),
      (
        Role.assistant,
        '## Day 1 — Higashiyama\n\n'
            '- **Morning:** Kiyomizu-dera before 8am, then walk down Sannenzaka.\n'
            '- **Coffee:** % Arabica by the Yasaka Pagoda.\n'
            '- **Afternoon:** the Philosopher’s Path to Ginkaku-ji — quiet and shaded.\n\n'
            '## Day 2 — Arashiyama\n\n'
            '1. Bamboo grove at opening time\n'
            '2. Tenryu-ji garden\n'
            '3. Boat ride on the Hozu river\n\n'
            'Want me to add dinner spots near your hotel?'
      ),
      (Role.user, 'Yes please, somewhere calm near Gion.'),
    ]),
    chat('Fix my Python script', const Duration(hours: 3), [
      (Role.user, 'Why does this crash with KeyError?\n\ncounts = {}\nfor w in words:\n    counts[w] += 1'),
      (
        Role.assistant,
        'The first time a word appears it isn’t in `counts` yet, so `+=` has nothing to add to. '
            'Use `collections.Counter` or `dict.get`:\n\n'
            '```python\nfrom collections import Counter\n\ncounts = Counter(words)\nprint(counts.most_common(3))\n```\n\n'
            'Or keep the loop with `counts[w] = counts.get(w, 0) + 1`.'
      ),
    ], model: 'anthropic/claude-haiku'),
    chat('Email to my landlord', const Duration(days: 1, hours: 2), [
      (Role.user, 'Draft a polite email asking my landlord to fix the heating before the weekend.'),
      (
        Role.assistant,
        'Subject: Heating repair request\n\nHi Alex,\n\nI hope you’re well. The heating in the flat stopped working on Tuesday '
            'and the evenings are getting cold. Could someone take a look before the weekend? I’m home most afternoons.\n\n'
            'Thank you,\nMaya'
      ),
    ]),
    chat('Explain vector databases', const Duration(days: 4), [
      (Role.user, 'Explain vector databases like I’m a backend engineer who has only used Postgres.'),
      (
        Role.assistant,
        'A vector database stores **embeddings** — arrays of floats that capture meaning — and answers the question '
            '“what is *closest* to this?” instead of “what equals this?”.\n\n'
            'In Postgres terms: imagine a column of `float[1536]` and a query ordered by distance to a probe vector. '
            'A naive scan is O(n), so vector databases build approximate indexes (HNSW, IVF) that trade a little '
            'recall for a lot of speed.\n\n'
            '> If you already run Postgres, the `pgvector` extension gives you most of this without a new system.\n\n'
            'Typical flow: chunk documents → embed each chunk → store vectors with metadata → embed the user question → '
            'fetch the top-k nearest chunks → hand them to the model as context.'
      ),
    ]),
  ];
}
