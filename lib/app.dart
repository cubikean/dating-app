import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/messaging_provider.dart';

/// Nécessaire pour afficher un bandeau depuis l'extérieur de l'arbre des
/// écrans, quand une notification arrive.
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class DatingApp extends ConsumerWidget {
  const DatingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Suffit à déclencher l'enregistrement de l'appareil : le provider
    // s'abonne lui-même à l'état d'authentification.
    ref.watch(deviceRegistrationProvider);

    // Une notification reçue application ouverte n'est pas affichée par le
    // système. On la relaie ici, au-dessus de l'écran courant.
    ref.listen(foregroundMessageProvider, (previous, next) {
      final notification = next.valueOrNull?.notification;
      if (notification == null) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(notification.title ?? notification.body ?? ''),
        ),
      );
    });

    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      title: 'Dating App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
