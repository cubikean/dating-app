import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'profile_provider.dart';

/// Personnes bloquées, dans un sens ou dans l'autre : celles que l'utilisateur
/// a bloquées comme celles qui l'ont bloqué. Un blocage coupe le lien pour les
/// deux, sans dire à la personne bloquée qu'elle l'a été.
final blockedUidsProvider = StreamProvider<Set<String>>((ref) {
  final me = ref.watch(authStateProvider).valueOrNull;
  if (me == null) return Stream.value(const <String>{});
  return ref.watch(firestoreServiceProvider).watchBlockedUids(me.uid);
});

/// Actions de sécurité : bloquer, débloquer, signaler.
class SafetyController {
  final Ref _ref;

  SafetyController(this._ref);

  Future<void> block(String targetUid) {
    final me = _ref.read(authStateProvider).valueOrNull;
    if (me == null) return Future.value();
    return _ref
        .read(firestoreServiceProvider)
        .blockUser(uid: me.uid, targetUid: targetUid);
  }

  Future<void> unblock(String targetUid) {
    final me = _ref.read(authStateProvider).valueOrNull;
    if (me == null) return Future.value();
    return _ref
        .read(firestoreServiceProvider)
        .unblockUser(uid: me.uid, targetUid: targetUid);
  }

  /// Se retirer d'un match, sans bloquer la personne.
  Future<void> endMatch(String matchId) {
    final me = _ref.read(authStateProvider).valueOrNull;
    if (me == null) return Future.value();
    return _ref
        .read(firestoreServiceProvider)
        .endMatch(matchId: matchId, uid: me.uid);
  }

  Future<void> report({
    required String targetUid,
    required String reason,
    String? matchId,
  }) {
    final me = _ref.read(authStateProvider).valueOrNull;
    if (me == null) return Future.value();
    return _ref.read(firestoreServiceProvider).reportUser(
          reporterUid: me.uid,
          reportedUid: targetUid,
          reason: reason,
          matchId: matchId,
        );
  }
}

final safetyControllerProvider =
    Provider<SafetyController>((ref) => SafetyController(ref));
