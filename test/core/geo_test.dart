import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app_boilerplate/core/utils/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Coordonnées réelles : une erreur de formule se voit tout de suite en
  // comparant à une distance connue.
  const paris = GeoPoint(48.8566, 2.3522);
  const lyon = GeoPoint(45.7640, 4.8357);
  const londres = GeoPoint(51.5074, -0.1278);

  group('distanceKmBetween', () {
    test('Paris–Lyon fait environ 392 km', () {
      expect(distanceKmBetween(paris, lyon), closeTo(392, 5));
    });

    test('Paris–Londres fait environ 344 km', () {
      expect(distanceKmBetween(paris, londres), closeTo(344, 5));
    });

    test('un point est à zéro de lui-même', () {
      expect(distanceKmBetween(paris, paris), closeTo(0, 0.001));
    });

    test('la distance est symétrique', () {
      expect(
        distanceKmBetween(paris, lyon),
        closeTo(distanceKmBetween(lyon, paris), 0.001),
      );
    });

    test('le passage du méridien de Greenwich ne casse rien', () {
      // Longitudes de signes opposés : le cas où une soustraction naïve
      // donnerait un écart absurde.
      const ouest = GeoPoint(51.5, -0.5);
      const est = GeoPoint(51.5, 0.5);
      expect(distanceKmBetween(ouest, est), closeTo(69, 2));
    });
  });
}
