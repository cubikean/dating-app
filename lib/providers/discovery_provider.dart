import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_model.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';
import 'safety_provider.dart';

/// État de la pile de découverte : la liste de candidats restants à swiper.
class DiscoveryState {
  final List<UserProfile> candidates;
  final bool isLoading;
  final MatchModel?
      newMatch; // non-null juste après un match, pour afficher un overlay
  final Object? error; // non-null si le dernier chargement/swipe a échoué
  final String? nextCursor; // dernier uid lu, pour reprendre la pagination
  final Set<String> swipedUids; // profils déjà vus, à ne plus proposer

  const DiscoveryState({
    this.candidates = const [],
    this.isLoading = false,
    this.newMatch,
    this.error,
    this.nextCursor,
    this.swipedUids = const {},
  });

  bool get hasMore => nextCursor != null;

  DiscoveryState copyWith({
    List<UserProfile>? candidates,
    bool? isLoading,
    MatchModel? newMatch,
    bool clearNewMatch = false,
    Object? error,
    bool clearError = false,
    String? nextCursor,
    bool clearCursor = false,
    Set<String>? swipedUids,
  }) {
    return DiscoveryState(
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      newMatch: clearNewMatch ? null : (newMatch ?? this.newMatch),
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      swipedUids: swipedUids ?? this.swipedUids,
    );
  }
}

class DiscoveryController extends StateNotifier<DiscoveryState> {
  /// En dessous de ce nombre de cartes restantes, on va chercher le lot
  /// suivant, pour que la pile ne se vide pas sous les doigts.
  static const _refillThreshold = 3;

  final Ref _ref;

  /// Personnes bloquées, à ne jamais proposer dans la pile.
  Set<String> get _blockedUids =>
      _ref.read(blockedUidsProvider).valueOrNull ?? const {};

  DiscoveryController(this._ref) : super(const DiscoveryState()) {
    // La pile dépend des préférences de l'utilisateur, qui arrivent de
    // Firestore : on attend que son profil soit chargé avant de composer.
    _ref.listen<AsyncValue<UserProfile?>>(
      currentUserProfileProvider,
      (previous, next) {
        if (previous?.valueOrNull == null && next.valueOrNull != null) {
          Future.microtask(loadCandidates);
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> loadCandidates() async {
    final me = _ref.read(authStateProvider).valueOrNull;
    final myProfile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (me == null || myProfile == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    // Sans ce try/catch, une erreur Firestore (règles, index, réseau) laissait
    // l'écran bloqué sur le spinner, sans message à copier ni à lire.
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      final swiped = await firestore.fetchSwipedUids(me.uid);
      final page = await firestore.fetchDiscoveryCandidates(
        viewer: myProfile,
        excludeUids: {...swiped, ..._blockedUids},
      );
      state = state.copyWith(
        candidates: page.candidates,
        swipedUids: swiped,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  /// Ajoute le lot suivant sans vider la pile en cours.
  Future<void> loadMore() async {
    final myProfile = _ref.read(currentUserProfileProvider).valueOrNull;
    final cursor = state.nextCursor;
    if (myProfile == null || cursor == null || state.isLoading) return;

    try {
      final page =
          await _ref.read(firestoreServiceProvider).fetchDiscoveryCandidates(
                viewer: myProfile,
                excludeUids: {
                  ...state.swipedUids,
                  ..._blockedUids,
                  ...state.candidates.map((candidate) => candidate.uid),
                },
                startAfterUid: cursor,
              );
      state = state.copyWith(
        candidates: [...state.candidates, ...page.candidates],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
      );
    } catch (error) {
      state = state.copyWith(error: error);
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
        swipedUids: {...state.swipedUids, candidate.uid},
      );

      if (state.candidates.length <= _refillThreshold && state.hasMore) {
        unawaited(loadMore());
      }

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
