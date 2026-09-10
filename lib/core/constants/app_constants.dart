/// Constantes globales de l'application. Centraliser ici évite les
/// "nombres magiques" éparpillés dans les widgets.
class AppConstants {
  AppConstants._();

  // --- Règles métier ---
  static const int minAge = 18;
  static const int maxAge = 99;
  static const double defaultSearchRadiusKm = 50;
  static const double minSearchRadiusKm = 5;
  static const double maxSearchRadiusKm = 200;
  static const int maxProfilePhotos = 6;

  /// Doit rester aligné sur la limite de taille dans `storage.rules`.
  static const int maxPhotoBytes = 10 * 1024 * 1024;

  // --- Firestore collections ---
  static const String usersCollection = 'users';
  static const String swipesCollection = 'swipes';
  static const String matchesCollection = 'matches';
  static const String messagesSubcollection = 'messages';

  /// Blocages entre deux personnes. L'identifiant du document suit la même
  /// convention que les matchs (les deux uids triés, joints par un underscore),
  /// si bien que pour un match donné, le blocage porte le même identifiant.
  static const String blocksCollection = 'blocks';

  /// Signalements. Écrits par l'application, lus uniquement par la modération.
  static const String reportsCollection = 'reports';

  /// Jetons de notification, un document par appareil connecté.
  static const String devicesSubcollection = 'devices';

  /// Nombre de messages chargés d'emblée dans une conversation, et taille
  /// d'un chargement supplémentaire quand on remonte l'historique.
  static const int messagesPageSize = 50;

  /// Nombre de profils chargés par lot dans la pile de swipe.
  static const int discoveryPageSize = 20;

  // --- UI ---
  static const double defaultPadding = 16;
  static const double cardBorderRadius = 24;
  static const Duration animationDuration = Duration(milliseconds: 250);
}
