import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/age_range_field.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/search_radius_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';

final _storageServiceProvider = Provider((ref) => StorageService());

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _bioController = TextEditingController();
  bool _initialized = false;
  bool _isSaving = false;
  bool _isBusyWithPhoto = false;
  bool _isLocating = false;
  UserProfile? _draft;

  void _initFromProfile(UserProfile profile) {
    if (_initialized) return;
    _draft = profile;
    _bioController.text = profile.bio;
    _initialized = true;
  }

  Future<void> _addPhoto() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || _draft == null) return;
    if (_draft!.photoUrls.length >= AppConstants.maxProfilePhotos) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > AppConstants.maxPhotoBytes) {
      showErrorSnackBar(context, 'Photo trop lourde : 10 Mo maximum.');
      return;
    }

    setState(() => _isBusyWithPhoto = true);
    final storage = ref.read(_storageServiceProvider);
    String? uploadedUrl;
    try {
      uploadedUrl = await storage.uploadProfilePhoto(
        uid: uid,
        bytes: bytes,
        contentType: picked.mimeType ?? 'image/jpeg',
      );
      // La photo est rattachée au profil immédiatement : quitter l'écran sans
      // enregistrer laisserait sinon un fichier orphelin, facturé, dans Storage.
      final updated =
          _draft!.copyWith(photoUrls: [..._draft!.photoUrls, uploadedUrl]);
      await ref.read(profileControllerProvider).save(updated);
      if (mounted) setState(() => _draft = updated);
    } catch (error) {
      // Le fichier est parti mais le profil ne le référence pas : on l'efface.
      if (uploadedUrl != null) {
        try {
          await storage.deleteProfilePhoto(uploadedUrl);
        } catch (_) {
          // Rien à faire de plus ici : l'erreur d'origine prime.
        }
      }
      if (mounted) {
        showErrorSnackBar(context, "Photo non ajoutée.", error: error);
      }
    } finally {
      if (mounted) setState(() => _isBusyWithPhoto = false);
    }
  }

  Future<void> _useMyLocation() async {
    if (_draft == null) return;
    setState(() => _isLocating = true);
    try {
      final position =
          await ref.read(locationServiceProvider).currentPosition();
      if (mounted) {
        setState(() => _draft = _draft!.copyWith(location: position));
      }
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

  Future<void> _removePhoto(String url) async {
    if (_draft == null || _isBusyWithPhoto) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cette photo ?'),
        content: const Text('Elle sera effacée de ton profil et du stockage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusyWithPhoto = true);
    final updated = _draft!.copyWith(
      photoUrls:
          _draft!.photoUrls.where((existing) => existing != url).toList(),
    );

    // Le profil est mis a jour en premier : une adresse encore referencee mais
    // absente du stockage afficherait une image cassee a tout le monde.
    try {
      await ref.read(profileControllerProvider).save(updated);
      if (mounted) setState(() => _draft = updated);
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Photo non retiree.', error: error);
        setState(() => _isBusyWithPhoto = false);
      }
      return;
    }

    // Le fichier part ensuite. S'il resiste, la photo a quand meme disparu du
    // profil : mieux vaut un fichier orphelin qu'une image cassee affichee.
    try {
      await ref.read(_storageServiceProvider).deleteProfilePhoto(url);
    } catch (_) {
      // Rien a signaler a l'utilisateur : de son point de vue, c'est fait.
    }
    if (mounted) setState(() => _isBusyWithPhoto = false);
  }

  Future<void> _save() async {
    if (_draft == null) return;
    setState(() => _isSaving = true);
    final updated = _draft!.copyWith(bio: _bioController.text.trim());
    try {
      await ref.read(profileControllerProvider).save(updated);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Profil non enregistré.', error: error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(error: error),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil introuvable.'));
          }
          _initFromProfile(profile);
          final draft = _draft!;

          return ListView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            children: [
              Text('Photos', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...draft.photoUrls.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                // Une photo illisible ne doit pas casser
                                // l'écran. Le cas le plus courant sur le web
                                // est un bucket sans CORS : voir le README.
                                errorBuilder: (context, error, stack) =>
                                    Container(
                                  width: 100,
                                  height: 100,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
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
                                  onTap: _isBusyWithPhoto
                                      ? null
                                      : () => _removePhoto(url),
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
                    ),
                    if (draft.photoUrls.length < AppConstants.maxProfilePhotos)
                      GestureDetector(
                        onTap: _isBusyWithPhoto ? null : _addPhoto,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outline),
                          ),
                          child: _isBusyWithPhoto
                              ? const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_a_photo_outlined),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AgeRangeField(
                ageMin: draft.ageMin,
                ageMax: draft.ageMax,
                onChanged: (min, max) => setState(() {
                  _draft = draft.copyWith(ageMin: min, ageMax: max);
                }),
              ),
              const SizedBox(height: 8),
              SearchRadiusField(
                radiusKm: draft.searchRadiusKm,
                hasLocation: draft.location != null,
                isLocating: _isLocating,
                onRadiusChanged: (value) => setState(() {
                  _draft = draft.copyWith(searchRadiusKm: value);
                }),
                onUseMyLocation: _useMyLocation,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Enregistrer',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}
