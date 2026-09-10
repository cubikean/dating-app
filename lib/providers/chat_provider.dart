import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/message_model.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

/// Nombre de messages actuellement chargés pour une conversation. Remonter
/// l'historique consiste simplement à augmenter cette valeur.
final chatPageSizeProvider = StateProvider.family<int, String>(
  (ref, matchId) => AppConstants.messagesPageSize,
);

/// Messages d'une conversation donnée, en temps réel.
/// `.family` permet de paramétrer le provider par `matchId`.
final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, matchId) {
  final limit = ref.watch(chatPageSizeProvider(matchId));
  return ref
      .watch(firestoreServiceProvider)
      .watchMessages(matchId, limit: limit);
});

class ChatController {
  final Ref _ref;

  ChatController(this._ref);

  Future<void> sendMessage({required String matchId, required String text}) {
    final me = _ref.read(authStateProvider).valueOrNull;
    if (me == null) return Future.value();
    return _ref.read(firestoreServiceProvider).sendMessage(
          matchId: matchId,
          senderId: me.uid,
          text: text,
        );
  }
}

final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(ref);
});
