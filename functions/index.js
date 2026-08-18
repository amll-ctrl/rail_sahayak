const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');

initializeApp();

const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

function cleanTokens(tokens) {
  return [...new Set(tokens.filter((token) => typeof token === 'string' && token.trim()))];
}

async function sendToTokens(tokens, title, body, data) {
  const cleanedTokens = cleanTokens(tokens);
  if (cleanedTokens.length === 0) {
    logger.info('No FCM tokens available for notification.');
    return;
  }

  const response = await messaging.sendEachForMulticast({
    tokens: cleanedTokens,
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: { channelId: 'rail_sahayak_notifications', sound: 'default' },
    },
  });

  logger.info('FCM notification result', {
    successCount: response.successCount,
    failureCount: response.failureCount,
  });
}

// Only an authenticated RailSahayak administrator can create staff accounts.
// Passwords are sent to Firebase Auth and are never written to Firestore.
exports.createStaffAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Please sign in as an administrator.');
  }

  const adminDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!adminDoc.exists || String(adminDoc.data()?.role || '').toLowerCase() !== 'admin') {
    throw new HttpsError('permission-denied', 'Only administrators can create staff accounts.');
  }

  const data = request.data || {};
  const name = String(data.name || '').trim();
  const email = String(data.email || '').trim().toLowerCase();
  const password = String(data.password || '');
  const phone = String(data.phone || '').trim();

  if (name.length < 2) {
    throw new HttpsError('invalid-argument', 'Enter the staff member’s name.');
  }
  if (!/^\S+@\S+\.\S+$/.test(email)) {
    throw new HttpsError('invalid-argument', 'Enter a valid company email address.');
  }
  if (password.length < 6) {
    throw new HttpsError('invalid-argument', 'Temporary password must contain at least 6 characters.');
  }

  let userRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });
  } catch (error) {
    if (error?.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'A Firebase account already exists for this email.');
    }
    logger.error('Could not create staff account', error);
    throw new HttpsError('internal', 'Could not create the staff account.');
  }

  await db.collection('users').doc(userRecord.uid).set({
    name,
    username: '',
    email,
    phone,
    role: 'staff',
    status: 'approved',
    createdBy: request.auth.uid,
    createdAt: FieldValue.serverTimestamp(),
    disabilityType: null,
    preferredAssistance: null,
  });

  return { uid: userRecord.uid, email, role: 'staff', status: 'approved' };
});

exports.notifyStaffOfNewRequest = onDocumentCreated('requests/{requestId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const request = snapshot.data();
  if (!request) return;

  const staffSnapshot = await db.collection('users').where('role', '==', 'staff').get();
  const staffTokens = staffSnapshot.docs.map((doc) => doc.data().fcmToken).filter(Boolean);
  const train = request.trainNo || 'your train';
  const coach = request.coach || 'coach not specified';
  const passenger = request.passengerName || 'A passenger';

  await sendToTokens(staffTokens, 'New Assistance Request', `${passenger} needs assistance on ${train}, ${coach}.`, {
    type: 'new_assistance_request',
    requestId: event.params.requestId,
    status: String(request.status || 'Requested'),
  });
});

exports.notifyPassengerOfRequestStatus = onDocumentUpdated('requests/{requestId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;

  const passengerId = after.passengerId;
  if (!passengerId) return;
  const passengerDoc = await db.collection('users').doc(passengerId).get();
  if (!passengerDoc.exists) return;
  const token = passengerDoc.data()?.fcmToken;
  if (!token) return;

  const status = String(after.status || 'Updated');
  const staffName = String(after.staffName || 'Railway staff');
  let body = `Your assistance request is now ${status}.`;
  if (status.toLowerCase() === 'assigned') body = `${staffName} has been assigned to assist you.`;
  if (status.toLowerCase() === 'completed') body = 'Your assistance request has been completed.';

  await messaging.send({
    token,
    notification: { title: 'RailSahayak Request Update', body },
    data: { type: 'request_status_update', requestId: event.params.requestId, status },
    android: {
      priority: 'high',
      notification: { channelId: 'rail_sahayak_notifications', sound: 'default' },
    },
  });
});
