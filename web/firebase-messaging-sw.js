// Service worker des notifications web.
//
// Il tourne hors de la page, ce qui permet d'afficher une notification quand
// l'onglet est fermé. Il ne peut donc rien recevoir de `--dart-define` : la
// configuration est écrite en clair ci-dessous. Ces valeurs sont publiques,
// ce sont les mêmes que dans `lib/firebase_options.dart`.
//
// À garder synchronisé si le projet Firebase change.

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCMnJI3q5iQj19WVPggTBMjCuiI7WG5FFs',
  appId: '1:482039734151:web:2dbfe6d0cb49d021833d22',
  messagingSenderId: '482039734151',
  projectId: 'dating-app-88dd9',
  authDomain: 'dating-app-88dd9.firebaseapp.com',
  storageBucket: 'dating-app-88dd9.firebasestorage.app',
});

// Suffit à activer l'affichage des notifications reçues en arrière-plan.
firebase.messaging();
