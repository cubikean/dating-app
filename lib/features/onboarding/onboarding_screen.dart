import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/age_range_field.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/search_radius_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';

/// Création de profil : prénom, date de naissance, genre, ce qu'on recherche,
/// tranche d'âge, au moins une photo et une bio.
///
/// Les photos sont retenues en mémoire et envoyées seulement à la validation
/// du formulaire. Les envoyer dès la sélection laisserait des fichiers
/// orphelins dans le stockage si la personne abandonne en cours de route, et
/// il n'existe encore aucun profil auquel les rattacher.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

final _storageServiceProvider = Provider((ref) => StorageService());

/// Une photo choisie mais pas encore envoyée.
typedef _PendingPhoto = ({Uint8List bytes, String contentType});

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime? _birthDate;
  Gender _gender = Gender.woman;
  final Set<Gender> _lookingFor = {};
  int _ageMin = AppConstants.minAge;
  int _ageMax = AppConstants.maxAge;
  final List<_PendingPhoto> _photos = [];
  double _searchRadiusKm = AppConstants.defaultSearchRadiusKm;
  GeoPoint? _location;
  bool _isLocating = false;
  bool _isSaving = false;

  Future<void> _useMyLocation() async {
    setState(() => _isLocating = true);
    try {
      final position =
          await ref.read(locationServiceProvider).currentPosition();
      if (mounted) setState(() => _location = position);
    } on LocationDeniedException catch (refusal) {
      // Un refus n'est pas une panne : on l'explique sans jargon technique.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(refusal.message)));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Position introuvable.', error: error);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= AppConstants.maxProfilePhotos) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > AppConstants.maxPhotoBytes) {
      showErrorSnackBar(context, 'Photo trop lourde : 10 Mo maximum.');
      return;
    }

    setState(() => _photos.add((
          bytes: bytes,
          contentType: picked.mimeType ?? 'image/jpeg',
        )));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - AppConstants.minAge, now.month, now.day),
      firstDate: DateTime(now.year - AppConstants.maxAge),
      lastDate: DateTime(now.year - AppConstants.minAge, now.month, now.day),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    if (_nameController.text.trim().isEmpty ||
        _birthDate == null ||
        _lookingFor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de compléter tous les champs.')),
      );
      return;
    }
    if (_photos.isEmpty) {
      // Un profil sans photo n'a aucune chance dans une pile de swipe : mieux
      // vaut le dire ici que laisser quelqu'un devenir invisible sans le savoir.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins une photo.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final List<String> photoUrls;
    try {
      final storage = ref.read(_storageServiceProvider);
      photoUrls = [
        for (final photo in _photos)
          await storage.uploadProfilePhoto(
            uid: uid,
            bytes: photo.bytes,
            contentType: photo.contentType,
          ),
      ];
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Photos non envoyées.', error: error);
        setState(() => _isSaving = false);
      }
      return;
    }

    final profile = UserProfile(
      uid: uid,
      name: _nameController.text.trim(),
      birthDate: _birthDate!,
      gender: _gender,
      lookingFor: _lookingFor.toList(),
      ageMin: _ageMin,
      ageMax: _ageMax,
      searchRadiusKm: _searchRadiusKm,
      location: _location,
      bio: _bioController.text.trim(),
      photoUrls: photoUrls,
      onboardingComplete: true,
    );
    try {
      await ref.read(profileControllerProvider).save(profile);
      // Le router redirige automatiquement vers `/` une fois onboardingComplete=true.
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Profil non enregistré.', error: error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crée ton profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Prénom'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_birthDate == null
                  ? 'Date de naissance'
                  : 'Né(e) le ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 12),
            Text('Je suis', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: Gender.values.map((g) {
                return ChoiceChip(
                  label: Text(_genderLabel(g)),
                  selected: _gender == g,
                  onSelected: (_) => setState(() => _gender = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Je recherche', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: Gender.values.map((g) {
                return FilterChip(
                  label: Text(_genderLabel(g)),
                  selected: _lookingFor.contains(g),
                  onSelected: (selected) => setState(() {
                    selected ? _lookingFor.add(g) : _lookingFor.remove(g);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Photos', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${_photos.length} / ${AppConstants.maxProfilePhotos}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var index = 0; index < _photos.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _photos[index].bytes,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _isSaving
                                    ? null
                                    : () =>
                                        setState(() => _photos.removeAt(index)),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length < AppConstants.maxProfilePhotos)
                    GestureDetector(
                      onTap: _isSaving ? null : _addPhoto,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Une photo au minimum : sans elle, ton profil ne sera montré à '
              'personne.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AgeRangeField(
              ageMin: _ageMin,
              ageMax: _ageMax,
              onChanged: (min, max) => setState(() {
                _ageMin = min;
                _ageMax = max;
              }),
            ),
            const SizedBox(height: 8),
            SearchRadiusField(
              radiusKm: _searchRadiusKm,
              hasLocation: _location != null,
              isLocating: _isLocating,
              onRadiusChanged: (value) =>
                  setState(() => _searchRadiusKm = value),
              onUseMyLocation: _useMyLocation,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'Bio',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Continuer',
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(Gender g) => switch (g) {
        Gender.woman => 'Femme',
        Gender.man => 'Homme',
        Gender.nonBinary => 'Non-binaire',
        Gender.other => 'Autre',
      };
}
