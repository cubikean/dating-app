import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/geo.dart';

enum Gender { woman, man, nonBinary, other }

/// Profil utilisateur tel que stocké dans `users/{uid}`.
class UserProfile extends Equatable {
  final String uid;
  final String name;
  final DateTime birthDate;
  final Gender gender;
  final List<Gender> lookingFor;
  final String bio;
  final List<String> photoUrls;
  final List<String> interests;
  final GeoPoint? location;
  final bool onboardingComplete;

  /// Tranche d'âge recherchée. Bornes incluses.
  final int ageMin;
  final int ageMax;

  /// Rayon de recherche, en kilomètres.
  final double searchRadiusKm;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.lookingFor,
    this.bio = '',
    this.photoUrls = const [],
    this.interests = const [],
    this.location,
    this.onboardingComplete = false,
    this.ageMin = AppConstants.minAge,
    this.ageMax = AppConstants.maxAge,
    this.searchRadiusKm = AppConstants.defaultSearchRadiusKm,
  });

  /// Vrai si [other] entre dans la tranche d'âge recherchée.
  ///
  /// La découverte exige la réciprocité : chacun doit entrer dans la tranche
  /// de l'autre, sans quoi l'un des deux verrait des profils qui ne le
  /// verront jamais en retour.
  bool acceptsAgeOf(UserProfile other) =>
      other.age >= ageMin && other.age <= ageMax;

  /// Distance jusqu'à [other], ou `null` si l'un des deux n'a pas de position.
  double? distanceKmTo(UserProfile other) {
    final mine = location;
    final theirs = other.location;
    if (mine == null || theirs == null) return null;
    return distanceKmBetween(mine, theirs);
  }

  /// Vrai si [other] tombe dans le rayon de recherche.
  ///
  /// Sans position connue de part ou d'autre, on répond vrai : mieux vaut
  /// proposer un profil dont on ignore la distance que vider la pile de
  /// tous ceux qui n'ont pas encore partagé leur position.
  bool acceptsDistanceOf(UserProfile other) {
    final distance = distanceKmTo(other);
    return distance == null || distance <= searchRadiusKm;
  }

  int get age {
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    final hasHadBirthdayThisYear = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) years -= 1;
    return years;
  }

  factory UserProfile.empty(String uid) => UserProfile(
        uid: uid,
        name: '',
        birthDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
        gender: Gender.other,
        lookingFor: const [],
      );

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      birthDate: (map['birthDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gender: Gender.values.firstWhere(
        (g) => g.name == map['gender'],
        orElse: () => Gender.other,
      ),
      lookingFor: ((map['lookingFor'] as List?) ?? [])
          .map((g) => Gender.values
              .firstWhere((e) => e.name == g, orElse: () => Gender.other))
          .toList(),
      bio: map['bio'] as String? ?? '',
      photoUrls: List<String>.from(map['photoUrls'] as List? ?? []),
      interests: List<String>.from(map['interests'] as List? ?? []),
      location: map['location'] as GeoPoint?,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      ageMin: map['ageMin'] as int? ?? AppConstants.minAge,
      ageMax: map['ageMax'] as int? ?? AppConstants.maxAge,
      searchRadiusKm: (map['searchRadiusKm'] as num?)?.toDouble() ??
          AppConstants.defaultSearchRadiusKm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate),
      'gender': gender.name,
      'lookingFor': lookingFor.map((g) => g.name).toList(),
      'bio': bio,
      'photoUrls': photoUrls,
      'interests': interests,
      'location': location,
      'onboardingComplete': onboardingComplete,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'searchRadiusKm': searchRadiusKm,
    };
  }

  UserProfile copyWith({
    String? name,
    DateTime? birthDate,
    Gender? gender,
    List<Gender>? lookingFor,
    String? bio,
    List<String>? photoUrls,
    List<String>? interests,
    GeoPoint? location,
    bool? onboardingComplete,
    int? ageMin,
    int? ageMax,
    double? searchRadiusKm,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      lookingFor: lookingFor ?? this.lookingFor,
      bio: bio ?? this.bio,
      photoUrls: photoUrls ?? this.photoUrls,
      interests: interests ?? this.interests,
      location: location ?? this.location,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        name,
        birthDate,
        gender,
        lookingFor,
        bio,
        photoUrls,
        interests,
        location,
        onboardingComplete,
        ageMin,
        ageMax,
        searchRadiusKm,
      ];
}
