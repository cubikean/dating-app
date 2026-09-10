import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app_boilerplate/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchModel.buildId', () {
    test("l'ordre des arguments ne change pas l'identifiant", () {
      expect(MatchModel.buildId('bob', 'alice'),
          MatchModel.buildId('alice', 'bob'));
    });

    test('les deux uids sont joints triés', () {
      expect(MatchModel.buildId('bob', 'alice'), 'alice_bob');
    });
  });

  group('otherUserId', () {
    final match = MatchModel(
      id: 'alice_bob',
      userIds: const ['alice', 'bob'],
      createdAt: DateTime(2026, 9, 1),
    );

    test("renvoie l'autre participant", () {
      expect(match.otherUserId('alice'), 'bob');
      expect(match.otherUserId('bob'), 'alice');
    });

    test('un match avec soi-même se replie sur son propre uid', () {
      // Seul cas où le repli sert : sinon `firstWhere` trouve toujours un uid
      // différent, y compris quand le demandeur n'appartient pas au match.
      final selfMatch = MatchModel(
        id: 'alice_alice',
        userIds: const ['alice', 'alice'],
        createdAt: DateTime(2026, 9, 1),
      );

      expect(selfMatch.otherUserId('alice'), 'alice');
    });
  });

  group('toMap', () {
    final createdAt = DateTime(2026, 9, 1, 12, 30);

    test('écrit toujours lastMessageAt, même sans message', () {
      // Régression : sans ce champ, la requête triée de `watchMatchesForUser`
      // excluait le document et le match restait invisible dans l'app.
      final match = MatchModel(
        id: 'alice_bob',
        userIds: const ['alice', 'bob'],
        createdAt: createdAt,
      );

      final map = match.toMap();

      expect(map.containsKey('lastMessageAt'), isTrue);
      expect((map['lastMessageAt'] as Timestamp).toDate(), createdAt);
    });

    test('conserve la date du dernier message quand elle existe', () {
      final lastMessageAt = DateTime(2026, 9, 5, 8, 0);
      final match = MatchModel(
        id: 'alice_bob',
        userIds: const ['alice', 'bob'],
        createdAt: createdAt,
        lastMessage: 'salut',
        lastMessageAt: lastMessageAt,
      );

      final map = match.toMap();

      expect((map['lastMessageAt'] as Timestamp).toDate(), lastMessageAt);
      expect(map['lastMessage'], 'salut');
    });

    test('omet lastMessage tant que rien n\'a été écrit', () {
      final match = MatchModel(
        id: 'alice_bob',
        userIds: const ['alice', 'bob'],
        createdAt: createdAt,
      );

      expect(match.toMap().containsKey('lastMessage'), isFalse);
    });
  });

  group('fromMap', () {
    test('lit la clé « users » du document', () {
      final match = MatchModel.fromMap('alice_bob', {
        'users': const ['alice', 'bob'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });

      expect(match.userIds, ['alice', 'bob']);
      expect(match.lastMessageAt, isNull);
    });
  });
}
