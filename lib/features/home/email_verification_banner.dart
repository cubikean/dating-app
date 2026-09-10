import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_view.dart';
import '../../providers/auth_provider.dart';

/// Bandeau affiché tant que l'adresse email n'est pas confirmée.
///
/// Volontairement informatif et non bloquant : couper l'accès à l'application
/// dès l'inscription ferait fuir des personnes légitimes dont l'email traîne
/// dans les indésirables. Pour en faire une condition d'accès, c'est dans
/// `app_router.dart` que la redirection se pose.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Action impossible.', error: error);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || user.emailVerified) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final controller = ref.read(authControllerProvider.notifier);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.mark_email_unread_outlined,
                  size: 20, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirme ton adresse email pour sécuriser ton compte.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              if (_isBusy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                TextButton(
                  onPressed: () => _run(
                    controller.sendEmailVerification,
                    'Email de confirmation renvoyé.',
                  ),
                  child: const Text('Renvoyer'),
                ),
                TextButton(
                  onPressed: () => _run(
                    controller.reloadUser,
                    'Compte actualisé.',
                  ),
                  child: const Text("C'est fait"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
