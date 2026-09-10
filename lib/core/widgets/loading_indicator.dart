import 'package:flutter/material.dart';

/// Indicateur de chargement centré, utilisé comme état "loading" par défaut
/// pour les écrans qui attendent une réponse Firebase.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
