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
            ],
          );
        },
      ),
    );
  }
}
