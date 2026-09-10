// Tests des regles de securite Firestore (`firestore.rules`).
//
// Ces tests tournent sur l'emulateur, jamais sur le vrai projet. Depuis la
// racine du depot :
//
//   npm install --no-save @firebase/rules-unit-testing firebase
//   firebase emulators:exec --only firestore --project demo-dating-app //     "node test/rules/firestore_rules_test.mjs"
//
// Chaque cas reproduit un appel reel de `lib/services/firestore_service.dart`.

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, collectionGroup, query, where, getDocs, addDoc, deleteField,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const RULES = new URL('../../firestore.rules', import.meta.url);
const ALICE = 'alice', BOB = 'bob', CAROL = 'carol', DAVE = 'dave';
const MATCH_AB = 'alice_bob';

// `firebase emulators:exec` renseigne FIRESTORE_EMULATOR_HOST : on suit le port
// reellement utilise plutot que d'en coder un en dur.
const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');

const testEnv = await initializeTestEnvironment({
  projectId: 'demo-dating-app',
  firestore: { rules: readFileSync(RULES, 'utf8'), host, port: Number(port) },
});

/** Date de naissance située `n` annees en arriere, decalee de `offsetDays`. */
function yearsAgo(n, offsetDays = 0) {
  const d = new Date();
  d.setFullYear(d.getFullYear() - n);
  d.setDate(d.getDate() + offsetDays);
  return d;
}

