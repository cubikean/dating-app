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
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

   Les règles Firestore sont couvertes par des tests sur l'émulateur, voir
   `test/rules/firestore_rules_test.mjs`.

   `firestore.indexes.json` contient l'index composite qu'exige la requête de
   découverte (profil complet, genre recherché, réciprocité). Si Firestore
   réclame malgré tout un index à l'exécution, suis le lien de l'erreur : il
   crée exactement la forme attendue, à recopier ensuite dans le fichier.

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

## App Check

Le code est déjà branché (`lib/core/app_check.dart`, appelé depuis `main.dart`).
Il reste la partie console, qui demande ton compte.

1. **Console Firebase → App Check → Apps.** Enregistre chaque application :
   - **Web** : fournisseur reCAPTCHA v3. Crée la clé sur
     <https://www.google.com/recaptcha/admin>, colle la clé *secrète* dans
     Firebase, et garde la clé *de site* pour l'étape 2.
   - **Android** : Play Integrity. Demande l'empreinte SHA-256 de ta clé de
     signature.
   - **iOS** : App Attest.

2. **Lance l'app avec la clé de site**, qui n'est pas un secret :

   ```bash
   flutter run -d chrome --dart-define=RECAPTCHA_SITE_KEY=6Lxxxxxxxxxxxxxxxx
   ```

   Sans cette valeur, App Check est simplement sauté sur le web et
   l'application démarre normalement.

3. **En développement**, le fournisseur de débogage remplace l'attestation
   réelle. Sur mobile il est choisi automatiquement ; sur le web, le drapeau
   posé dans `web/index.html` s'active dès que le domaine est `localhost`.
   Dans les deux cas, un jeton est imprimé dans la console au premier
   chargement : colle-le dans la console Firebase, sous App Check → Apps →
   *Gérer les jetons de débogage*. Sans cette étape, la connexion échoue,
   puisque App Check est appliqué.

   C'est le chemin recommandé en local : reCAPTCHA v3 refuse les domaines
   qu'il ne connaît pas, et `flutter run` sert l'application depuis un port
   qui change à chaque lancement.

   Si tu veux malgré tout tester reCAPTCHA en local, l'erreur
   `AppCheck: 400 error` vient presque toujours de l'une de ces trois causes,
   dans cet ordre :

   - `localhost` ne figure pas dans les domaines autorisés de la clé
     reCAPTCHA (console reCAPTCHA, pas Firebase) ;
   - c'est la clé **secrète** qu'attend la console Firebase, la clé **de
     site** n'allant que dans `--dart-define` ;
   - la clé est de type reCAPTCHA **Enterprise** alors que le code utilise
     `ReCaptchaV3Provider`. Les deux ne sont pas interchangeables.

4. **Surveille avant d'appliquer.** Onglet App Check → API : chaque service
   affiche la part de trafic attesté. Attends que le trafic légitime soit
   proche de 100 % avant de passer à l'étape suivante, sinon tu bloques tes
   propres utilisateurs.

5. **Active l'application des règles, service par service.** Commence par
   **Authentication** : c'est lui qui empêche la création de comptes en masse
   par appel direct à l'API, la faille réelle décrite plus haut. Firestore et
   Storage ensuite.

Tant que l'étape 5 n'est pas faite, App Check ne bloque rien : il se contente
de mesurer.

## Afficher les photos sur le web : CORS

Sur le web, les photos de profil se chargent via une requête que le navigateur
soumet aux règles CORS. Firebase Storage ne renvoie aucun en-tête
`Access-Control-Allow-Origin` par défaut : la requête est donc bloquée, et
Flutter la rapporte sous la forme déroutante `statusCode: 0`. Le fichier, lui,
est parfaitement accessible ; c'est le navigateur qui refuse de le donner à la
page.

La configuration est dans `cors.json`. Elle s'applique au bucket, pas au
projet Firebase, donc pas avec la CLI Firebase :

```bash
gcloud storage buckets update gs://dating-app-88dd9.firebasestorage.app \
  --cors-file=cors.json
```

