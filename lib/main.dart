import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_check.dart';
import 'firebase_options.dart' as firebase_options;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ Remplacer `firebase_options_example.dart` par le vrai fichier généré
  // via `flutterfire configure` (voir README.md).
  await Firebase.initializeApp(
    options: firebase_options.DefaultFirebaseOptions.currentPlatform,
  );

  // Atteste que les requêtes viennent de cette application. Inoffensif tant
  // que l'application des règles n'est pas activée dans la console Firebase.
  await activateAppCheck();

  // Cache local : activé par défaut sur mobile, il doit être demandé
  // explicitement sur le web. Sans lui, l'app est vide dès que le réseau
  // manque. À régler avant la première lecture Firestore.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    // ProviderScope est requis à la racine pour que Riverpod fonctionne.
    const ProviderScope(child: DatingApp()),
  );
}
