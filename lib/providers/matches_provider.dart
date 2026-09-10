import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_model.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

/// Liste temps réel des matchs de l'utilisateur connecté, triée par
/// dernier message (les conversations actives en premier).
final userMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final me = ref.watch(authStateProvider).valueOrNull;
  if (me == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchMatchesForUser(me.uid);
});

/// Profils des personnes avec qui on a matché, indexés par uid.
///
/// Chargés en un seul appel groupé pour toute la liste. Auparavant chaque
/// vignette ouvrait son propre flux temps réel, soit autant d'écoutes
/// simultanées que de matchs, pour des données qui changent rarement.
final matchProfilesProvider =
    FutureProvider<Map<String, UserProfile>>((ref) async {
  final me = ref.watch(authStateProvider).valueOrNull;
  final matches = ref.watch(userMatchesProvider).valueOrNull;
  if (me == null || matches == null || matches.isEmpty) return const {};

  return ref
      .watch(firestoreServiceProvider)
      .fetchProfiles(matches.map((match) => match.otherUserId(me.uid)));
});

/// Un match précis, pris dans la liste déjà ouverte : pas de lecture en plus.
final matchByIdProvider = Provider.family<MatchModel?, String>((ref, matchId) {
  final matches = ref.watch(userMatchesProvider).valueOrNull;
  if (matches == null) return null;
  for (final match in matches) {
    if (match.id == matchId) return match;
  }
  return null;
});
