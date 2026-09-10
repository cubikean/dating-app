import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
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
  bool _isUploadingPhoto = false;
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

    setState(() => _isUploadingPhoto = true);
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
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url,
                              width: 100, height: 100, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    if (draft.photoUrls.length < AppConstants.maxProfilePhotos)
                      GestureDetector(
                        onTap: _isUploadingPhoto ? null : _addPhoto,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outline),
                          ),
                          child: _isUploadingPhoto
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
