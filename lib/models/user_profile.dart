import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

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
  });

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
      ];
}
