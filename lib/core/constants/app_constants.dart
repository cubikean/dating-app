/// Constantes globales de l'application. Centraliser ici évite les
/// "nombres magiques" éparpillés dans les widgets.
class AppConstants {
  AppConstants._();

  // --- Règles métier ---
  static const int minAge = 18;
  static const int maxAge = 99;
  static const double defaultSearchRadiusKm = 50;
  static const int maxProfilePhotos = 6;

  /// Doit rester aligné sur la limite de taille dans `storage.rules`.
  static const int maxPhotoBytes = 10 * 1024 * 1024;

  // --- Firestore collections ---
  static const String usersCollection = 'users';
  static const String swipesCollection = 'swipes';
  static const String matchesCollection = 'matches';
  static const String messagesSubcollection = 'messages';

  // --- UI ---
  static const double defaultPadding = 16;
  static const double cardBorderRadius = 24;
  static const Duration animationDuration = Duration(milliseconds: 250);
}
