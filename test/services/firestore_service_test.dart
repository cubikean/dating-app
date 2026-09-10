import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app_boilerplate/models/user_profile.dart';
import 'package:dating_app_boilerplate/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirestoreService(firestore: db);
  });

  Future<void> seedMatch(
    String id, {
    required List<String> users,
    required DateTime createdAt,
    DateTime? lastMessageAt,
    String? lastMessage,
  }) {
    return db.collection('matches').doc(id).set({
      'users': users,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
    });
  }

  group('watchMatchesForUser', () {
    test('inclut un match sans aucun message', () async {
      // Régression : la requête triait sur `lastMessageAt` côté Firestore, ce
      // qui excluait tout match sans message. Les deux onglets restaient vides.
      await seedMatch('alice_bob',
          users: ['alice', 'bob'], createdAt: DateTime(2026, 9, 1));

      final matches = await service.watchMatchesForUser('alice').first;

      expect(matches, hasLength(1));
      expect(matches.single.id, 'alice_bob');
    });

    test('classe les conversations actives avant les matchs muets', () async {
      await seedMatch('alice_bob',
          users: ['alice', 'bob'], createdAt: DateTime(2026, 9, 1));
      await seedMatch('alice_carol',
          users: ['alice', 'carol'],
          createdAt: DateTime(2026, 8, 1),
          lastMessage: 'salut',
          lastMessageAt: DateTime(2026, 9, 8));

      final matches = await service.watchMatchesForUser('alice').first;

      expect(matches.map((m) => m.id), ['alice_carol', 'alice_bob']);
    });

    test('un match muet est classé sur sa date de création', () async {
      await seedMatch('alice_bob',
          users: ['alice', 'bob'], createdAt: DateTime(2026, 9, 5));
      await seedMatch('alice_carol',
          users: ['alice', 'carol'], createdAt: DateTime(2026, 9, 9));

      final matches = await service.watchMatchesForUser('alice').first;

      expect(matches.map((m) => m.id), ['alice_carol', 'alice_bob']);
    });

    test("ne renvoie pas les matchs auxquels on n'appartient pas", () async {
      await seedMatch('bob_carol',
          users: ['bob', 'carol'], createdAt: DateTime(2026, 9, 1));

      final matches = await service.watchMatchesForUser('alice').first;

      expect(matches, isEmpty);
    });
  });

  group('sendMessage', () {
    setUp(() => seedMatch('alice_bob',
        users: ['alice', 'bob'], createdAt: DateTime(2026, 9, 1)));

    test('écrit le message et met à jour le match du même coup', () async {
      await service.sendMessage(
        matchId: 'alice_bob',
        senderId: 'alice',
        text: 'bonjour',
      );

      final messages = await db.collection('matches/alice_bob/messages').get();
      expect(messages.docs, hasLength(1));
      expect(messages.docs.single.data()['senderId'], 'alice');
      expect(messages.docs.single.data()['text'], 'bonjour');

      final match = await db.collection('matches').doc('alice_bob').get();
      expect(match.data()!['lastMessage'], 'bonjour');
      expect(match.data()!['lastMessageAt'], isA<Timestamp>());
    });

    test('le message remonte la conversation en tête de liste', () async {
      await seedMatch('alice_carol',
          users: ['alice', 'carol'], createdAt: DateTime(2026, 9, 9));

      await service.sendMessage(
        matchId: 'alice_bob',
        senderId: 'alice',
        text: 'bonjour',
      );

      final matches = await service.watchMatchesForUser('alice').first;
      expect(matches.first.id, 'alice_bob');
    });
  });

  group('watchMessages', () {
    Future<void> seedMessages(int count) async {
      await seedMatch('alice_bob',
          users: ['alice', 'bob'], createdAt: DateTime(2026, 9, 1));
      for (var i = 0; i < count; i++) {
        await db.collection('matches/alice_bob/messages').add({
          'senderId': 'alice',
          'text': 'message $i',
          'sentAt': Timestamp.fromDate(
              DateTime(2026, 9, 1).add(Duration(minutes: i))),
        });
      }
    }

    test('rend les messages du plus ancien au plus récent', () async {
      await seedMessages(3);

      final messages = await service.watchMessages('alice_bob').first;

      expect(
          messages.map((m) => m.text), ['message 0', 'message 1', 'message 2']);
    });

    test('la limite garde la fin de la conversation, pas le début', () async {
      // Régression de coût : sans limite, ouvrir un chat chargeait tout
      // l'historique. Et une limite sur un tri croissant garderait le début.
      await seedMessages(10);

      final messages = await service.watchMessages('alice_bob', limit: 3).first;

      expect(
          messages.map((m) => m.text), ['message 7', 'message 8', 'message 9']);
    });
  });

  group('createMatch', () {
    test('crée un document lisible par la requête de liste', () async {
      final match = await service.createMatch('bob', 'alice');

      expect(match.id, 'alice_bob');

      final matches = await service.watchMatchesForUser('alice').first;
      expect(matches.single.id, 'alice_bob');
    });

    test('rappelé deux fois, il ne duplique rien', () async {
      final first = await service.createMatch('alice', 'bob');
      final second = await service.createMatch('bob', 'alice');

      expect(second.id, first.id);
      expect(second.createdAt, first.createdAt);

      final all = await db.collection('matches').get();
      expect(all.docs, hasLength(1));
    });
  });

  group('recordSwipe et hasLikedMe', () {
    test("hasLikedMe voit le like de l'autre personne", () async {
      await service.recordSwipe(uid: 'bob', targetUid: 'alice', liked: true);

      expect(await service.hasLikedMe(uid: 'alice', targetUid: 'bob'), isTrue);
    });

    test('un rejet ne compte pas comme un like', () async {
      await service.recordSwipe(uid: 'bob', targetUid: 'alice', liked: false);

      expect(await service.hasLikedMe(uid: 'alice', targetUid: 'bob'), isFalse);
    });

    test("aucun swipe du tout n'est pas un like", () async {
      expect(await service.hasLikedMe(uid: 'alice', targetUid: 'bob'), isFalse);
    });
  });

  group('fetchDiscoveryCandidates', () {
    test("exclut l'utilisateur courant de sa propre pile", () async {
      for (final uid in ['alice', 'bob', 'carol']) {
        await db.collection('users').doc(uid).set({
          'name': uid,
          'birthDate': Timestamp.fromDate(DateTime(1995, 1, 1)),
          'gender': 'other',
          'lookingFor': const <String>[],
        });
      }

      final candidates =
          await service.fetchDiscoveryCandidates(excludeUid: 'alice');

      expect(candidates.map((c) => c.uid), isNot(contains('alice')));
      expect(candidates, hasLength(2));
    });
  });

  group('fetchProfiles', () {
    Future<void> seedUser(String uid) => db.collection('users').doc(uid).set({
          'name': uid,
          'birthDate': Timestamp.fromDate(DateTime(1995, 1, 1)),
          'gender': 'other',
          'lookingFor': const <String>[],
        });

    test('charge plusieurs profils en un seul appel', () async {
      await seedUser('bob');
      await seedUser('carol');

      final profiles = await service.fetchProfiles(['bob', 'carol']);

      expect(profiles.keys, containsAll(['bob', 'carol']));
      expect(profiles['bob']!.name, 'bob');
    });

    test('ignore les uids sans profil au lieu de lever', () async {
      await seedUser('bob');

      final profiles = await service.fetchProfiles(['bob', 'fantome']);

      expect(profiles.keys, ['bob']);
    });

    test('une liste vide ne déclenche aucune requête', () async {
      expect(await service.fetchProfiles(const []), isEmpty);
    });

    test('les doublons ne sont demandés qu\'une fois', () async {
      await seedUser('bob');

      final profiles = await service.fetchProfiles(['bob', 'bob', 'bob']);

      expect(profiles, hasLength(1));
    });
  });

  group('profil', () {
    final alice = UserProfile(
      uid: 'alice',
      name: 'Alice',
      birthDate: DateTime(1995, 6, 15),
      gender: Gender.woman,
      lookingFor: const [Gender.man],
      bio: 'Bonjour',
    );

    test('un profil enregistré se relit à l\'identique', () async {
      await service.saveUserProfile(alice);

      expect(await service.fetchUserProfile('alice'), alice);
    });

    test('un profil inexistant renvoie null plutôt que de lever', () async {
      expect(await service.fetchUserProfile('inconnu'), isNull);
    });

    test('watchUserProfile suit les modifications', () async {
      await service.saveUserProfile(alice);

      final stream = service.watchUserProfile('alice');
      expect(await stream.first, alice);
    });
  });
}
