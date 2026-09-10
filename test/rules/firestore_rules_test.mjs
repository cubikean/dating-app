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
  collection, collectionGroup, query, where, getDocs, addDoc,
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

await testEnv.clearFirestore();
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users', ALICE), { displayName: 'Alice' });
  await setDoc(doc(db, 'users', BOB), { displayName: 'Bob' });
  // Bob et Carol ont liké Alice ; Dave non.
  await setDoc(doc(db, 'swipes', BOB, 'actions', ALICE), { liked: true });
  await setDoc(doc(db, 'swipes', CAROL, 'actions', ALICE), { liked: true });
  await setDoc(doc(db, 'swipes', DAVE, 'actions', ALICE), { liked: false });
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
  () => setDoc(doc(as(ALICE), 'users', ALICE), { displayName: 'Alice B.' }, { merge: true }));
await t('ecriture du profil d un autre refusee', 'ko',
  () => setDoc(doc(as(ALICE), 'users', BOB), { displayName: 'pirate' }, { merge: true }));

console.log('\n[ swipes ]');
await t('on enregistre son propre swipe', 'ok',
  () => setDoc(doc(as(ALICE), 'swipes', ALICE, 'actions', BOB), { liked: true }));
await t('hasLikedMe : on lit le swipe qui nous vise', 'ok',
  () => getDoc(doc(as(ALICE), 'swipes', BOB, 'actions', ALICE)));
await t('lecture du swipe d autrui sur un tiers refusee', 'ko',
  () => getDoc(doc(as(DAVE), 'swipes', BOB, 'actions', ALICE)));
await t('ecriture d un swipe au nom d un autre refusee', 'ko',
  () => setDoc(doc(as(ALICE), 'swipes', BOB, 'actions', CAROL), { liked: true }));

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

await testEnv.cleanup();
console.log(`\n${pass} reussis, ${fail} echoues\n`);
process.exit(fail === 0 ? 0 : 1);
