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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _requestsSubscription;

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
  List<UserProfile> get adminStaffCandidates =>
      List.unmodifiable(_adminStaffCandidates);
  bool get isAdminDataLoading => _adminDataLoading;

  List<AssistanceRequest> get passengerRequests {
    if (_currentUser == null) return [];
    return _requests
        .where((r) => r.passengerId == _currentUser!.id)
        .toList();
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
        final firestoreName = (data['name'] ?? '').toString().trim();
        final firestoreEmail = (data['email'] ?? '').toString().trim();
        final restoredName = firestoreName.isNotEmpty ? firestoreName : ((refreshedUser.displayName ?? '').trim().isNotEmpty ? refreshedUser.displayName!.trim() : 'Google User');
        final restoredEmail = firestoreEmail.isNotEmpty ? firestoreEmail : (refreshedUser.email ?? '').trim();
        _currentUser = UserProfile(id: refreshedUser.uid, name: restoredName, username: (data['username'] ?? '').toString(), email: restoredEmail, phone: (data['phone'] ?? '').toString(), role: UserProfile.fromMap(data, refreshedUser.uid).role, disabilityType: data['disabilityType'], preferredAssistance: data['preferredAssistance']);
        final isGoogleUser = refreshedUser.providerData.any((provider) => provider.providerId == 'google.com');
        if (isGoogleUser) {
          _pendingGoogleUser = refreshedUser;
          _pendingGoogleName = restoredName;
          _pendingGoogleEmail = restoredEmail;
        }
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
      final isGoogleUser = refreshedUser.providerData.any((provider) => provider.providerId == 'google.com');
      if (isGoogleUser) {
        final restoredName = (refreshedUser.displayName ?? '').trim().isNotEmpty ? refreshedUser.displayName!.trim() : 'Google User';
        final restoredEmail = (refreshedUser.email ?? '').trim();
        _currentUser = UserProfile(id: refreshedUser.uid, name: restoredName, username: '', email: restoredEmail, phone: '', role: UserRole.passenger);
        _pendingGoogleUser = refreshedUser;
        _pendingGoogleEmail = restoredEmail;
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

  Future<bool> login(String identifier, String password, bool isStaff) async {
    _isLoading = true;
    notifyListeners();
    try {
      final input = identifier.trim();
      if (input.isEmpty || password.isEmpty) return false;
      String email = input;
      if (!input.contains('@')) {
        final username = input.toLowerCase();
        final usernameQuery = await _firestore.collection('users').where('username', isEqualTo: username).limit(1).get();
        if (usernameQuery.docs.isEmpty) return false;
        final storedEmail = usernameQuery.docs.first.data()['email'];
        if (storedEmail == null || storedEmail.toString().trim().isEmpty) return false;
        email = storedEmail.toString().trim();
      }
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final firebaseUser = credential.user;
      if (firebaseUser == null) return false;
      final profileDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (!profileDoc.exists || profileDoc.data() == null) { await _auth.signOut(); return false; }
      final profileUser = UserProfile.fromMap(profileDoc.data()!, firebaseUser.uid);
      if (profileUser.role == UserRole.admin) {
        _currentUser = profileUser; _needsProfileCompletion = false; _clearPendingGoogleProfile(); await _startRequestListener(); await refreshAdminData(); return true;
      }
      if (isStaff && profileUser.role != UserRole.staff) { await _auth.signOut(); return false; }
      if (!isStaff && profileUser.role != UserRole.passenger) { await _auth.signOut(); return false; }
      _currentUser = profileUser; _needsProfileCompletion = false; _clearPendingGoogleProfile(); await _startRequestListener(); return true;
    } on FirebaseAuthException catch (e) { debugPrint('Firebase login error: ${e.code}'); return false; }
    catch (e) { debugPrint('Login error: $e'); return false; }
    finally { _isLoading = false; notifyListeners(); }
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
      final profileRef = _firestore.collection('users').doc(firebaseUser.uid);
      final profileDoc = await profileRef.get();
      if (profileDoc.exists && profileDoc.data() != null) {
        final profileUser = UserProfile.fromMap(profileDoc.data()!, firebaseUser.uid);
        if (profileUser.role == UserRole.admin) { _currentUser = profileUser; _needsProfileCompletion = false; _pendingGoogleUser = firebaseUser; _pendingGoogleEmail = profileUser.email; _pendingGoogleName = profileUser.name; await _startRequestListener(); await refreshAdminData(); return true; }
        final profileIncomplete = _isProfileIncomplete(profileUser);
        if (profileIncomplete) {
          _currentUser = UserProfile(id: profileUser.id, name: profileUser.name, username: profileUser.username, email: profileUser.email, phone: profileUser.phone, role: isStaff ? UserRole.staff : UserRole.passenger, disabilityType: profileUser.disabilityType, preferredAssistance: profileUser.preferredAssistance);
        } else {
          final selectedRole = isStaff ? UserRole.staff : UserRole.passenger;
          if (selectedRole != profileUser.role) { await _auth.signOut(); await _googleSignIn.signOut(); _currentUser = null; _needsProfileCompletion = false; _clearPendingGoogleProfile(); return false; }
          _currentUser = profileUser;
        }
        _needsProfileCompletion = _isProfileIncomplete(_currentUser!);
        _pendingGoogleUser = firebaseUser; _pendingGoogleEmail = _currentUser!.email; _pendingGoogleName = _currentUser!.name;
        if (!_needsProfileCompletion) await _startRequestListener(); else await _stopRequestListener();
        return true;
      }
      if (isStaff) { await _auth.signOut(); await _googleSignIn.signOut(); _currentUser = null; _needsProfileCompletion = false; _clearPendingGoogleProfile(); return false; }
      _currentUser = UserProfile(id: firebaseUser.uid, name: (firebaseUser.displayName ?? '').trim().isNotEmpty ? firebaseUser.displayName!.trim() : 'Google User', username: '', email: firebaseUser.email ?? '', phone: '', role: UserRole.passenger);
      _pendingGoogleUser = firebaseUser; _pendingGoogleEmail = _currentUser!.email; _pendingGoogleName = _currentUser!.name; _needsProfileCompletion = true; await _stopRequestListener(); return true;
    } catch (e) { debugPrint('Google sign-in error: $e'); return false; }
    finally { _isLoading = false; notifyListeners(); }
  }

  // Existing request, profile, notification, admin, OTP and logout methods remain below.