await testEnv.clearFirestore();
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users', ALICE), { displayName: 'Alice', birthDate: yearsAgo(30) });
  await setDoc(doc(db, 'users', BOB), { displayName: 'Bob', birthDate: yearsAgo(31) });
  // Bob et Carol ont liké Alice ; Dave non.
  await setDoc(doc(db, 'swipes', BOB, 'actions', ALICE), { liked: true, targetUid: ALICE });
  await setDoc(doc(db, 'swipes', CAROL, 'actions', ALICE), { liked: true, targetUid: ALICE });
  await setDoc(doc(db, 'swipes', DAVE, 'actions', ALICE), { liked: false, targetUid: ALICE });
  await setDoc(doc(db, 'matches', MATCH_AB), { users: [ALICE, BOB], createdAt: new Date() });
  await setDoc(doc(db, 'matches', MATCH_AB, 'messages', 'm1'), {
    senderId: BOB, text: 'salut', sentAt: new Date(),
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

let pass = 0, fail = 0;
async function t(name, expect, fn) {
  try {
    await (expect === 'ok' ? assertSucceeds(fn()) : assertFails(fn()));
    pass++; console.log(`  PASS  ${name}`);
  } catch (e) {
    fail++; console.log(`  FAIL  ${name}\n        ${String(e).split('\n')[0]}`);
  }
}

console.log('\n[ anonyme : la faille constatee en production ]');
await t('lecture des profils refusee', 'ko', () => getDocs(collection(anon(), 'users')));
await t('lecture des matchs refusee', 'ko', () => getDoc(doc(anon(), 'matches', MATCH_AB)));
await t('lecture des messages refusee', 'ko',
  () => getDocs(collection(anon(), 'matches', MATCH_AB, 'messages')));
await t('ecriture de profil refusee', 'ko',
  () => setDoc(doc(anon(), 'users', ALICE), { displayName: 'pirate' }));

console.log('\n[ profils ]');
await t('un membre liste les profils (decouverte)', 'ok', () => getDocs(collection(as(ALICE), 'users')));
await t('un membre lit le profil d un autre', 'ok', () => getDoc(doc(as(ALICE), 'users', BOB)));
await t('ecriture de son propre profil', 'ok',
  () => setDoc(doc(as(ALICE), 'users', ALICE),
    { displayName: 'Alice B.', birthDate: yearsAgo(30) }, { merge: true }));
await t('ecriture du profil d un autre refusee', 'ko',
  () => setDoc(doc(as(ALICE), 'users', BOB),
    { displayName: 'pirate', birthDate: yearsAgo(30) }, { merge: true }));

console.log('\n[ age minimum, verifie par le serveur ]');
await t('un profil de moins de 18 ans est refuse', 'ko',
  () => setDoc(doc(as(ALICE), 'users', ALICE),
    { displayName: 'Alice', birthDate: yearsAgo(17) }, { merge: true }));
await t('la veille des 18 ans, encore refuse', 'ko',
  () => setDoc(doc(as(ALICE), 'users', ALICE),
    { displayName: 'Alice', birthDate: yearsAgo(18, 1) }, { merge: true }));
await t('le jour des 18 ans, accepte', 'ok',
  () => setDoc(doc(as(ALICE), 'users', ALICE),
    { displayName: 'Alice', birthDate: yearsAgo(18) }, { merge: true }));
await t('sans date de naissance, refuse', 'ko',
  () => setDoc(doc(as(ALICE), 'users', ALICE), { displayName: 'Alice' })); 

console.log('\n[ swipes ]');
await t('on enregistre son propre swipe', 'ok',
  () => setDoc(doc(as(ALICE), 'swipes', ALICE, 'actions', BOB),
    { liked: true, targetUid: BOB }));
await t('un swipe dont la cible ne correspond pas au document est refuse', 'ko',
  () => setDoc(doc(as(ALICE), 'swipes', ALICE, 'actions', CAROL),
    { liked: true, targetUid: DAVE }));
await t('hasLikedMe : on lit le swipe qui nous vise', 'ok',
  () => getDoc(doc(as(ALICE), 'swipes', BOB, 'actions', ALICE)));
await t('lecture du swipe d autrui sur un tiers refusee', 'ko',
  () => getDoc(doc(as(DAVE), 'swipes', BOB, 'actions', ALICE)));
await t('ecriture d un swipe au nom d un autre refusee', 'ko',
  () => setDoc(doc(as(ALICE), 'swipes', BOB, 'actions', CAROL),
    { liked: true, targetUid: CAROL }));

console.log('\n[ matchs ]');
await t('createMatch : lecture prealable d un doc inexistant', 'ok',
  () => getDoc(doc(as(ALICE), 'matches', 'alice_carol')));
await t('creation avec like reciproque', 'ok',
  () => setDoc(doc(as(ALICE), 'matches', 'alice_carol'),
    { users: [ALICE, CAROL], createdAt: new Date() }));
await t('creation sans like reciproque refusee', 'ko',
  () => setDoc(doc(as(ALICE), 'matches', 'alice_dave'),
    { users: [ALICE, DAVE], createdAt: new Date() }));
await t('creation d un match entre tiers refusee', 'ko',
  () => setDoc(doc(as(ALICE), 'matches', 'bob_carol'),
    { users: [BOB, CAROL], createdAt: new Date() }));
await t('watchMatchesForUser : requete sur ses propres matchs', 'ok',
  () => getDocs(query(collection(as(ALICE), 'matches'), where('users', 'array-contains', ALICE))));
await t('requete sur les matchs d un autre refusee', 'ko',
  () => getDocs(query(collection(as(ALICE), 'matches'), where('users', 'array-contains', BOB))));
await t('lecture du match d autrui refusee', 'ko',
  () => getDoc(doc(as(DAVE), 'matches', MATCH_AB)));
await t('sendMessage : mise a jour du dernier message', 'ok',
  () => updateDoc(doc(as(ALICE), 'matches', MATCH_AB), { lastMessage: 'coucou', lastMessageAt: new Date() }));
await t('modification des participants refusee', 'ko',
  () => updateDoc(doc(as(ALICE), 'matches', MATCH_AB), { users: [ALICE, DAVE] }));
await t('suppression d un match refusee', 'ko',
  () => deleteDoc(doc(as(ALICE), 'matches', MATCH_AB)));

console.log('\n[ messages ]');
await t('un participant lit la conversation', 'ok',
  () => getDocs(collection(as(ALICE), 'matches', MATCH_AB, 'messages')));
await t('un participant envoie un message', 'ok',
  () => addDoc(collection(as(ALICE), 'matches', MATCH_AB, 'messages'),
    { senderId: ALICE, text: 'hello', sentAt: new Date() }));
await t('message signe au nom d un autre refuse', 'ko',
  () => addDoc(collection(as(ALICE), 'matches', MATCH_AB, 'messages'),
    { senderId: BOB, text: 'faux', sentAt: new Date() }));
await t('lecture par un tiers refusee', 'ko',
  () => getDocs(collection(as(DAVE), 'matches', MATCH_AB, 'messages')));
await t('envoi par un tiers refuse', 'ko',
  () => addDoc(collection(as(DAVE), 'matches', MATCH_AB, 'messages'),
    { senderId: DAVE, text: 'intrus', sentAt: new Date() }));
await t('modification d un message envoye refusee', 'ko',
  () => updateDoc(doc(as(BOB), 'matches', MATCH_AB, 'messages', 'm1'), { text: 'edite' }));

console.log('\n[ blocage ]');
await t('on bloque quelqu un', 'ok',
  () => setDoc(doc(as(ALICE), 'blocks', 'alice_carol'),
    { users: [ALICE, CAROL], blockedBy: ALICE, createdAt: new Date() }));
await t('la personne bloquee voit le blocage', 'ok',
  () => getDoc(doc(as(CAROL), 'blocks', 'alice_carol')));
await t('un tiers ne voit pas le blocage', 'ko',
  () => getDoc(doc(as(DAVE), 'blocks', 'alice_carol')));
await t('bloquer une paire dont on ne fait pas partie refuse', 'ko',
  () => setDoc(doc(as(DAVE), 'blocks', 'bob_carol'),
    { users: [BOB, CAROL], blockedBy: BOB, createdAt: new Date() }));
await t('se declarer auteur d un blocage sans l etre refuse', 'ko',
  () => setDoc(doc(as(DAVE), 'blocks', 'alice_bob'),
    { users: [ALICE, BOB], blockedBy: DAVE, createdAt: new Date() }));
await t('message refuse une fois le blocage pose', 'ko',
  () => addDoc(collection(as(ALICE), 'matches', 'alice_carol', 'messages'),
    { senderId: ALICE, text: 'malgre tout', sentAt: new Date() }));
await t('la personne bloquee ne peut pas lever le blocage', 'ko',
  () => deleteDoc(doc(as(CAROL), 'blocks', 'alice_carol')));
await t('l auteur du blocage peut le lever', 'ok',
  () => deleteDoc(doc(as(ALICE), 'blocks', 'alice_carol')));
await t('le message repasse une fois le blocage leve', 'ok',
  () => addDoc(collection(as(ALICE), 'matches', 'alice_carol', 'messages'),
    { senderId: ALICE, text: 'de nouveau', sentAt: new Date() }));

console.log('\n[ signalements ]');
await t('on signale quelqu un', 'ok',
  () => addDoc(collection(as(ALICE), 'reports'),
    { reporterUid: ALICE, reportedUid: BOB, reason: 'photo choquante', createdAt: new Date() }));
await t('signaler au nom d un autre refuse', 'ko',
  () => addDoc(collection(as(ALICE), 'reports'),
    { reporterUid: BOB, reportedUid: CAROL, reason: 'x', createdAt: new Date() }));
await t('se signaler soi-meme refuse', 'ko',
  () => addDoc(collection(as(ALICE), 'reports'),
    { reporterUid: ALICE, reportedUid: ALICE, reason: 'x', createdAt: new Date() }));
await t('relire les signalements refuse', 'ko',
  () => getDocs(collection(as(ALICE), 'reports')));

console.log('\n[ retrait d un match ]');
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), 'matches', 'alice_dave'),
    { users: [ALICE, DAVE], createdAt: new Date() });
});
await t('un tiers ne peut pas rompre le match', 'ko',
  () => updateDoc(doc(as(BOB), 'matches', 'alice_dave'),
    { endedAt: new Date(), endedBy: BOB }));
