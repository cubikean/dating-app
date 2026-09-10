import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Clé de site reCAPTCHA v3, injectée à la compilation :
/// `flutter run --dart-define=RECAPTCHA_SITE_KEY=6Lxxxxxxxxxxxx`
///
/// Ce n'est pas un secret — elle est publique par nature, comme la clé d'API
/// Firebase. Elle est sortie du code pour rester propre à chaque environnement.
const _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Active App Check, qui atteste que les requêtes viennent bien de cette
/// application et non d'un script appelant l'API avec la clé publique.
///
/// Tant que l'application des règles n'est pas activée dans la console, ceci
/// ne bloque rien : les jetons sont seulement collectés, ce qui permet de
/// vérifier dans les statistiques que le trafic légitime est bien attesté
/// avant de fermer la porte.
Future<void> activateAppCheck() async {
  if (kIsWeb && _recaptchaSiteKey.isEmpty) {
    // Sans clé, l'activation web échoue. On préfère démarrer sans App Check
    // plutôt que d'empêcher l'application de se lancer.
    debugPrint(
      'App Check désactivé sur le web : RECAPTCHA_SITE_KEY absente. '
      'Voir la section « App Check » du README.',
    );
    return;
  }

  await FirebaseAppCheck.instance.activate(
    webProvider: _recaptchaSiteKey.isEmpty
        ? null
        : ReCaptchaV3Provider(_recaptchaSiteKey),
    // En développement, le fournisseur de débogage imprime un jeton à coller
    // dans la console Firebase. En production, l'attestation vient du système.
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );
}
