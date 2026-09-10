import 'package:cloud_functions/cloud_functions.dart';

/// Doit rester identique à la région déclarée dans `functions/src/index.ts`,
/// sans quoi l'appel part vers une fonction qui n'existe pas.
const functionsRegion = 'europe-west1';

/// Opérations de compte confiées à une fonction Cloud.
class AccountService {
  final FirebaseFunctions _functions;

  AccountService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  /// Efface définitivement le compte et tout ce qui s'y rattache.
  ///
  /// Le travail ne peut pas se faire depuis l'application : effacer un compte
  /// suppose de supprimer des documents qui appartiennent à d'autres, comme
  /// les swipes posés sur cette personne ou les conversations partagées.
  Future<void> deleteAccount() {
    return _functions.httpsCallable('deleteAccount').call<void>();
  }
}
