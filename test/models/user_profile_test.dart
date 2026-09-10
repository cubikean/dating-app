import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app_boilerplate/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profileBornOn(DateTime birthDate) => UserProfile(
      uid: 'u1',
      name: 'Alice',
      birthDate: birthDate,
      gender: Gender.woman,
      lookingFor: const [Gender.man],
    );

void main() {
  group('UserProfile.age', () {
    // Les dates sont construites à partir d'aujourd'hui, ce qui couvre au
    // passage les bascules d'année : un anniversaire « hier » un 1er janvier
    // tombe en décembre de l'année précédente.
    final now = DateTime.now();

    test('anniversaire passé hier : on a bien son âge', () {
      final yesterday = now.subtract(const Duration(days: 1));
      final born =
          DateTime(yesterday.year - 30, yesterday.month, yesterday.day);
      expect(_profileBornOn(born).age, 30);
    });

    test("anniversaire aujourd'hui : l'âge est déjà incrémenté", () {
      final born = DateTime(now.year - 30, now.month, now.day);
      expect(_profileBornOn(born).age, 30);
    });

    test('anniversaire demain : on a encore un an de moins', () {
      final tomorrow = now.add(const Duration(days: 1));
      final born = DateTime(tomorrow.year - 30, tomorrow.month, tomorrow.day);
      expect(_profileBornOn(born).age, 29);
    });
  });

  group('sérialisation', () {
    test('un aller-retour conserve toutes les valeurs', () {
      final original = UserProfile(
        uid: 'u1',
        name: 'Alice',
        birthDate: DateTime(1995, 6, 15),
        gender: Gender.woman,
        lookingFor: const [Gender.man, Gender.nonBinary],
        bio: 'Bonjour',
        photoUrls: const ['https://exemple.test/1.jpg'],
        interests: const ['escalade'],
        location: const GeoPoint(48.85, 2.35),
        onboardingComplete: true,
      );

      final restored = UserProfile.fromMap('u1', original.toMap());

      expect(restored, original);
    });

    test('un genre inconnu retombe sur « autre » au lieu de planter', () {
      final restored = UserProfile.fromMap('u1', {
        'name': 'Alice',
        'birthDate': Timestamp.fromDate(DateTime(1995, 6, 15)),
        'gender': 'martien',
        'lookingFor': const ['licorne'],
      });

      expect(restored.gender, Gender.other);
      expect(restored.lookingFor, [Gender.other]);
    });

    test('un document vide donne un profil utilisable', () {
      final restored = UserProfile.fromMap('u1', const {});

      expect(restored.name, '');
      expect(restored.photoUrls, isEmpty);
      expect(restored.onboardingComplete, isFalse);
    });
  });
}
