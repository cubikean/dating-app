import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_model.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

/// Liste temps réel des matchs de l'utilisateur connecté, triée par
/// dernier message (les conversations actives en premier).
final userMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final me = ref.watch(authStateProvider).valueOrNull;
  if (me == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchMatchesForUser(me.uid);
});
