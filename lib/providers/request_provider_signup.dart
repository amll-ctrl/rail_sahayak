import 'dart:async';

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
      return 'Username must be at least 3 characters and use only letters, numbers and _.';
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
    const timeout = Duration(seconds: 20);

    try {
      // A username lookup is helpful, but a Firestore read failure must not
      // prevent Firebase Auth from creating a valid passenger account.
      try {
        final existingUsername = await firestore
            .collection('users')
            .where('username', isEqualTo: cleanUsername)
            .limit(1)
            .get()
            .timeout(timeout);
        if (existingUsername.docs.isNotEmpty) {
          return 'That username is already registered. Please choose another one.';
        }
      } on FirebaseException catch (e) {
        // Continue to the authenticated profile write below. This avoids a
        // signup dead-end when Firestore rules permit creating one's own
        // profile but do not permit querying every user document.
        if (e.code != 'permission-denied') rethrow;
      }

      final credential = await auth
          .createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          )
          .timeout(timeout);
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return 'Firebase did not create the account. Please try again.';
      }

      await firebaseUser.updateDisplayName(cleanName).timeout(timeout);

      final profile = UserProfile(
        id: firebaseUser.uid,
        name: cleanName,
        username: cleanUsername,
        email: cleanEmail,
        phone: cleanPhone,
        role: UserRole.passenger,
      );

      await firestore.collection('users').doc(firebaseUser.uid).set({
        ...profile.toMap(),
        'role': 'passenger',
        'disabilityType': null,
        'preferredAssistance': null,
      }, SetOptions(merge: true)).timeout(timeout);

      // Keep Provider, Firebase Auth and the app router in the same session.
      // Previously the account could be created successfully while the app
      // continued waiting on an uninitialized provider session.
      await completePassengerSignupSession(profile);
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
    } on TimeoutException {
      return 'Firebase is taking too long to respond. Check your internet connection and try again.';
    } on FirebaseException catch (e) {
      return 'Your Firebase account was created, but the passenger profile could not be saved (${e.code}). Check your Firestore rules and try logging in again.';
    } catch (_) {
      return 'The account could not be saved. Please try again.';
    }
  }
}
