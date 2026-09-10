import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

/// Onboarding minimal : prénom, date de naissance, genre, ce qu'on
/// recherche, et bio. Les photos sont volontairement laissées de côté
/// ici (voir `EditProfileScreen` + `StorageService` pour l'upload) afin
/// de garder ce flow simple à adapter.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime? _birthDate;
  Gender _gender = Gender.woman;
  final Set<Gender> _lookingFor = {};
  bool _isSaving = false;

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

    setState(() => _isSaving = true);
    final profile = UserProfile(
      uid: uid,
      name: _nameController.text.trim(),
      birthDate: _birthDate!,
      gender: _gender,
      lookingFor: _lookingFor.toList(),
      bio: _bioController.text.trim(),
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
