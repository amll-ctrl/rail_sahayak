import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssistanceWorkflowService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> markPassengerAtStation({required String requestId, String? platform, String? location}) async {
    try {
      await _functions.httpsCallable('markPassengerAtStation').call({
        'requestId': requestId,
        'platform': platform?.trim() ?? '',
        'location': location?.trim() ?? '',
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') rethrow;
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'At Station',
        'atStationAt': FieldValue.serverTimestamp(),
        'platform': platform?.trim() ?? '',
        'currentLocation': location?.trim() ?? '',
      });
    }
  }

  Future<void> updateStatus(String requestId, String status) async {
    if (status == 'Cancelled') {
      await cancel(requestId);
      return;
    }
    try {
      await _functions.httpsCallable('updateAssistanceStatus').call({
        'requestId': requestId,
        'status': status,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') rethrow;
      final uid = _auth.currentUser?.uid;
      final data = <String, dynamic>{
        'status': status,
        if (uid != null) 'staffId': uid,
      };
      final nowField = <String, String>{
        'Assigned': 'acknowledgedAt',
        'Located': 'locatedAt',
        'Boarding': 'boardingAt',
        'Boarded': 'boardedAt',
        'Completed': 'completedAt',
      }[status];
      if (nowField != null) data[nowField] = FieldValue.serverTimestamp();
      if (uid != null) {
        final staffDoc = await _firestore.collection('users').doc(uid).get();
        if (staffDoc.exists) data['staffName'] = staffDoc.data()?['name'] ?? 'Railway Staff';
      }
      await _firestore.collection('requests').doc(requestId).update(data);
    }
  }

  Future<void> cancel(String requestId) async {
    try {
      await _functions.httpsCallable('cancelAssistanceRequest').call({'requestId': requestId});
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') rethrow;
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> escalate(String requestId) async {
    try {
      await _functions.httpsCallable('escalateAssistanceRequest').call({'requestId': requestId});
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') rethrow;
      final uid = _auth.currentUser?.uid;
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'Escalated',
        'escalatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'escalatedBy': uid,
      });
    }
  }
}
