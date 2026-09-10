import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/matches_provider.dart';

/// Grille des matchs — taper sur un match ouvre directement le chat
/// correspondant. Pour l'instant on réutilise `watchUserProfile` pour
/// afficher le nom/photo de l'autre personne ; à optimiser avec un
/// batch-get si la liste devient grande.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(userMatchesProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final profiles = ref.watch(matchProfilesProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Mes matchs')),
      body: matchesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(error: error),
        data: (matches) {
          if (matches.isEmpty || myUid == null) {
            return const Center(
                child: Text('Pas encore de match. Continue à swiper !'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final other = profiles[match.otherUserId(myUid)];
              final photoUrl = (other?.photoUrls.isNotEmpty ?? false)
                  ? other!.photoUrls.first
                  : null;

              return GestureDetector(
                onTap: () => context.push('/chats/${match.id}'),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      other?.name ?? '…',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
