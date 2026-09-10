import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart' as firebase_options;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ Remplacer `firebase_options_example.dart` par le vrai fichier généré
  // via `flutterfire configure` (voir README.md).
  await Firebase.initializeApp(
    options: firebase_options.DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // ProviderScope est requis à la racine pour que Riverpod fonctionne.
    const ProviderScope(child: DatingApp()),
  );
}
