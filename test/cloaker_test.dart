import 'package:cloak/models/alt_identity.dart';
import 'package:cloak/models/chat_models.dart';
import 'package:cloak/models/conversation_portrait.dart';
import 'package:cloak/services/chat_client.dart';
import 'package:cloak/services/cloaker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cloaker', () {
    AltIdentity maya() => AltIdentity(realName: 'Maya Bright', altName: 'Alex Stone');

    test('swaps a configured name outward and restores it in a reply', () {
      final identity = maya();
      final vault = Vault();
      final outgoing = Cloaker.cloak("Hi, I'm Maya Bright.", identity: identity, vault: vault);
      expect(outgoing, "Hi, I'm Alex Stone.");

      final reply = Cloaker.uncloak('Hello Alex Stone, nice to meet you.', vault: vault);
      expect(reply, 'Hello Maya Bright, nice to meet you.');
    });

    test('restores a first name used alone in the reply', () {
      final identity = maya();
      final vault = Vault();
      Cloaker.cloak('My name is Maya Bright.', identity: identity, vault: vault);
      final reply = Cloaker.uncloak('Sure, Alex! Happy to help.', vault: vault);
      expect(reply, contains('Maya'));
      expect(reply, isNot(contains('Alex')));
    });

    test('does not cut inside an unrelated word', () {
      final identity = AltIdentity(realName: 'Ana', altName: 'Zoe');
      final vault = Vault();
      final outgoing = Cloaker.cloak('banana analysis', identity: identity, vault: vault);
      expect(outgoing, 'banana analysis');
    });

    test('masks an email address with a stable placeholder', () {
      final vault = Vault();
      final outgoing = Cloaker.cloak('Reach me at maya@example.com today.',
          identity: AltIdentity.empty(), vault: vault);
      expect(outgoing, isNot(contains('maya@example.com')));
      expect(outgoing, matches(RegExp(r'\[EMAIL_\d\]')));
    });

    test('detects a Luhn-valid card and leaves random digits alone', () {
      final vault = Vault();
      final outgoing = Cloaker.cloak('Card 4111 1111 1111 1111 and ref 1234 5678 9012.',
          identity: AltIdentity.empty(), vault: vault);
      expect(outgoing, isNot(contains('4111 1111 1111 1111')));
      expect(outgoing, contains('1234 5678 9012'));
    });
  });

  group('AltIdentity', () {
    test('validation rejects an alt value that contains the real first name', () {
      final identity = AltIdentity(realName: 'Maya Bright', altName: 'Maya Stone');
      expect(identity.validationError, isNotNull);
    });

    test('altPairs sorts longest real value first', () {
      final identity = AltIdentity(
        realName: 'Maya',
        altName: 'Alex',
        realEmail: 'maya@example.com',
        altEmail: 'alex@example.net',
      );
      expect(identity.altPairs.first.$1, 'maya@example.com');
    });
  });

  group('ChatClient.decodeEvent', () {
    test('extracts content deltas', () {
      final event = ChatClient.decodeEvent('{"choices":[{"delta":{"content":"Hi"}}]}');
      expect(event.$1, 'Hi');
      expect(event.$2, isFalse);
    });

    test('surfaces an in-band error envelope', () {
      expect(
        () => ChatClient.decodeEvent('{"error":{"message":"No endpoints found"}}'),
        throwsA(isA<ChatClientException>()),
      );
    });

    test('cleanMessage strips request-id noise', () {
      final message = ChatClient.cleanMessage('{"error":{"message":"Bad key (request id: abc123)"}}');
      expect(message, 'Bad key');
    });
  });

  group('portraitNumber', () {
    test('is stable and within range', () {
      final n = portraitNumber('11111111-1111-1111-1111-111111111111');
      expect(n, inInclusiveRange(10, 44));
      expect(portraitNumber('11111111-1111-1111-1111-111111111111'), n);
    });
  });

  test('WireMessage serializes role and content', () {
    expect(const WireMessage('user', 'hello').toJson(), {'role': 'user', 'content': 'hello'});
  });
}
