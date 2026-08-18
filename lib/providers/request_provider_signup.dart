import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'request_provider.dart';

/// Passenger registration lives in an extension so the existing provider
/// remains focused on authentication, requests, notifications and admin data.
extension PassengerSignup on RequestProvider {
  /// Returns null on success, otherwise a user-facing reason for failure.
  Future<String?> signup({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    if (role != UserRole.passenger) {
      return 'Only passenger accounts can be created here.';
    }

    final cleanName = name.trim();
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');

    if (cleanName.isEmpty) return 'Please enter your full name.';
    if (cleanUsername.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername)) {
      return 'Username must contain only letters, numbers and _.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      return 'Please enter a valid email address.';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(cleanPhone)) {
      return 'Please enter a valid 10-digit phone number.';
    }
    if (password.length < 6) return 'Password must be at least 6 characters.';

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    try {
      final existingUsername = await firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();
      if (existingUsername.docs.isNotEmpty) {
        return 'That username is already registered. Please choose another one.';
      }

      final credential = await auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return 'Firebase did not create the account. Please try again.';
      }

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

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email already has a RailSahayak account. Please log in instead.';
        case 'weak-password':
          return 'That password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'operation-not-allowed':
          return 'Email/password registration is disabled in Firebase.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection and try again.';
        default:
          return 'Could not create the account (${e.code}). Please try again.';
      }
    } catch (e) {
      // If Firestore fails after Firebase Auth created the user, remove the
      // partially-created Auth account so the email is not permanently stuck.
      try {
        await auth.currentUser?.delete();
      } catch (_) {}
      return 'The account could not be saved. Please try again.';
    }
  }
}
