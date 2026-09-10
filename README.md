# Dating App Boilerplate (Flutter + Firebase + Riverpod)

Boilerplate de départ pour une application mobile de rencontre façon
Tinder/Bumble : swipe de profils, matchs, chat, gestion de profil.

## Stack

- **Flutter** (Material 3)
- **Riverpod** (`flutter_riverpod`) pour la gestion d'état
- **go_router** pour la navigation déclarative (avec redirections liées à l'auth)
- **Firebase** : Auth, Firestore, Storage
- **flutter_card_swiper** pour la pile de cartes swipeables

## Mise en route

1. Installer les dépendances :

   ```bash
   flutter pub get
   ```

2. Configurer Firebase pour ce projet (une seule fois) :

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Cela génère `lib/firebase_options.dart`. Un fichier
   `lib/firebase_options_example.dart` est fourni ici à titre indicatif
   uniquement — remplace-le par celui généré par la commande ci-dessus,
   puis mets à jour l'import dans `lib/main.dart`.

3. Dans la console Firebase, activer :
   - **Authentication** → méthode Email/Password (et Google si tu gardes
     `google_sign_in`)
   - **Firestore** → créer la base en mode production, puis déployer les
     règles fournies (`firestore.rules`) — voir l'étape 4
   - **Storage** → pour les photos de profil

4. Déployer les règles de sécurité. Sans elles, un nouveau projet Firebase
   laisse la base ouverte en lecture et en écriture à tout le monde :

   ```bash
   firebase deploy --only firestore:rules,storage
   ```

   Les règles Firestore sont couvertes par des tests sur l'émulateur, voir
   `test/rules/firestore_rules_test.mjs`.

5. Lancer l'app :

   ```bash
   flutter run
   ```

## La clé d'API dans `firebase_options.dart`

GitHub signale cette clé comme un secret exposé. C'en est un au sens de son
détecteur, pas au sens de Firebase : une clé d'API Firebase **identifie** le
projet, elle n'ouvre aucun accès par elle-même. Elle est embarquée dans le
bundle web de toute application Firebase, donc lisible par n'importe quel
visiteur, dépôt public ou non. Google le documente comme un fonctionnement
normal.

**Ne la régénère pas.** Cela casserait l'application en production sans rien
protéger, puisque la nouvelle clé serait tout aussi visible. Ferme l'alerte
GitHub en faux positif.

Ce qui protège réellement le projet, dans cet ordre :

1. **Les règles de sécurité** (`firestore.rules`, `storage.rules`), qui
   décident qui lit et écrit quoi. Elles sont déployées.
2. **App Check**, à activer dans la console Firebase. C'est le seul vrai
   rempart contre un client qui n'est pas ton application : sans lui, la clé
   permet de créer des comptes en masse par appel direct à l'API, et chaque
   compte créé passe ensuite les règles qui exigent seulement d'être connecté.
3. **Les restrictions de clé**, dans la console Google Cloud : limiter la clé
   aux seules API Firebase utilisées, et aux domaines qui servent l'app. Cela
   plafonne le détournement de quota, mais un en-tête de provenance se
   falsifie : c'est une ceinture, pas un rempart.

## Structure du projet

```
lib/
├── main.dart                 # Point d'entrée, init Firebase
├── app.dart                  # MaterialApp.router + thème
├── core/
│   ├── constants/            # Constantes globales (durées, tailles...)
│   ├── theme/                # Thème clair/sombre centralisé
│   ├── router/               # Config go_router + redirections auth
│   └── widgets/              # Widgets réutilisables (boutons, loaders...)
├── models/                    # UserProfile, MatchModel, MessageModel
├── services/                   # Accès Firebase (Auth, Firestore, Storage)
├── providers/                  # Providers Riverpod (state applicatif)
└── features/
    ├── splash/                # Écran de démarrage / vérification session
    ├── auth/                  # Connexion / inscription
    ├── onboarding/             # Création de profil (photos, bio, préférences)
    ├── home/                   # Coquille avec bottom navigation
    ├── discovery/              # Swipe de profils
    ├── matches/                # Liste des matchs
    ├── chat/                   # Liste de conversations + détail d'un chat
    └── profile/                # Profil utilisateur + édition
```

## Modèle de données Firestore (suggestion)

```
users/{uid}
  - name, birthDate, gender, bio, photos[], interests[], location (geopoint)

swipes/{uid}/actions/{targetUid}
  - liked: bool, timestamp

matches/{matchId}          # matchId = uids triés et concaténés
  - users: [uidA, uidB]
  - createdAt

matches/{matchId}/messages/{messageId}
  - senderId, text, sentAt, readAt
```

Ce modèle est un point de départ : adapte-le à tes besoins (algorithme de
matching, filtres de recherche, préférences, etc.).

## Points à compléter avant la prod

- Remplacer `firebase_options_example.dart` par le vrai fichier généré.
- Vérifier que les règles de sécurité (`firestore.rules`, `storage.rules`)
  sont bien déployées : un nouveau projet Firebase est ouvert à tous par
  défaut, et les règles du dépôt ne protègent rien tant qu'elles dorment
  sur le disque.
- Ajouter la logique de matching réelle (actuellement les données de
  démonstration sont mockées dans `DiscoveryProvider` en attendant le
  branchement Firestore complet).
- Gérer la modération de contenu (photos, bio) et le signalement/blocage
  d'utilisateurs, obligatoires pour ce type d'app.
- Ajouter la vérification d'âge (18+) et les CGU/consentement RGPD.
