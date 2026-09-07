const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');

initializeApp();

const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();
const railRadarApiKey = defineSecret('RAILRADAR_API_KEY');

function cleanTokens(tokens) { return [...new Set(tokens.filter((token) => typeof token === 'string' && token.trim()))]; }
async function sendToTokens(tokens, title, body, data) {
  const cleanedTokens = cleanTokens(tokens);
  if (cleanedTokens.length === 0) return;
  const response = await messaging.sendEachForMulticast({ tokens: cleanedTokens, notification: { title, body }, data, android: { priority: 'high', notification: { channelId: 'rail_sahayak_notifications', sound: 'default' } } });
  logger.info('FCM notification result', { successCount: response.successCount, failureCount: response.failureCount });
}
async function sendToUsersByRoles(roles, title, body, data) {
  const tokens = [];
  for (const role of roles) {
    const snapshot = await db.collection('users').where('role', '==', role).get();
    snapshot.docs.forEach((doc) => { const token = doc.data()?.fcmToken; if (token) tokens.push(token); });
  }
  await sendToTokens(tokens, title, body, data);
}
function istDateKey(date = new Date()) { return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(date); }
function requestDateKey(value) { if (!value) return ''; const date = value.toDate ? value.toDate() : new Date(value); return Number.isNaN(date.getTime()) ? '' : istDateKey(date); }
async function writeAudit(requestId, status, actor) { await db.collection('requests').doc(requestId).collection('events').add({ status, actorId: actor.uid, actorRole: actor.role, createdAt: FieldValue.serverTimestamp() }); }
async function getRequestForUser(requestId, uid) {
  const ref = db.collection('requests').doc(requestId);
  const snapshot = await ref.get();
  if (!snapshot.exists) throw new HttpsError('not-found', 'Assistance request was not found.');
  const data = snapshot.data();
  if (data.passengerId !== uid) throw new HttpsError('permission-denied', 'You can only manage your own assistance request.');
  return { ref, data };
}

exports.createStaffAccount = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in as an administrator.');
  const adminDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!adminDoc.exists || String(adminDoc.data()?.role || '').toLowerCase() !== 'admin') throw new HttpsError('permission-denied', 'Only administrators can create staff accounts.');
  const data = request.data || {};
  const name = String(data.name || '').trim(); const email = String(data.email || '').trim().toLowerCase(); const password = String(data.password || ''); const phone = String(data.phone || '').trim();
  if (name.length < 2) throw new HttpsError('invalid-argument', 'Enter the staff member’s name.');
  if (!/^\S+@\S+\.\S+$/.test(email)) throw new HttpsError('invalid-argument', 'Enter a valid company email address.');
  if (password.length < 6) throw new HttpsError('invalid-argument', 'Temporary password must contain at least 6 characters.');
  let userRecord;
  try { userRecord = await auth.createUser({ email, password, displayName: name }); }
  catch (error) { if (error?.code === 'auth/email-already-exists') throw new HttpsError('already-exists', 'A Firebase account already exists for this email.'); logger.error('Could not create staff account', error); throw new HttpsError('internal', 'Could not create the staff account.'); }
  await db.collection('users').doc(userRecord.uid).set({ name, username: '', email, phone, role: 'staff', status: 'approved', createdBy: request.auth.uid, createdAt: FieldValue.serverTimestamp(), disabilityType: null, preferredAssistance: null });
  return { uid: userRecord.uid, email, role: 'staff', status: 'approved' };
});

exports.notifyStaffOfNewRequest = onDocumentCreated('requests/{requestId}', async (event) => {
  const snapshot = event.data; if (!snapshot) return; const request = snapshot.data(); if (!request) return;
  const staffSnapshot = await db.collection('users').where('role', '==', 'staff').get(); const staffTokens = staffSnapshot.docs.map((doc) => doc.data().fcmToken).filter(Boolean);
  await sendToTokens(staffTokens, 'New Assistance Request', `${request.passengerName || 'A passenger'} needs assistance on ${request.trainNo || 'your train'}, ${request.coach || 'coach not specified'}.`, { type: 'new_assistance_request', requestId: event.params.requestId, status: String(request.status || 'Requested') });
});

