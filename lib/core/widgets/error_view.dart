import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

/// Affichage d'erreur dont le détail technique est sélectionnable et copiable.
///
/// Le texte brut (`error.toString()`) contient le code Firebase et, le cas
/// échéant, l'URL de création d'index Firestore : il faut pouvoir le coller
/// tel quel dans un ticket ou une console, sans passer par une capture d'écran.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = error.toString();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Une erreur est survenue',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                details,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => copyError(context, error),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text("Copier l'erreur"),
                ),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Réessayer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Place le détail technique de l'erreur dans le presse-papiers et le confirme.
Future<void> copyError(BuildContext context, Object error) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: error.toString()));
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Erreur copiée dans le presse-papiers'),
      duration: Duration(seconds: 2),
    ),
  );
}

/// SnackBar d'erreur : message lisible à l'écran, détail technique récupérable
/// via l'action « Copier ». Sans `error`, c'est le message qui est copié.
void showErrorSnackBar(BuildContext context, String message, {Object? error}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: SelectableText(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Copier',
          onPressed: () => Clipboard.setData(
            ClipboardData(text: (error ?? message).toString()),
          ),
        ),
      ),
    );
}
