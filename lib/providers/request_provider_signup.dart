import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'request_provider.dart';

/// Passenger registration lives in an extension so the existing provider
/// remains focused on authentication, requests, notifications and admin data.
extension PassengerSignup on RequestProvider {
  Future<bool> signup({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    if (role != UserRole.passenger) return false;

    final cleanName = name.trim();
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');

    if (cleanName.isEmpty ||
        cleanUsername.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername) ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail) ||
        !RegExp(r'^\d{10}$').hasMatch(cleanPhone) ||
        password.length < 6) {
      return false;
    }

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    try {
      final existingUsername = await firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();
      if (existingUsername.docs.isNotEmpty) return false;

      final credential = await auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) return false;

      await firebaseUser.updateDisplayName(cleanName);

      await firestore.collection('users').doc(firebaseUser.uid).set({
        'name': cleanName,
        'username': cleanUsername,
        'email': cleanEmail,
        'phone': cleanPhone,
        'role': 'passenger',
        'disabilityType': null,
        'preferredAssistance': null,
      }, SetOptions(merge: true));

      return true;
    } on FirebaseAuthException catch (_) {
      return false;
    } catch (_) {
      try {
        await auth.currentUser?.delete();
      } catch (_) {}
      return false;
    }
  }
}
