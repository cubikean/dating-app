import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/matches_provider.dart';
import '../../providers/safety_provider.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String matchId;

  const ChatDetailScreen({super.key, required this.matchId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Le champ est vidé tout de suite pour que la saisie reste fluide, mais le
    // texte est conservé : en cas d'échec il est remis, sinon il serait perdu.
    _textController.clear();
    try {
      await ref.read(chatControllerProvider).sendMessage(
            matchId: widget.matchId,
            text: text,
          );
    } catch (error) {
      if (!mounted) return;
      _textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      showErrorSnackBar(context, 'Message non envoyé.', error: error);
    }
  }

  /// Motifs proposés au signalement. Une liste fermée vaut mieux qu'un champ
  /// libre : elle se trie et se compte du côté de la modération.
  static const _reportReasons = [
    'Photos ou propos à caractère sexuel',
    'Harcèlement ou insultes',
    'Faux profil ou usurpation',
    'Arnaque ou sollicitation commerciale',
    'Comportement dangereux',
    'Autre',
  ];

  Future<void> _report(String otherUid) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Signaler cette personne'),
        children: [
          for (final reason in _reportReasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, reason),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(reason),
              ),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await ref.read(safetyControllerProvider).report(
            targetUid: otherUid,
            reason: reason,
            matchId: widget.matchId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signalement envoyé. Notre équipe va le regarder.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Signalement non envoyé.', error: error);
      }
    }
  }

  Future<void> _confirmUnmatch(String? otherName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Se retirer du match avec ${otherName ?? 'cette personne'} ?'),
        content: const Text(
          'La conversation disparaîtra de vos deux listes et personne ne '
          'pourra plus y écrire. Ce retrait ne se défait pas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(safetyControllerProvider).endMatch(widget.matchId);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Retrait impossible.', error: error);
      }
    }
  }

  Future<void> _confirmBlock(String otherUid, String? otherName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bloquer ${otherName ?? 'cette personne'} ?'),
        content: const Text(
          "Vous ne pourrez plus vous écrire et la conversation disparaîtra de "
          'vos deux listes. Cette personne ne sera pas prévenue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(safetyControllerProvider).block(otherUid);
      // La conversation n'existe plus pour cet utilisateur : on quitte l'écran.
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Blocage impossible.', error: error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.matchId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    // Le match et le profil viennent des flux déjà ouverts par la liste des
    // conversations : afficher le prénom ne coûte aucune lecture de plus.
    final match = ref.watch(matchByIdProvider(widget.matchId));
    final profiles = ref.watch(matchProfilesProvider).valueOrNull ?? const {};
    final otherUid =
        (match != null && myUid != null) ? match.otherUserId(myUid) : null;
    final otherName = otherUid != null ? profiles[otherUid]?.name : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(otherName ?? 'Conversation'),
        actions: [
          if (otherUid != null)
            PopupMenuButton<_SafetyAction>(
              tooltip: 'Signaler ou bloquer',
              onSelected: (action) {
                switch (action) {
                  case _SafetyAction.report:
                    _report(otherUid);
                  case _SafetyAction.unmatch:
                    _confirmUnmatch(otherName);
                  case _SafetyAction.block:
                    _confirmBlock(otherUid, otherName);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _SafetyAction.report,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Signaler'),
                  ),
                ),
                PopupMenuItem(
                  value: _SafetyAction.unmatch,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.heart_broken_outlined),
                    title: Text('Se retirer du match'),
                  ),
                ),
                PopupMenuItem(
                  value: _SafetyAction.block,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.block),
                    title: Text('Bloquer'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => ErrorView(error: error),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Dites bonjour 👋'));
                }
                // La conversation ne charge que sa fin. Si le lot est plein,
                // c'est qu'il reste probablement de l'historique au-dessus.
                final pageSize =
                    ref.watch(chatPageSizeProvider(widget.matchId));
                final mayHaveMore = messages.length >= pageSize;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length + (mayHaveMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return Center(
                        child: TextButton(
                          onPressed: () => ref
                              .read(
                                  chatPageSizeProvider(widget.matchId).notifier)
                              .update((size) =>
                                  size + AppConstants.messagesPageSize),
                          child: const Text('Charger les messages précédents'),
                        ),
                      );
                    }
                    final message = messages[messages.length - 1 - index];
                    final isMine = message.isMine(myUid ?? '');
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: isMine
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Actions du menu de sécurité, en haut de la conversation.
enum _SafetyAction { report, unmatch, block }