exports.notifyPassengerOfRequestStatus = onDocumentUpdated('requests/{requestId}', async (event) => {
  const before = event.data?.before.data(); const after = event.data?.after.data(); if (!before || !after || before.status === after.status) return;
  const requestId = event.params.requestId; const status = String(after.status || 'Updated'); const passengerId = after.passengerId; const staffName = String(after.staffName || 'Railway staff');
  if (passengerId) {
    const passengerDoc = await db.collection('users').doc(passengerId).get(); const token = passengerDoc.exists ? passengerDoc.data()?.fcmToken : null;
    if (token) {
      let body = `Your assistance request is now ${status}.`;
      if (status === 'At Station') body = 'Staff have been alerted that you are at the station. Please remain at your stated location.';
      if (status === 'Assigned') body = `${staffName} has acknowledged your request and will assist you.`;
      if (status === 'Located') body = `${staffName} has located you and is ready to assist.`;
      if (status === 'Boarding') body = 'Boarding assistance has started.';
      if (status === 'Boarded') body = 'You have been marked as boarded. Have a safe journey.';
      if (status === 'Completed') body = 'Your assistance request has been completed.';
      if (status === 'Escalated') body = 'Your assistance request has been escalated to station supervision.';
      await messaging.send({ token, notification: { title: 'RailSahayak Request Update', body }, data: { type: 'request_status_update', requestId, status }, android: { priority: 'high', notification: { channelId: 'rail_sahayak_notifications', sound: 'default' } } });
    }
  }
  if (status === 'At Station') {
    const station = String(after.boardingStation || 'your boarding station'); const location = String(after.currentLocation || 'Location not specified'); const platform = String(after.platform || 'Platform not specified');
    const staffSnapshot = await db.collection('users').where('role', '==', 'staff').get(); const staffTokens = staffSnapshot.docs.map((doc) => doc.data()?.fcmToken).filter(Boolean);
    await sendToTokens(staffTokens, 'Passenger Ready for Assistance', `${after.passengerName || 'Passenger'} is at ${station}. ${platform}. ${location}. Train ${after.trainNumber || after.trainNo || ''}, ${after.coach || ''}, Seat ${after.seat || 'not specified'}.`, { type: 'passenger_at_station', requestId, status, trainNumber: String(after.trainNumber || ''), boardingStation: station });
  }
});

exports.markPassengerAtStation = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in to notify railway staff.');
  const { ref, data } = await getRequestForUser(String(request.data?.requestId || ''), request.auth.uid);
  if (!['Requested', 'Assigned'].includes(String(data.status || 'Requested'))) throw new HttpsError('failed-precondition', 'This assistance request is no longer waiting for your arrival.');
  if (requestDateKey(data.journeyDate) !== istDateKey()) throw new HttpsError('failed-precondition', 'The “I’m at the station” action is available on your journey date.');
  const last = data.atStationAt?.toDate ? data.atStationAt.toDate() : null;
  if (last && Date.now() - last.getTime() < 2 * 60 * 1000) throw new HttpsError('resource-exhausted', 'Please wait before sending another arrival notification.');
  await ref.update({ status: 'At Station', atStationAt: FieldValue.serverTimestamp(), platform: String(request.data?.platform || '').trim().slice(0, 40), currentLocation: String(request.data?.location || '').trim().slice(0, 120) });
  await writeAudit(ref.id, 'At Station', { uid: request.auth.uid, role: 'passenger' });
  return { status: 'At Station' };
});