Sans `gcloud` installé, la Cloud Shell de la console Google Cloud fonctionne
aussi bien : elle l'a déjà, et téléverser `cors.json` y prend dix secondes.

`origin: ["*"]` convient au développement et reste sans risque ici : les URL
de téléchargement portent déjà un jeton, et seule la méthode `GET` est
ouverte. En production, remplace l'étoile par la liste de tes domaines.

## Notifications

Le code est en place des deux côtés : l'application enregistre un jeton par
appareil sous `users/{uid}/devices/{jeton}`, et deux fonctions Cloud envoient
les notifications à la création d'un match et à l'arrivée d'un message.

Ce qui reste à faire, dans la console :

1. **Clé publique web.** Paramètres du projet → Cloud Messaging → Certificats
   push Web → *Générer une paire de clés*. Passe la clé publique au démarrage,
   comme celle de reCAPTCHA :

   ```bash
   flutter run -d chrome \
     --dart-define=RECAPTCHA_SITE_KEY=… \
     --dart-define=VAPID_PUBLIC_KEY=…
   ```

   Sans elle, l'application démarre normalement mais n'enregistre aucun jeton
   web, et le journal de la console le dit.

2. **Android.** Rien de spécifique, mais `flutterfire configure` doit avoir
   écrit `android/app/google-services.json`.

3. **iOS.** Un compte développeur Apple, une clé APNs (.p8) déposée dans
   Firebase, et la capacité *Push Notifications* activée dans Xcode.

**La région des déclencheurs n'est pas libre.** Un déclencheur Firestore de
deuxième génération doit vivre dans la région imposée par l'emplacement de la
base. Celle de ce projet est en `eur3`, une multi-région, dont la seule région
valide est `europe-west4` — d'où les deux constantes de région distinctes dans
`functions/src/index.ts`. Déployer ailleurs échoue à la création de la
fonction, avec un message qui n'explique pas pourquoi. Les autres cas
courants : `nam5` impose `us-central1`, une base mono-région impose la sienne.
Pour vérifier l'emplacement :

```bash
firebase firestore:databases:get "(default)"
```

Deux points qui se cassent en silence si on les oublie. `web/firebase-messaging-sw.js`
contient la configuration Firebase en clair : un service worker tourne hors de
la page et ne peut rien recevoir de `--dart-define`. Il faut donc le mettre à
jour si le projet Firebase change. Et la région des fonctions doit rester la
même de part et d'autre, cf. la section sur la suppression de compte.

Les jetons refusés définitivement sont effacés à l'envoi : sans ce ménage, la
liste d'appareils grossirait indéfiniment et chaque notification repaierait
des échecs certains.

## Suppression de compte

Le code vit dans `functions/`, pas dans l'application, et ce n'est pas un
choix d'architecture : effacer un compte suppose de supprimer des documents
qui appartiennent à d'autres personnes, comme les swipes posés sur celle qui
s'en va, ou les conversations partagées. Aucune règle de sécurité ne doit
autoriser ça depuis un téléphone.

```bash
cd functions && npm install
firebase deploy --only functions
```

**Les fonctions Cloud exigent le plan Blaze.** Sur le plan gratuit, le
déploiement échoue ; le bouton de suppression renverra alors une erreur
`not-found`, lisible et copiable depuis l'application.

Ce qui est effacé : le profil, les photos, les matchs et leurs messages, les
blocages, les swipes émis, les swipes que d'autres ont posés sur la personne,
puis le compte d'authentification, en dernier pour qu'une reprise reste
possible en cas d'échec en cours de route.

Ce qui est conservé : les signalements. Ce sont des pièces de modération,
qui doivent survivre au départ de la personne signalée.

Deux détails qui se cassent en silence si on les oublie. La région déclarée
dans `functions/src/index.ts` doit rester identique à celle de
`lib/services/account_service.dart`, sinon l'appel part vers une fonction
inexistante. Et les swipes portent un champ `targetUid` redondant avec
l'identifiant du document : c'est lui qui permet de retrouver les swipes
reçus, une requête de groupe ne sachant pas filtrer sur un identifiant.

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
