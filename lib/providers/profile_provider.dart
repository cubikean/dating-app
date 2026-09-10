import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'auth_provider.dart';

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Profil de l'utilisateur connecté, tenu à jour en temps réel depuis
/// Firestore. `null` tant qu'il n'a pas encore complété l'onboarding.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  if (authState == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchUserProfile(authState.uid);
});

class ProfileController {
  final FirestoreService _firestoreService;

  ProfileController(this._firestoreService);

  Future<void> save(UserProfile profile) {
    return _firestoreService.saveUserProfile(profile);
  }
}

final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(ref.watch(firestoreServiceProvider));
});
