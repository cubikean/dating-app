import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isBusy = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(error: error),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil introuvable.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 56,
                  backgroundImage: profile.photoUrls.isNotEmpty
                      ? NetworkImage(profile.photoUrls.first)
                      : null,
                  child: profile.photoUrls.isEmpty
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${profile.name}, ${profile.age}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 24),
              if (profile.bio.isNotEmpty) ...[
                Text('Bio', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(profile.bio),
                const SizedBox(height: 20),
              ],
              if (profile.interests.isNotEmpty) ...[
                Text('Centres d\'intérêt',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.interests
                      .map((interest) => Chip(label: Text(interest)))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Se déconnecter',
                    style: TextStyle(color: Colors.red)),
                onTap: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text(
                  'Efface définitivement ton profil, tes photos, tes matchs '
                  'et tes conversations.',
                ),
                trailing: isBusy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: isBusy ? null : () => _confirmDelete(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Confirmation avant suppression définitive. Le texte énumère ce qui part,
/// pour que personne ne découvre après coup ce qu'il a perdu.
Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer ton compte ?'),
      content: const Text(
        'Ton profil, tes photos, tes matchs et tes conversations seront '
        'effacés définitivement. Les personnes avec qui tu as échangé ne '
        'retrouveront plus ces conversations. Cette action est irréversible.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await ref.read(authControllerProvider.notifier).deleteAccount();
  final error = ref.read(authControllerProvider).asError;
  if (error != null && context.mounted) {
    showErrorSnackBar(context, 'Suppression impossible.', error: error.error);
  }
  // En cas de succès, le router bascule seul vers l'écran de connexion.
}