exports.updateAssistanceStatus = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in to update assistance.');
  const uid = request.auth.uid; const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists || String(userDoc.data()?.role || '').toLowerCase() !== 'staff') throw new HttpsError('permission-denied', 'Only railway staff can perform boarding workflow actions.');
  const requestId = String(request.data?.requestId || ''); const nextStatus = String(request.data?.status || ''); const ref = db.collection('requests').doc(requestId); const staffName = String(userDoc.data()?.name || 'Railway Staff'); let previousStatus = '';
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref); if (!snapshot.exists) throw new HttpsError('not-found', 'Assistance request was not found.'); const data = snapshot.data(); previousStatus = String(data.status || 'Requested');
    const allowed = { Requested: ['Assigned'], 'At Station': ['Assigned'], Assigned: ['Located'], Located: ['Boarding'], Boarding: ['Boarded'], Boarded: ['Completed'] };
    if (!allowed[previousStatus]?.includes(nextStatus)) throw new HttpsError('failed-precondition', `Cannot move this request from ${previousStatus} to ${nextStatus}.`);
    const update = { status: nextStatus, staffId: uid, staffName }; const nowField = { Assigned: 'acknowledgedAt', Located: 'locatedAt', Boarding: 'boardingAt', Boarded: 'boardedAt', Completed: 'completedAt' }[nextStatus]; if (nowField) update[nowField] = FieldValue.serverTimestamp(); transaction.update(ref, update);
  });
  await writeAudit(requestId, nextStatus, { uid, role: 'staff' }); return { status: nextStatus };
});

exports.escalateAssistanceRequest = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in to escalate assistance.'); const uid = request.auth.uid; const staffDoc = await db.collection('users').doc(uid).get();
  if (!staffDoc.exists || String(staffDoc.data()?.role || '').toLowerCase() !== 'staff') throw new HttpsError('permission-denied', 'Only railway staff can escalate assistance.');
  const requestId = String(request.data?.requestId || ''); const ref = db.collection('requests').doc(requestId); const snapshot = await ref.get(); if (!snapshot.exists) throw new HttpsError('not-found', 'Assistance request was not found.'); const data = snapshot.data();
  if (!['At Station', 'Assigned', 'Located', 'Boarding'].includes(String(data.status || ''))) throw new HttpsError('failed-precondition', 'This request cannot be escalated in its current state.');
  await ref.update({ status: 'Escalated', escalatedAt: FieldValue.serverTimestamp(), escalatedBy: uid }); await writeAudit(requestId, 'Escalated', { uid, role: 'staff' });
  await sendToUsersByRoles(['supervisor', 'authority'], 'Assistance Escalation', `${data.passengerName || 'Passenger'} needs urgent assistance for train ${data.trainNumber || data.trainNo || ''} at ${data.boardingStation || 'the station'}.`, { type: 'assistance_escalation', requestId, status: 'Escalated' });
  return { status: 'Escalated' };
});

exports.getTrainInfo = onCall({ secrets: [railRadarApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in to view train information.'); const trainNumber = String(request.data?.trainNumber || '').replace(/\D/g, ''); if (!/^\d{5}$/.test(trainNumber)) throw new HttpsError('invalid-argument', 'A valid 5-digit train number is required.');
  const apiKey = railRadarApiKey.value().trim(); const baseUrl = String(process.env.RAILRADAR_API_BASE_URL || 'https://api.railradar.in/v1').replace(/\/$/, ''); if (!apiKey) throw new HttpsError('failed-precondition', 'Live train data is not configured yet.');
  try { const response = await fetch(`${baseUrl}/legacy/trains/${trainNumber}?dataType=full`, { headers: { Authorization: `Bearer ${apiKey}`, Accept: 'application/json' } }); if (!response.ok) { if (response.status === 404) throw new HttpsError('not-found', 'Train information was not found.'); if (response.status === 429) throw new HttpsError('resource-exhausted', 'Train data is temporarily rate limited.'); throw new HttpsError('unavailable', 'Train information is temporarily unavailable.'); } const payload = await response.json(); if (!payload?.success || !payload?.data) throw new HttpsError('not-found', 'Train information was not found.'); return payload.data; }
  catch (error) { if (error instanceof HttpsError) throw error; logger.error('Train information lookup failed', { error, trainNumber }); throw new HttpsError('unavailable', 'Unable to retrieve train information right now.'); }
});

Object.assign(exports, require('./cancel_assistance'));
