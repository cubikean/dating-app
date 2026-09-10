import 'package:flutter/material.dart';

import '../../core/widgets/loading_indicator.dart';

/// Écran affiché pendant que Firebase Auth détermine si une session
/// existe déjà. Le router redirige automatiquement dès que l'état est connu.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 64, color: Colors.pink),
            SizedBox(height: 24),
            LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}
