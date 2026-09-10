import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app_boilerplate/models/match_model.dart';
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

    test('le swipe porte la cible en clair, pour la suppression de compte',
        () async {
      // La fonction Cloud retrouve les swipes reçus par une requête de groupe
      // sur ce champ : sans lui, ils survivraient à la suppression du compte.
      await service.recordSwipe(uid: 'bob', targetUid: 'alice', liked: true);

      final doc = await db.collection('swipes/bob/actions').doc('alice').get();

      expect(doc.data()!['targetUid'], 'alice');
    });

    test("aucun swipe du tout n'est pas un like", () async {
      expect(await service.hasLikedMe(uid: 'alice', targetUid: 'bob'), isFalse);
    });
  });

  group('fetchDiscoveryCandidates', () {
    Future<void> seedUser(
      String uid, {
      required String gender,
      required List<String> lookingFor,
      bool onboardingComplete = true,
      int age = 30,
      int ageMin = 18,
      int ageMax = 99,
      GeoPoint? location,
      double searchRadiusKm = 50,
    }) {
      return db.collection('users').doc(uid).set({
        'name': uid,
        // Né un 1er janvier : l'anniversaire est toujours passé, donc l'âge
        // vaut exactement `age` quel que soit le jour où le test tourne.
        'birthDate':
            Timestamp.fromDate(DateTime(DateTime.now().year - age, 1, 1)),
        'gender': gender,
        'lookingFor': lookingFor,
        'onboardingComplete': onboardingComplete,
        'ageMin': ageMin,
        'ageMax': ageMax,
        'searchRadiusKm': searchRadiusKm,
        if (location != null) 'location': location,
      });
    }

    final alice = UserProfile(
      uid: 'alice',
      name: 'Alice',
      birthDate: DateTime(DateTime.now().year - 30, 1, 1),
      gender: Gender.woman,
      lookingFor: const [Gender.man],
      onboardingComplete: true,
    );

    test('le filtrage est réciproque, pas seulement à sens unique', () async {
      await seedUser('bob', gender: 'man', lookingFor: ['woman']);
      await seedUser('dan', gender: 'man', lookingFor: ['man']);
      await seedUser('eve', gender: 'woman', lookingFor: ['woman']);

      final page = await service.fetchDiscoveryCandidates(viewer: alice);

      // dan est du bon genre mais ne cherche pas de femmes ; eve cherche des
      // femmes mais n'est pas du genre recherché par alice.
      expect(page.candidates.map((c) => c.uid), ['bob']);
    });

    test('écarte les profils dont le questionnaire est inachevé', () async {
      await seedUser('bob',
          gender: 'man', lookingFor: ['woman'], onboardingComplete: false);

      final page = await service.fetchDiscoveryCandidates(viewer: alice);

      expect(page.candidates, isEmpty);
    });

    test('ne se propose jamais à soi-même', () async {
      final narcissa = UserProfile(
        uid: 'narcissa',
        name: 'Narcissa',
        birthDate: DateTime(1995, 1, 1),
        gender: Gender.woman,
        lookingFor: const [Gender.woman],
        onboardingComplete: true,
      );
      await seedUser('narcissa', gender: 'woman', lookingFor: ['woman']);
      await seedUser('eve', gender: 'woman', lookingFor: ['woman']);

      final page = await service.fetchDiscoveryCandidates(viewer: narcissa);

      expect(page.candidates.map((c) => c.uid), ['eve']);
    });

    test('ne repropose pas un profil déjà swipé', () async {
      await seedUser('bob', gender: 'man', lookingFor: ['woman']);
      await seedUser('carl', gender: 'man', lookingFor: ['woman']);

      final page = await service
          .fetchDiscoveryCandidates(viewer: alice, excludeUids: {'bob'});

      expect(page.candidates.map((c) => c.uid), ['carl']);
    });

    test("un candidat hors de ma tranche d'âge est écarté", () async {
      await seedUser('bob', gender: 'man', lookingFor: ['woman'], age: 45);
      await seedUser('carl', gender: 'man', lookingFor: ['woman'], age: 30);

      final page = await service.fetchDiscoveryCandidates(
        viewer: alice.copyWith(ageMin: 25, ageMax: 35),
      );

      expect(page.candidates.map((c) => c.uid), ['carl']);
    });

    test("le filtre par âge joue aussi dans l'autre sens", () async {
      // Alice a 30 ans. Dan n'en cherche pas plus de 25 : la proposer à Alice
      // reviendrait à lui montrer un profil qui ne la verra jamais.
      await seedUser('dan',
          gender: 'man',
          lookingFor: ['woman'],
          age: 24,
          ageMin: 18,
          ageMax: 25);
      await seedUser('carl', gender: 'man', lookingFor: ['woman'], age: 30);

      final page = await service.fetchDiscoveryCandidates(viewer: alice);

      expect(page.candidates.map((c) => c.uid), ['carl']);
    });

    test("un profil au-delà du rayon est écarté", () async {
      const paris = GeoPoint(48.8566, 2.3522);
      const lyon = GeoPoint(45.7640, 4.8357);

      await seedUser('bob',
          gender: 'man', lookingFor: ['woman'], location: lyon);
      await seedUser('carl',
          gender: 'man', lookingFor: ['woman'], location: paris);

      final page = await service.fetchDiscoveryCandidates(
        viewer: alice.copyWith(location: paris, searchRadiusKm: 50),
      );

      // Lyon est a près de 400 km de Paris.
      expect(page.candidates.map((c) => c.uid), ['carl']);
    });

    test("le rayon joue aussi dans l'autre sens", () async {
      const paris = GeoPoint(48.8566, 2.3522);
      const lyon = GeoPoint(45.7640, 4.8357);

      // Alice cherche large, Bob non : le proposér reviendrait a montrer un
      // profil qui ne la verra jamais en retour.
      await seedUser('bob',
          gender: 'man',
          lookingFor: ['woman'],
          location: lyon,
          searchRadiusKm: 20);

      final page = await service.fetchDiscoveryCandidates(
        viewer: alice.copyWith(location: paris, searchRadiusKm: 500),
      );

      expect(page.candidates, isEmpty);
    });

    test('sans position connue, le profil reste proposé', () async {
      // Sinon la pile se viderait de tous ceux qui n'ont pas encore partagé
      // leur position, y compris les profils créés avant cette fonction.
      await seedUser('bob', gender: 'man', lookingFor: ['woman']);

      final page = await service.fetchDiscoveryCandidates(
        viewer: alice.copyWith(
          location: const GeoPoint(48.8566, 2.3522),
          searchRadiusKm: 5,
        ),
      );

      expect(page.candidates.map((c) => c.uid), ['bob']);
    });

    test('sans préférence renseignée, la pile reste vide', () async {
      await seedUser('bob', gender: 'man', lookingFor: ['woman']);

      final page = await service.fetchDiscoveryCandidates(
        viewer: alice.copyWith(lookingFor: const []),
      );

      expect(page.candidates, isEmpty);
      expect(page.nextCursor, isNull);
    });

    // `fake_cloud_firestore` renvoie une page vide dès qu'un `startAfterDocument`
    // est combiné à une clause `where`, quelle qu'elle soit. Vérifié à part : la
    // pagination seule fonctionne, les filtres seuls aussi, leur combinaison non.
    // La requête est correcte pour le vrai Firestore, c'est la simulation qui ne
    // suit pas. À rejouer sur l'émulateur si la pagination devient critique.
    test('le curseur reprend là où le lot précédent s\'est arrêté', skip: true,
        () async {
      for (final uid in ['bob', 'carl', 'dave']) {
        await seedUser(uid, gender: 'man', lookingFor: ['woman']);
      }

      final first =
          await service.fetchDiscoveryCandidates(viewer: alice, limit: 2);
      expect(first.candidates.map((c) => c.uid), ['bob', 'carl']);
      expect(first.nextCursor, 'carl');

      final second = await service.fetchDiscoveryCandidates(
        viewer: alice,
        limit: 2,
        startAfterUid: first.nextCursor,
      );
      expect(second.candidates.map((c) => c.uid), ['dave']);
      expect(second.nextCursor, isNull);
    });
  });

  group('fetchSwipedUids', () {
    test('renvoie les profils vus, likés comme rejetés', () async {
      await service.recordSwipe(uid: 'alice', targetUid: 'bob', liked: true);
      await service.recordSwipe(uid: 'alice', targetUid: 'carl', liked: false);
      await service.recordSwipe(uid: 'bob', targetUid: 'dave', liked: true);

      expect(await service.fetchSwipedUids('alice'), {'bob', 'carl'});
    });

    test('personne de swipé, ensemble vide', () async {
      expect(await service.fetchSwipedUids('alice'), isEmpty);
    });
  });

  group('endMatch', () {
    setUp(() => seedMatch('alice_bob',
        users: ['alice', 'bob'], createdAt: DateTime(2026, 9, 1)));

    test('un match rompu disparaît des deux listes', () async {
      await service.endMatch(matchId: 'alice_bob', uid: 'alice');

      expect(await service.watchMatchesForUser('alice').first, isEmpty);
      expect(await service.watchMatchesForUser('bob').first, isEmpty);
    });

    test('le document reste en base, avec qui a rompu', () async {
      // Les messages vivent sous ce document : le supprimer les laisserait
      // orphelins, et un match rompu sert encore a la modération.
      await service.endMatch(matchId: 'alice_bob', uid: 'alice');

      final stored = await db.collection('matches').doc('alice_bob').get();

      expect(stored.exists, isTrue);
      expect(stored.data()!['endedBy'], 'alice');
      expect(stored.data()!['endedAt'], isA<Timestamp>());
    });

    test('les autres matchs ne sont pas touchés', () async {
      await seedMatch('alice_carol',
          users: ['alice', 'carol'], createdAt: DateTime(2026, 9, 2));

      await service.endMatch(matchId: 'alice_bob', uid: 'alice');

      final matches = await service.watchMatchesForUser('alice').first;
      expect(matches.map((m) => m.id), ['alice_carol']);
    });
  });

  group('blocage', () {
    test('le document porte le même identifiant que le match', () async {
      // Invariant dont dépendent les règles de sécurité : elles vérifient
      // l'existence d'un blocage à partir du seul identifiant de match.
      await service.blockUser(uid: 'alice', targetUid: 'bob');

      final match = await service.createMatch('alice', 'bob');
      final block = await db
          .collection('blocks')
          .doc(MatchModel.buildId('alice', 'bob'))
          .get();

      expect(block.exists, isTrue);
      expect(block.id, match.id);
    });

    test("l'auteur du blocage est enregistré", () async {
      await service.blockUser(uid: 'alice', targetUid: 'bob');

      final block = await db.collection('blocks').doc('alice_bob').get();

      expect(block.data()!['blockedBy'], 'alice');
      expect(block.data()!['users'], ['alice', 'bob']);
    });

    test('le blocage vaut dans les deux sens', () async {
      // Alice bloque Bob : Bob doit disparaître pour Alice, et Alice pour Bob.
      await service.blockUser(uid: 'alice', targetUid: 'bob');

      expect(await service.watchBlockedUids('alice').first, {'bob'});
      expect(await service.watchBlockedUids('bob').first, {'alice'});
    });

    test('un blocage entre tiers ne concerne personne d\'autre', () async {
      await service.blockUser(uid: 'bob', targetUid: 'carol');

      expect(await service.watchBlockedUids('alice').first, isEmpty);
    });

    test('lever le blocage rétablit le lien', () async {
      await service.blockUser(uid: 'alice', targetUid: 'bob');
      await service.unblockUser(uid: 'alice', targetUid: 'bob');

      expect(await service.watchBlockedUids('alice').first, isEmpty);
      expect(await service.watchBlockedUids('bob').first, isEmpty);
    });

    test("l'ordre des arguments ne change pas le document visé", () async {
      await service.blockUser(uid: 'bob', targetUid: 'alice');
      await service.unblockUser(uid: 'alice', targetUid: 'bob');

      expect(await service.watchBlockedUids('alice').first, isEmpty);
    });
  });

  group('signalement', () {
    test('le signalement retient qui, contre qui et pourquoi', () async {
      await service.reportUser(
        reporterUid: 'alice',
        reportedUid: 'bob',
        reason: 'Harcèlement ou insultes',
        matchId: 'alice_bob',
      );

      final reports = await db.collection('reports').get();
      final data = reports.docs.single.data();

      expect(data['reporterUid'], 'alice');
      expect(data['reportedUid'], 'bob');
      expect(data['reason'], 'Harcèlement ou insultes');
      expect(data['matchId'], 'alice_bob');
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('un signalement hors conversation omet le match', () async {
      await service.reportUser(
        reporterUid: 'alice',
        reportedUid: 'bob',
        reason: 'Faux profil ou usurpation',
      );

      final reports = await db.collection('reports').get();

      expect(reports.docs.single.data().containsKey('matchId'), isFalse);
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
