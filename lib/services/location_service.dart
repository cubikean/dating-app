import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Position refusée par l'utilisateur ou par le système.
class LocationDeniedException implements Exception {
  final String message;

  const LocationDeniedException(this.message);

  @override
  String toString() => message;
}

/// Accès à la position de l'appareil, isolé pour que le reste du code
/// n'ait à connaître ni les permissions ni le paquet sous-jacent.
class LocationService {
  /// Demande la permission si nécessaire et renvoie la position courante.
  ///
  /// Lève [LocationDeniedException] avec un message lisible plutôt que de
  /// laisser remonter les codes du système : c'est un refus d'utilisateur,
  /// pas une panne, et l'écran doit pouvoir l'expliquer.
  Future<GeoPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationDeniedException(
        'La localisation est désactivée sur cet appareil.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationDeniedException(
        "L'accès à la position a été refusé.",
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationDeniedException(
        "L'accès à la position est bloqué. Il faut le réactiver dans les "
        'réglages du téléphone.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return GeoPoint(position.latitude, position.longitude);
  }
}
