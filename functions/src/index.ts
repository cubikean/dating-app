import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

initializeApp();

const db = getFirestore();

/** Région des fonctions appelées depuis l'application. Doit rester identique
 * à `functionsRegion` dans `lib/services/account_service.dart`. */
const CALLABLE_REGION = "europe-west1";

/**
 * Région des déclencheurs Firestore. Elle n'est pas libre : un déclencheur de
 * deuxième génération doit vivre dans la région imposée par l'emplacement de
 * la base. Celle-ci est en `eur3`, une multi-région, dont la seule région de
 * déclenchement valide est `europe-west4`. Déployer ailleurs échoue à la
 * création de la fonction, sans message explicite.
 *
 * Les deux autres cas courants : `nam5` impose `us-central1`, et une base
 * mono-région impose sa propre région.
 */
const TRIGGER_REGION = "europe-west4";

/**
 * Efface définitivement le compte de l'appelant et tout ce qui s'y rattache.
 *
 * Cette opération vit ici et pas dans l'application parce qu'elle touche des
 * documents qui n'appartiennent pas à l'utilisateur : les swipes que d'autres
 * ont posés sur lui, les matchs partagés, les conversations. Autoriser un
 * client à les supprimer reviendrait à laisser n'importe qui effacer les
 * données d'autrui.
 *
 * Les signalements sont volontairement conservés : ce sont des pièces de
 * modération, qui doivent survivre au départ de la personne signalée.
 */
export const deleteAccount = onCall(
  { region: CALLABLE_REGION },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Connexion requise.");
  }

  logger.info("Suppression de compte demandée", { uid });

  // 1. Matchs et, récursivement, leurs messages.
  const matches = await db
    .collection("matches")
    .where("users", "array-contains", uid)
    .get();
  for (const match of matches.docs) {
    await db.recursiveDelete(match.ref);
  }

  // 2. Blocages, dans un sens comme dans l'autre.
  const blocks = await db
    .collection("blocks")
    .where("users", "array-contains", uid)
    .get();
  await Promise.all(blocks.docs.map((doc) => doc.ref.delete()));

  // 3. Swipes émis par l'utilisateur, sous-collection comprise.
  await db.recursiveDelete(db.collection("swipes").doc(uid));

  // 4. Swipes que les autres ont posés sur lui. C'est précisément ce qu'un
  //    client ne peut pas faire : ces documents appartiennent à autrui.
  const received = await db
    .collectionGroup("actions")
    .where("targetUid", "==", uid)
    .get();
  await Promise.all(received.docs.map((doc) => doc.ref.delete()));

  // 5. Photos de profil.
  await getStorage()
    .bucket()
    .deleteFiles({ prefix: `users/${uid}/` });

  // 6. Le profil lui-même.
  await db.collection("users").doc(uid).delete();

  // 7. Le compte d'authentification, en dernier : tant qu'il existe, une
  //    reprise après erreur reste possible.
  await getAuth().deleteUser(uid);

  logger.info("Compte supprimé", {
    uid,
    matches: matches.size,
    blocks: blocks.size,
    swipesReceived: received.size,
  });

  return {
    deletedMatches: matches.size,
    deletedBlocks: blocks.size,
    deletedIncomingSwipes: received.size,
  };
});

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

/** Prénom affiché, ou un repli neutre si le profil a disparu. */
async function displayName(uid: string): Promise<string> {
  const profile = await db.collection("users").doc(uid).get();
  return (profile.data()?.name as string | undefined) || "Quelqu'un";
}

/**
 * Envoie une notification à tous les appareils de [uid].
 *
 * Les jetons refusés définitivement sont effacés au passage : sans ce
 * ménage, chaque envoi ultérieur repaierait un échec certain, et la liste
 * d'appareils grossirait sans fin.
 */
async function notify(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const devices = await db
    .collection("users")
    .doc(uid)
    .collection("devices")
    .get();
  const tokens = devices.docs.map((device) => device.id);
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  const stale = response.responses.flatMap((result, index) => {
    const code = result.error?.code;
    const gone =
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token";
    return gone ? [devices.docs[index].ref.delete()] : [];
  });
  await Promise.all(stale);

  logger.info("Notification envoyée", {
    uid,
    envoyes: response.successCount,
    echecs: response.failureCount,
    jetonsRetires: stale.length,
  });
}

/** Prévient les deux personnes dès qu'un match est créé. */
export const onMatchCreated = onDocumentCreated(
  { document: "matches/{matchId}", region: TRIGGER_REGION },
  async (event) => {
    const users = (event.data?.data()?.users as string[] | undefined) ?? [];

    await Promise.all(
      users.map(async (uid) => {
        const other = users.find((candidate) => candidate !== uid);
        if (!other) return;
        await notify(
          uid,
          "Nouveau match",
          `${await displayName(other)} t'a liké aussi.`,
          { type: "match", matchId: event.params.matchId },
        );
      }),
    );
  },
);

/** Prévient le destinataire d'un message. */
export const onMessageCreated = onDocumentCreated(
  {
    document: "matches/{matchId}/messages/{messageId}",
    region: TRIGGER_REGION,
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const senderId = message.senderId as string;
    const match = await db
      .collection("matches")
      .doc(event.params.matchId)
      .get();
    const users = (match.data()?.users as string[] | undefined) ?? [];
    const recipient = users.find((candidate) => candidate !== senderId);
    if (!recipient) return;

    await notify(
      recipient,
      await displayName(senderId),
      // Tronqué : un message long déborderait de la notification, et son
      // texte intégral n'a rien à faire dans l'aperçu de l'écran verrouillé.
      String(message.text ?? "").slice(0, 120),
      { type: "message", matchId: event.params.matchId },
    );
  },
);
