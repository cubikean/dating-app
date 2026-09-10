import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import '../models/user_profile.dart';

/// Toutes les lectures/écritures Firestore passent par ce service.
/// Objectif : garder les widgets et providers ignorants des détails
/// Firestore (chemins de collections, conversion de documents, etc.).
class FirestoreService {
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
  Future<List<UserProfile>> fetchDiscoveryCandidates({
    required String excludeUid,
    int limit = 20,
  }) async {
    final snapshot = await _users.limit(limit + 1).get();
    return snapshot.docs
        .where((doc) => doc.id != excludeUid)
        .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
        .take(limit)
        .toList();
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
        .set({'liked': liked, 'timestamp': FieldValue.serverTimestamp()});
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
      final matches =
          snap.docs.map((d) => MatchModel.fromMap(d.id, d.data())).toList();
      matches.sort((a, b) => (b.lastMessageAt ?? b.createdAt)
          .compareTo(a.lastMessageAt ?? a.createdAt));
      return matches;
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
