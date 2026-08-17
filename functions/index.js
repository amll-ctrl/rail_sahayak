const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');

initializeApp();

const db = getFirestore();
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
      notification: {
        channelId: 'rail_sahayak_notifications',
        sound: 'default',
      },
    },
  });

  logger.info('FCM notification result', {
    successCount: response.successCount,
    failureCount: response.failureCount,
  });
}

exports.notifyStaffOfNewRequest = onDocumentCreated(
  'requests/{requestId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const request = snapshot.data();
    if (!request) return;

    const staffSnapshot = await db
      .collection('users')
      .where('role', '==', 'staff')
      .get();

    const staffTokens = staffSnapshot.docs
      .map((doc) => doc.data().fcmToken)
      .filter(Boolean);

    const train = request.trainNo || 'your train';
    const coach = request.coach || 'coach not specified';
    const passenger = request.passengerName || 'A passenger';

    await sendToTokens(
      staffTokens,
      'New Assistance Request',
      `${passenger} needs assistance on ${train}, ${coach}.`,
      {
        type: 'new_assistance_request',
        requestId: event.params.requestId,
        status: String(request.status || 'Requested'),
      },
    );
  },
);

exports.notifyPassengerOfRequestStatus = onDocumentUpdated(
  'requests/{requestId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;
    if (before.status === after.status) return;

    const passengerId = after.passengerId;
    if (!passengerId) return;

    const passengerDoc = await db
      .collection('users')
      .doc(passengerId)
      .get();

    if (!passengerDoc.exists) return;

    const token = passengerDoc.data()?.fcmToken;
    if (!token) {
      logger.info('Passenger has no FCM token.', { passengerId });
      return;
    }

    const status = String(after.status || 'Updated');
    const staffName = String(after.staffName || 'Railway staff');

    let body = `Your assistance request is now ${status}.`;

    if (status.toLowerCase() === 'assigned') {
      body = `${staffName} has been assigned to assist you.`;
    } else if (status.toLowerCase() === 'completed') {
      body = 'Your assistance request has been completed.';
    }

    await messaging.send({
      token,
      notification: {
        title: 'RailSahayak Request Update',
        body,
      },
      data: {
        type: 'request_status_update',
        requestId: event.params.requestId,
        status,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'rail_sahayak_notifications',
          sound: 'default',
        },
      },
    });
  },
);
