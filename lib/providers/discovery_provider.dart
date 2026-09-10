import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_model.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

/// État de la pile de découverte : la liste de candidats restants à swiper.
class DiscoveryState {
  final List<UserProfile> candidates;
  final bool isLoading;
  final MatchModel?
      newMatch; // non-null juste après un match, pour afficher un overlay
  final Object? error; // non-null si le dernier chargement/swipe a échoué

  const DiscoveryState({
    this.candidates = const [],
    this.isLoading = false,
    this.newMatch,
    this.error,
  });

  DiscoveryState copyWith({
    List<UserProfile>? candidates,
    bool? isLoading,
    MatchModel? newMatch,
    bool clearNewMatch = false,
    Object? error,
    bool clearError = false,
  }) {
    return DiscoveryState(
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      newMatch: clearNewMatch ? null : (newMatch ?? this.newMatch),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DiscoveryController extends StateNotifier<DiscoveryState> {
  final Ref _ref;

  DiscoveryController(this._ref) : super(const DiscoveryState()) {
    loadCandidates();
  }

  Future<void> loadCandidates() async {
    final me = _ref.read(authStateProvider).valueOrNull;
    if (me == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    // Sans ce try/catch, une erreur Firestore (règles, index, réseau) laissait
    // l'écran bloqué sur le spinner, sans message à copier ni à lire.
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      final candidates =
          await firestore.fetchDiscoveryCandidates(excludeUid: me.uid);
      state = state.copyWith(candidates: candidates, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  /// Appelé quand l'utilisateur swipe à droite (like) ou à gauche (pass).
  /// Si le candidat nous a déjà likés, un match est créé.
  Future<void> swipe(UserProfile candidate, {required bool liked}) async {
    final me = _ref.read(authStateProvider).valueOrNull;
    if (me == null) return;

    try {
      final firestore = _ref.read(firestoreServiceProvider);
      await firestore.recordSwipe(
        uid: me.uid,
        targetUid: candidate.uid,
        liked: liked,
      );

      state = state.copyWith(
        candidates:
            state.candidates.where((c) => c.uid != candidate.uid).toList(),
      );

      if (!liked) return;

      final theyLikedMe = await firestore.hasLikedMe(
        uid: me.uid,
        targetUid: candidate.uid,
      );
      if (theyLikedMe) {
        final match = await firestore.createMatch(me.uid, candidate.uid);
        state = state.copyWith(newMatch: match);
      }
    } catch (error) {
      state = state.copyWith(error: error);
    }
  }

  void dismissMatchOverlay() => state = state.copyWith(clearNewMatch: true);
}

final discoveryControllerProvider =
    StateNotifierProvider<DiscoveryController, DiscoveryState>((ref) {
  return DiscoveryController(ref);
});