await t('un participant se retire du match', 'ok',
  () => updateDoc(doc(as(ALICE), 'matches', 'alice_dave'),
    { endedAt: new Date(), endedBy: ALICE }));
await t('message refuse une fois le match rompu', 'ko',
  () => addDoc(collection(as(DAVE), 'matches', 'alice_dave', 'messages'),
    { senderId: DAVE, text: 'encore la ?', sentAt: new Date() }));
await t('un retrait ne se defait pas', 'ko',
  () => updateDoc(doc(as(ALICE), 'matches', 'alice_dave'),
    { endedAt: deleteField() }));

console.log('\n[ jetons de notification ]');
await t('on enregistre le jeton de son appareil', 'ok',
  () => setDoc(doc(as(ALICE), 'users', ALICE, 'devices', 'jeton-alice'),
    { platform: 'android', updatedAt: new Date() }));
await t('enregistrer un jeton chez quelqu un d autre refuse', 'ko',
  () => setDoc(doc(as(DAVE), 'users', ALICE, 'devices', 'jeton-pirate'),
    { platform: 'android', updatedAt: new Date() }));
await t('lire les jetons d un autre refuse', 'ko',
  () => getDocs(collection(as(DAVE), 'users', ALICE, 'devices')));
await t('on relit ses propres jetons', 'ok',
  () => getDocs(collection(as(ALICE), 'users', ALICE, 'devices')));
await t('on retire le jeton de son appareil', 'ok',
  () => deleteDoc(doc(as(ALICE), 'users', ALICE, 'devices', 'jeton-alice')));

await testEnv.cleanup();
console.log(`\n${pass} reussis, ${fail} echoues\n`);
process.exit(fail === 0 ? 0 : 1);
