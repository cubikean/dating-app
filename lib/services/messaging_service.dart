import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';

/// Clé publique de notification web, injectée à la compilation :
/// `flutter run --dart-define=VAPID_PUBLIC_KEY=BN...`
///
/// Elle se génère dans la console Firebase, Paramètres du projet, onglet
/// Cloud Messaging, section « Certificats push Web ». Publique par nature,
/// comme la clé d'API : sortie du code pour rester propre à l'environnement.
const _vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');

/// Enregistrement de l'appareil pour les notifications.
///
/// Un jeton par appareil, rangé sous `users/{uid}/devices/{jeton}` : une même
/// personne peut être connectée sur son téléphone et dans un navigateur, et
/// doit être prévenue sur les deux.
class MessagingService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  MessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  /// Demande l'autorisation puis enregistre le jeton de cet appareil.
  ///
  /// Sans autorisation, on s'arrête sans rien écrire : un jeton enregistré
  /// pour un appareil qui refuse les notifications ferait échouer les envois
  /// et gonflerait la base de jetons morts.
  Future<void> registerDevice(String uid) async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Sur le web, `getToken` exige la clé publique ; ailleurs elle est ignorée.
    if (kIsWeb && _vapidPublicKey.isEmpty) {
      debugPrint(
        'Notifications désactivées sur le web : VAPID_PUBLIC_KEY absente. '
        'Voir la section « Notifications » du README.',
      );
      return;
    }

    final token = await _messaging.getToken(
      vapidKey: _vapidPublicKey.isEmpty ? null : _vapidPublicKey,
    );
    if (token != null) await _saveToken(uid, token);

    // Un jeton peut être remplacé par le système à tout moment ; sans cette
    // écoute, l'appareil cesserait silencieusement de recevoir.
    _messaging.onTokenRefresh.listen((refreshed) => _saveToken(uid, refreshed));
  }

  Future<void> _saveToken(String uid, String token) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.devicesSubcollection)
        .doc(token)
        .set({
      'platform': defaultTargetPlatform.name,
      'isWeb': kIsWeb,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Retire le jeton de cet appareil : après une déconnexion, la personne
  /// suivante à utiliser le téléphone ne doit pas recevoir les messages
  /// destinés à la précédente.
  Future<void> unregisterDevice(String uid) async {
    final token = await _messaging.getToken(
      vapidKey: _vapidPublicKey.isEmpty ? null : _vapidPublicKey,
    );
    if (token == null) return;
    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.devicesSubcollection)
        .doc(token)
        .delete();
  }
}
