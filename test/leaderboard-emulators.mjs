import assert from 'node:assert/strict';
import test from 'node:test';

const project = 'demo-number-slide-pro';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
assert.ok(firestoreHost && authHost, 'Run this test with the Auth and Firestore emulators.');
const database = `projects/${project}/databases/(default)`;
const documents = `http://${firestoreHost}/v1/${database}/documents`;

async function signIn() {
  const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({returnSecureToken: true}),
  });
  const user = await response.json();
  assert.equal(response.status, 200, JSON.stringify(user));
  assert.ok(user.idToken && user.localId);
  return user;
}

async function request(endpoint, user, payload) {
  const headers = {'Content-Type': 'application/json'};
  if (user) headers.Authorization = 'Bearer ' + user.idToken;
  const response = await fetch(documents + endpoint, {
    method: payload ? 'POST' : 'GET', headers,
    body: payload ? JSON.stringify(payload) : undefined,
  });
  return {status: response.status, body: await response.json()};
}

async function score(user, owner, size, points, overrides = {}) {
  const name = `${database}/documents/leaderboard/${owner.localId}_${size}`;
  return request(':commit', user, {writes: [{
    update: {name, fields: {
      uid: {stringValue: owner.localId}, name: {stringValue: 'Player'},
      size: {integerValue: String(size)}, score: {integerValue: String(points)},
      ...overrides,
    }},
    updateTransforms: [{fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME'}],
  }]});
}

function ranking(user, size, limit = 50) {
  return request(':runQuery', user, {structuredQuery: {
    from: [{collectionId: 'leaderboard'}],
    where: {fieldFilter: {field: {fieldPath: 'size'}, op: 'EQUAL', value: {integerValue: String(size)}}},
    orderBy: [{field: {fieldPath: 'score'}, direction: 'DESCENDING'}], limit,
  }});
}

function expectStatus(response, expected) {
  assert.equal(response.status, expected, JSON.stringify(response.body));
}

test('anonymous players can rank their best scores only on their own boards', async () => {
  const first = await signIn();
  const second = await signIn();
  const entry = '/leaderboard/' + first.localId + '_3';
  expectStatus(await request(entry, first), 404);
  expectStatus(await score(first, first, 3, 400), 200);
  expectStatus(await score(first, first, 3, 600), 200);
  expectStatus(await score(first, first, 3, 500), 403);
  expectStatus(await score(first, first, 3, 600), 403);
  expectStatus(await score(second, first, 3, 700), 403);
  expectStatus(await score(first, first, 3, 1000), 403);
  expectStatus(await score(first, first, 3, 602), 403);
  expectStatus(await score(first, first, 3, 650, {extra: {booleanValue: true}}), 403);
  expectStatus(await score(second, second, 3, 750), 200);
  expectStatus(await score(first, first, 5, 1), 200);
  expectStatus(await score(null, first, 3, 650), 403);
  expectStatus(await request(entry, null), 403);
  expectStatus(await ranking(null, 3), 403);
  expectStatus(await ranking(first, 3, 51), 403);
  expectStatus(await request(':commit', first, {writes: [{delete: database + '/documents' + entry}]}), 403);
  const top = await ranking(second, 3);
  expectStatus(top, 200);
  assert.deepEqual(top.body.map(row => Number(row.document.fields.score.integerValue)), [750, 600]);
});
