import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/messaging_service.dart';
import 'auth_provider.dart';

final messagingServiceProvider =
    Provider<MessagingService>((ref) => MessagingService());

/// Enregistre l'appareil dès qu'une session s'ouvre, et une seule fois par
/// utilisateur : sans le test sur l'uid précédent, chaque émission du flux
/// d'authentification relancerait une demande de permission.
final deviceRegistrationProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<Object?>>(
    authStateProvider,
    (previous, next) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;
      if (previous?.valueOrNull != null) return;
      ref.read(messagingServiceProvider).registerDevice(uid);
    },
    fireImmediately: true,
  );
});

/// Messages reçus alors que l'application est au premier plan. Le système
/// n'affiche rien dans ce cas : c'est à l'application de le faire.
final foregroundMessageProvider = StreamProvider<RemoteMessage>((ref) {
  return FirebaseMessaging.onMessage;
});
