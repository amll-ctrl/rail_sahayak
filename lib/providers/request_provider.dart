import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../models/assistance_request.dart';

class RequestProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  UserProfile? _currentUser;
  bool _isLoading = false;
  bool _needsProfileCompletion = false;
  bool _isSessionInitialized = false;

  String? _phoneVerificationId;
  int? _phoneResendToken;
  String? _pendingVerifiedPhone;
  bool _phoneVerificationInProgress = false;
  bool _phoneVerified = false;
  String? _phoneVerificationError;

  User? _pendingGoogleUser;
  String? _pendingGoogleEmail;
  String? _pendingGoogleName;

  final List<AssistanceRequest> _requests = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSubscription;

  final List<UserProfile> _adminStaffCandidates = [];
  bool _adminDataLoading = false;

  RequestProvider() {
    _restoreSession();
  }

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get needsProfileCompletion => _needsProfileCompletion;
  bool get needsGoogleProfileCompletion => _needsProfileCompletion;
  bool get isSessionInitialized => _isSessionInitialized;
  bool get phoneVerificationInProgress => _phoneVerificationInProgress;
  bool get phoneVerified => _phoneVerified;
  String? get phoneVerificationError => _phoneVerificationError;
  String get pendingGoogleName => _pendingGoogleName ?? '';
  String get pendingGoogleEmail => _pendingGoogleEmail ?? '';
  List<AssistanceRequest> get requests => List.unmodifiable(_requests);
  List<UserProfile> get adminStaffCandidates => List.unmodifiable(_adminStaffCandidates);
  bool get isAdminDataLoading => _adminDataLoading;

  List<AssistanceRequest> get passengerRequests {
    if (_currentUser == null) return [];
    return _requests.where((r) => r.passengerId == _currentUser!.id).toList();
  }

  List<AssistanceRequest> get staffRequests => List.unmodifiable(_requests);

  Future<void> completePassengerSignupSession(UserProfile user) async {
    _currentUser = user;
    _needsProfileCompletion = false;
    _clearPendingGoogleProfile();
    _isSessionInitialized = true;
    await _startRequestListener();
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return;

      await firebaseUser.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        _currentUser = null;
        _needsProfileCompletion = false;
        return;
      }

      final doc = await _firestore.collection('users').doc(refreshedUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final restoredName = (data['name'] ?? '').toString().trim().isNotEmpty
            ? (data['name'] ?? '').toString().trim()
            : ((refreshedUser.displayName ?? '').trim().isNotEmpty
                ? refreshedUser.displayName!.trim()
                : 'RailSahayak User');
        final restoredEmail = (data['email'] ?? '').toString().trim().isNotEmpty
            ? (data['email'] ?? '').toString().trim()
            : (refreshedUser.email ?? '').trim();

        _currentUser = UserProfile(
          id: refreshedUser.uid,
          name: restoredName,
          username: (data['username'] ?? '').toString(),
          email: restoredEmail,
          phone: (data['phone'] ?? '').toString(),
          role: UserProfile.fromMap(data, refreshedUser.uid).role,
          disabilityType: data['disabilityType'],
          preferredAssistance: data['preferredAssistance'],
        );

        _needsProfileCompletion = _isProfileIncomplete(_currentUser!);
        if (_currentUser!.role == UserRole.admin) {
          _needsProfileCompletion = false;
          await _startRequestListener();
          await refreshAdminData();
        } else if (!_needsProfileCompletion) {
          await _startRequestListener();
        } else {
          await _stopRequestListener();
        }
        return;
      }

      final isGoogleUser = refreshedUser.providerData.any(
        (provider) => provider.providerId == 'google.com',
      );
      if (isGoogleUser) {
        final restoredName = (refreshedUser.displayName ?? '').trim().isNotEmpty
            ? refreshedUser.displayName!.trim()
            : 'Google User';
        _currentUser = UserProfile(
          id: refreshedUser.uid,
          name: restoredName,
          username: '',
          email: refreshedUser.email ?? '',
          phone: '',
          role: UserRole.passenger,
        );
        _pendingGoogleUser = refreshedUser;
        _pendingGoogleEmail = refreshedUser.email ?? '';
        _pendingGoogleName = restoredName;
        _needsProfileCompletion = true;
        await _stopRequestListener();
      } else {
        await _auth.signOut();
        _currentUser = null;
        _needsProfileCompletion = false;
        _clearPendingGoogleProfile();
        await _stopRequestListener();
      }
    } catch (e) {
      debugPrint('Error restoring Firebase session: $e');
      _currentUser = null;
      _needsProfileCompletion = false;
      await _stopRequestListener();
    } finally {
      _isSessionInitialized = true;
      notifyListeners();
    }
  }

  bool _isProfileIncomplete(UserProfile user) {
    if (user.role == UserRole.admin) return false;
    return user.username.trim().isEmpty || user.phone.trim().isEmpty;
  }

  Future<bool> _isStaffApproved(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final snapshot = await _firestore
        .collection('staff_requests')
        .where('email', isEqualTo: normalized)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> login(String identifier, String password, bool isStaff) async {
    _isLoading = true;
    notifyListeners();
    try {
      final input = identifier.trim();
      if (input.isEmpty || password.isEmpty) return false;

      if (isStaff && !input.contains('@')) return false;

      String email = input;
      if (!input.contains('@')) {
        final usernameQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: input.toLowerCase())
            .limit(1)
            .get();
        if (usernameQuery.docs.isEmpty) return false;
        final storedEmail = usernameQuery.docs.first.data()['email'];
        if (storedEmail == null || storedEmail.toString().trim().isEmpty) return false;
        email = storedEmail.toString().trim();
      }

      if (isStaff && !await _isStaffApproved(email)) {
        return false;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) return false;

      final profileDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (profileDoc.exists && profileDoc.data() != null) {
        final profileUser = UserProfile.fromMap(profileDoc.data()!, firebaseUser.uid);
        if (profileUser.role == UserRole.admin) {
          _currentUser = profileUser;
          _needsProfileCompletion = false;
          _clearPendingGoogleProfile();
          await _startRequestListener();
          await refreshAdminData();
          return true;
        }

        if (isStaff && profileUser.role != UserRole.staff) {
          final approved = await _isStaffApproved(email);
          if (!approved) {
            await _auth.signOut();
            return false;
          }
          final promoted = UserProfile(
            id: profileUser.id,
            name: profileUser.name,
            username: profileUser.username,
            email: profileUser.email,
            phone: profileUser.phone,
            role: UserRole.staff,
            disabilityType: profileUser.disabilityType,
            preferredAssistance: profileUser.preferredAssistance,
          );
          await _firestore.collection('users').doc(firebaseUser.uid).set({
            'role': 'staff',
            'status': 'approved',
          }, SetOptions(merge: true));
          _currentUser = promoted;
        } else if (isStaff && profileUser.role != UserRole.staff) {
          await _auth.signOut();
          return false;
        } else if (!isStaff && profileUser.role != UserRole.passenger) {
          await _auth.signOut();
          return false;
        } else {
          _currentUser = profileUser;
        }
      } else {
        if (!isStaff) {
          await _auth.signOut();
          return false;
        }
        if (!await _isStaffApproved(email)) {
          await _auth.signOut();
          return false;
        }
        final newStaff = UserProfile(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Railway Staff',
          username: '',
          email: email,
          phone: '',
          role: UserRole.staff,
        );
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          ...newStaff.toMap(),
          'status': 'approved',
        }, SetOptions(merge: true));
        _currentUser = newStaff;
      }

      _needsProfileCompletion = false;
      _clearPendingGoogleProfile();
      await _startRequestListener();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase login error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle({bool isStaff = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) return false;

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return false;

      final email = (firebaseUser.email ?? googleUser.email).trim().toLowerCase();
      if (isStaff && !await _isStaffApproved(email)) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        _currentUser = null;
        _needsProfileCompletion = false;
        _clearPendingGoogleProfile();
        return false;
      }

      final profileRef = _firestore.collection('users').doc(firebaseUser.uid);
      final profileDoc = await profileRef.get();

      if (profileDoc.exists && profileDoc.data() != null) {
        final profileUser = UserProfile.fromMap(profileDoc.data()!, firebaseUser.uid);
        if (profileUser.role == UserRole.admin) {
          _currentUser = profileUser;
          _needsProfileCompletion = false;
          _pendingGoogleUser = firebaseUser;
          _pendingGoogleEmail = profileUser.email;
          _pendingGoogleName = profileUser.name;
          await _startRequestListener();
          await refreshAdminData();
          return true;
        }

        final selectedRole = isStaff ? UserRole.staff : UserRole.passenger;
        if (!isStaff && selectedRole != profileUser.role) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          _currentUser = null;
          _needsProfileCompletion = false;
          _clearPendingGoogleProfile();
          return false;
        }
        if (isStaff && profileUser.role != UserRole.staff) {
          await profileRef.set({'role': 'staff', 'status': 'approved'}, SetOptions(merge: true));
        }
        _currentUser = UserProfile(
          id: profileUser.id,
          name: profileUser.name,
          username: profileUser.username,
          email: profileUser.email,
          phone: profileUser.phone,
          role: selectedRole,
          disabilityType: profileUser.disabilityType,
          preferredAssistance: profileUser.preferredAssistance,
        );

        _needsProfileCompletion = _isProfileIncomplete(_currentUser!);
        _pendingGoogleUser = firebaseUser;
        _pendingGoogleEmail = _currentUser!.email;
        _pendingGoogleName = _currentUser!.name;
        if (!_needsProfileCompletion) {
          await _startRequestListener();
        } else {
          await _stopRequestListener();
        }
        return true;
      }

      if (isStaff) {
        final approved = await _isStaffApproved(email);
        if (!approved) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          _currentUser = null;
          _needsProfileCompletion = false;
          _clearPendingGoogleProfile();
          return false;
        }
        final staff = UserProfile(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Railway Staff',
          username: '',
          email: email,
          phone: '',
          role: UserRole.staff,
        );
        await profileRef.set({
          ...staff.toMap(),
          'status': 'approved',
        }, SetOptions(merge: true));
        _currentUser = staff;
        _needsProfileCompletion = false;
        await _startRequestListener();
        return true;
      }

      _currentUser = UserProfile(
        id: firebaseUser.uid,
        name: (firebaseUser.displayName ?? '').trim().isNotEmpty
            ? firebaseUser.displayName!.trim()
            : 'Google User',
        username: '',
        email: email,
        phone: '',
        role: UserRole.passenger,
      );
      _pendingGoogleUser = firebaseUser;
      _pendingGoogleEmail = email;
      _pendingGoogleName = _currentUser!.name;
      _needsProfileCompletion = true;
      await _stopRequestListener();
      return true;
    } on GoogleSignInException catch (e) {
      debugPrint('Google Sign-In error: ${e.code}');
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Google login error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Google login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Existing phone OTP, profile, requests, admin and logout methods continue below.
}
