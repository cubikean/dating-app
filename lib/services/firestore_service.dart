import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import '../models/user_profile.dart';

/// Toutes les lectures/écritures Firestore passent par ce service.
/// Objectif : garder les widgets et providers ignorants des détails
/// Firestore (chemins de collections, conversion de documents, etc.).
class FirestoreService {
  /// Nombre maximum de lots lus pour composer une page de découverte, quand
  /// les exclusions vident les premiers lots.
  static const _maxDiscoveryRounds = 5;

  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(AppConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection(AppConstants.matchesCollection);

  // --- Profil utilisateur ---

  Future<void> saveUserProfile(UserProfile profile) {
    return _users
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<UserProfile?> fetchUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(uid, doc.data()!);
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? UserProfile.fromMap(uid, doc.data()!) : null,
        );
  }

  /// Charge plusieurs profils en une fois, indexés par uid.
  ///
  /// Sert aux écrans qui affichent une liste de matchs : ouvrir un flux
  /// temps réel par vignette multipliait les écoutes simultanées pour des
  /// données qui bougent rarement. `whereIn` accepte 30 valeurs par requête,
  /// d'où le découpage.
  Future<Map<String, UserProfile>> fetchProfiles(Iterable<String> uids) async {
    final unique = uids.toSet().toList();
    if (unique.isEmpty) return const {};

    final profiles = <String, UserProfile>{};
    const chunkSize = 30;
    for (var start = 0; start < unique.length; start += chunkSize) {
      final end =
          start + chunkSize < unique.length ? start + chunkSize : unique.length;
      final snapshot = await _users
          .where(FieldPath.documentId, whereIn: unique.sublist(start, end))
          .get();
      for (final doc in snapshot.docs) {
        profiles[doc.id] = UserProfile.fromMap(doc.id, doc.data());
      }
    }
    return profiles;
  }

  /// Renvoie un lot de profils candidats pour le swipe, en excluant
  /// l'utilisateur courant. Pour un vrai algorithme de matching (distance,
  /// préférences, utilisateurs déjà swipés...), remplacer par une Cloud
  /// Function ou une requête composite plus poussée.
  /// Une page de candidats pour le swipe.
  ///
  /// Le filtrage réciproque se fait côté Firestore : le candidat est d'un
  /// genre que [viewer] cherche, et cherche lui-même le genre de [viewer].
  /// Les profils inachevés sont écartés.
  ///
  /// L'exclusion de soi-même et des profils déjà swipés ne s'exprime pas dans
  /// une requête : Firestore ne sait pas écarter une liste arbitraire
  /// d'identifiants. On lit donc par lots jusqu'à remplir la page, en bornant
  /// le nombre d'allers-retours pour ne pas s'emballer sur une base déjà
  /// presque entièrement swipée.
  Future<({List<UserProfile> candidates, String? nextCursor})>
      fetchDiscoveryCandidates({
    required UserProfile viewer,
    Set<String> excludeUids = const {},
    String? startAfterUid,
    int limit = AppConstants.discoveryPageSize,
  }) async {
    // Sans préférence renseignée, aucune requête n'a de sens : `whereIn` sur
    // une liste vide lève une exception.
    if (viewer.lookingFor.isEmpty) {
      return (candidates: const <UserProfile>[], nextCursor: null);
    }

    final wantedGenders = viewer.lookingFor.map((g) => g.name).toList();
    final collected = <UserProfile>[];
    String? cursor = startAfterUid;

    for (var round = 0; round < _maxDiscoveryRounds; round++) {
      var query = _users
          .where('onboardingComplete', isEqualTo: true)
          .where('gender', whereIn: wantedGenders)
          .where('lookingFor', arrayContains: viewer.gender.name)
          .orderBy(FieldPath.documentId)
          .limit(limit);
      if (cursor != null) {
        final cursorDoc = await _users.doc(cursor).get();
        if (!cursorDoc.exists) break;
        query = query.startAfterDocument(cursorDoc);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        return (candidates: collected, nextCursor: null);
      }

      for (final doc in snapshot.docs) {
        cursor = doc.id;
        if (doc.id == viewer.uid || excludeUids.contains(doc.id)) continue;

        // L'âge se filtre ici et non dans la requête : Firestore n'accepte
        // qu'un intervalle par requête, et il est déjà pris par le genre et
        // la réciprocité. Les tours de boucle ci-dessus rattrapent les lots
        // que ce tri vide.
        final candidate = UserProfile.fromMap(doc.id, doc.data());
        if (!viewer.acceptsAgeOf(candidate) ||
            !candidate.acceptsAgeOf(viewer)) {
          continue;
        }
        // La distance se filtre elle aussi ici. Firestore ne sait pas trier
        // par distance : passer à l'échelle demanderait un géohachage et une
        // requête par plage de préfixes, ce qui n'a pas de sens tant que la
        // base tient dans quelques lots.
        if (!viewer.acceptsDistanceOf(candidate) ||
            !candidate.acceptsDistanceOf(viewer)) {
          continue;
        }

        collected.add(candidate);
        if (collected.length >= limit) {
          return (candidates: collected, nextCursor: cursor);
        }
      }

      // Lot incomplet : il n'y a plus rien après.
      if (snapshot.docs.length < limit) {
        return (candidates: collected, nextCursor: null);
      }
    }

    return (candidates: collected, nextCursor: cursor);
  }

