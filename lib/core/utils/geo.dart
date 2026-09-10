import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Rayon moyen de la Terre, en kilomètres.
const _earthRadiusKm = 6371.0;

/// Distance en kilomètres entre deux points, par la formule de haversine.
///
/// Écrite ici plutôt qu'empruntée au paquet de géolocalisation : c'est du
/// calcul pur, qui doit rester testable sans plateforme ni permission.
/// L'approximation sphérique suffit largement à un rayon de recherche.
double distanceKmBetween(GeoPoint a, GeoPoint b) {
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLon = _toRadians(b.longitude - a.longitude);
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);

  final h = math.pow(math.sin(dLat / 2), 2) +
      math.pow(math.sin(dLon / 2), 2) * math.cos(lat1) * math.cos(lat2);

  return 2 * _earthRadiusKm * math.asin(math.sqrt(h));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
