import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Upload des photos de profil vers Firebase Storage.
class StorageService {
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Envoie une photo de profil et renvoie son URL de téléchargement.
  ///
  /// On passe par `putData` et non `putFile` : `putFile` n'est pas implémenté
  /// dans `firebase_storage_web` et lève `UnimplementedError` sur le web.
  /// Les octets fonctionnent sur toutes les plateformes, et évitent au passage
  /// la dépendance à `dart:io`, indisponible côté navigateur.
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final fileName = '${_uuid.v4()}.${_extensionFor(contentType)}';
    final ref = _storage.ref('users/$uid/photos/$fileName');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  String _extensionFor(String contentType) {
    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
  }

  Future<void> deleteProfilePhoto(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }
}
