const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

const db = getFirestore();

exports.cancelAssistanceRequest = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in to cancel your request.');
  const requestId = String(request.data?.requestId || '');
  if (!requestId) throw new HttpsError('invalid-argument', 'A request ID is required.');
  const ref = db.collection('requests').doc(requestId);
  const snapshot = await ref.get();
  if (!snapshot.exists) throw new HttpsError('not-found', 'Assistance request was not found.');
  const data = snapshot.data();
  if (data.passengerId !== request.auth.uid) throw new HttpsError('permission-denied', 'You can only cancel your own request.');
  if (['Boarded', 'Completed', 'Cancelled'].includes(String(data.status || ''))) throw new HttpsError('failed-precondition', 'This request can no longer be cancelled.');
  await ref.update({ status: 'Cancelled', cancelledAt: FieldValue.serverTimestamp(), cancelledBy: request.auth.uid });
  await ref.collection('events').add({ status: 'Cancelled', actorId: request.auth.uid, actorRole: 'passenger', createdAt: FieldValue.serverTimestamp() });
  return { status: 'Cancelled' };
});