  /// Identifiants des profils que [uid] a déjà swipés, dans un sens ou l'autre.
  Future<Set<String>> fetchSwipedUids(String uid) async {
    final snapshot = await _db
        .collection(AppConstants.swipesCollection)
        .doc(uid)
        .collection('actions')
        .get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  // --- Swipes & matchs ---

  Future<void> recordSwipe({
    required String uid,
    required String targetUid,
    required bool liked,
  }) {
    return _db
        .collection(AppConstants.swipesCollection)
        .doc(uid)
        .collection('actions')
        .doc(targetUid)
        .set({
      'liked': liked,
      // Redondant avec l'identifiant du document, mais indispensable : la
      // suppression de compte doit retrouver les swipes que les autres ont
      // posés sur une personne, ce qui suppose de pouvoir filtrer dessus.
      'targetUid': targetUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Vérifie si `targetUid` a déjà liké `uid` (= match réciproque).
  Future<bool> hasLikedMe(
      {required String uid, required String targetUid}) async {
    final doc = await _db
        .collection(AppConstants.swipesCollection)
        .doc(targetUid)
        .collection('actions')
        .doc(uid)
        .get();
    return doc.exists && (doc.data()?['liked'] as bool? ?? false);
  }

  Future<MatchModel> createMatch(String uidA, String uidB) async {
    final id = MatchModel.buildId(uidA, uidB);
    final ref = _matches.doc(id);
    final existing = await ref.get();
    if (existing.exists) {
      return MatchModel.fromMap(id, existing.data()!);
    }
    final match = MatchModel(
      id: id,
      userIds: [uidA, uidB],
      createdAt: DateTime.now(),
    );
    await ref.set(match.toMap());
    return match;
  }

  /// Matchs de l'utilisateur, du plus récemment actif au plus ancien.
  ///
  /// Le tri est volontairement fait côté client : un `orderBy` Firestore
  /// exclut silencieusement les documents où le champ de tri est absent
  /// (donc tout match sans message), et impose en plus un index composite.
  /// La requête ramène de toute façon tous les matchs de l'utilisateur,
  /// dont le nombre reste petit, donc trier ici ne coûte rien de plus.
  Stream<List<MatchModel>> watchMatchesForUser(String uid) {
    return _matches.where('users', arrayContains: uid).snapshots().map((snap) {
      final matches = snap.docs
          .map((d) => MatchModel.fromMap(d.id, d.data()))
          .where((match) => !match.isEnded)
          .toList();
      matches.sort((a, b) => (b.lastMessageAt ?? b.createdAt)
          .compareTo(a.lastMessageAt ?? a.createdAt));
      return matches;
    });
  }

  /// Retire [uid] du match : la conversation disparaît des deux côtés et
  /// personne ne peut plus y écrire.
  ///
  /// Le document est marqué plutôt que supprimé. Les messages vivent dans une
  /// sous-collection, qu'une suppression laisserait orpheline, et un match
  /// rompu reste une pièce utile en cas de signalement.
  Future<void> endMatch({required String matchId, required String uid}) {
    return _matches.doc(matchId).update({
      'endedAt': Timestamp.fromDate(DateTime.now()),
      'endedBy': uid,
    });
  }

  // --- Signalement et blocage ---

  /// Bloque [targetUid]. Le document porte l'identifiant de paire, celui-là
  /// même qu'utiliserait leur match : les règles peuvent donc vérifier
  /// l'existence d'un blocage à partir du seul `matchId`.
  Future<void> blockUser({
    required String uid,
    required String targetUid,
  }) {
    final id = MatchModel.buildId(uid, targetUid);
    return _db.collection(AppConstants.blocksCollection).doc(id).set({
      'users': [uid, targetUid]..sort(),
      'blockedBy': uid,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Retire un blocage. Seule la personne qui l'a posé peut le lever.
  Future<void> unblockUser({
    required String uid,
    required String targetUid,
  }) {
    final id = MatchModel.buildId(uid, targetUid);
    return _db.collection(AppConstants.blocksCollection).doc(id).delete();
  }

  /// Personnes bloquées, dans un sens ou dans l'autre : un blocage coupe le
  /// lien pour les deux, celui qui bloque comme celui qui est bloqué.
  Stream<Set<String>> watchBlockedUids(String uid) {
    return _db
        .collection(AppConstants.blocksCollection)
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .expand((doc) => List<String>.from(doc.data()['users'] as List))
            .where((other) => other != uid)
            .toSet());
  }

  /// Enregistre un signalement. Écriture seule : personne ne relit ces
  /// documents depuis l'application, la modération passe par la console.
  Future<void> reportUser({
    required String reporterUid,
    required String reportedUid,
    required String reason,
    String? matchId,
  }) {
    return _db.collection(AppConstants.reportsCollection).add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      if (matchId != null) 'matchId': matchId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // --- Messagerie ---

  /// Les `limit` messages les plus récents, rendus du plus ancien au plus
  /// récent pour l'affichage.
  ///
  /// Le tri se fait en décroissant côté Firestore pour que la limite garde
  /// la fin de la conversation : sans elle, ouvrir un chat chargeait tout
  /// l'historique depuis le premier message.
  Stream<List<MessageModel>> watchMessages(
    String matchId, {
    int limit = AppConstants.messagesPageSize,
  }) {
    return _matches
        .doc(matchId)
        .collection(AppConstants.messagesSubcollection)
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.reversed
            .map((d) => MessageModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> sendMessage({
    required String matchId,
    required String senderId,
    required String text,
  }) {
    final matchRef = _matches.doc(matchId);
    final messageRef =
        matchRef.collection(AppConstants.messagesSubcollection).doc();
    final now = Timestamp.fromDate(DateTime.now());

    // Les deux écritures partent ensemble. Séparées, un message pouvait être
    // enregistré sans que le match soit mis à jour, laissant la liste des
    // conversations sur un aperçu périmé et dans le mauvais ordre.
    final batch = _db.batch();
    batch.set(messageRef, {
      'senderId': senderId,
      'text': text,
      'sentAt': now,
    });
    batch.update(matchRef, {
      'lastMessage': text,
      'lastMessageAt': now,
    });
    return batch.commit();
  }
}
