import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/matches_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(userMatchesProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: matchesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(error: error),
        data: (matches) {
          if (matches.isEmpty || myUid == null) {
            return const Center(
                child: Text('Aucune conversation pour le moment.'));
          }
          return ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final match = matches[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(match
                    .otherUserId(myUid)), // TODO: résoudre en nom via le profil
                subtitle: Text(
                  match.lastMessage ?? 'Dites bonjour 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    match.lastMessage != null && match.lastMessageAt != null
                        ? Text(DateFormat.Hm().format(match.lastMessageAt!))
                        : null,
                onTap: () => context.push('/chats/${match.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
