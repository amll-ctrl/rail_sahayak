import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  String get pendingGoogleName => _pendingGoogleName ?? '';
  String get pendingGoogleEmail => _pendingGoogleEmail ?? '';
  List<AssistanceRequest> get requests => List.unmodifiable(_requests);
  List<UserProfile> get adminStaffCandidates => List.unmodifiable(_adminStaffCandidates);
  bool get isAdminDataLoading => _adminDataLoading;
  bool get phoneVerificationInProgress => false;
  bool get phoneVerified => true;
  String? get phoneVerificationError => null;

  List<AssistanceRequest> get passengerRequests {
    final user = _currentUser;
    if (user == null) return [];
    return _requests.where((r) => r.passengerId == user.id).toList();
  }

  List<AssistanceRequest> get staffRequests => List.unmodifiable(_requests);

  void _clearPendingGoogleProfile() {
    _pendingGoogleUser = null;
    _pendingGoogleEmail = null;
    _pendingGoogleName = null;
  }

  bool _isProfileIncomplete(UserProfile user) {
    if (user.role == UserRole.admin || user.role == UserRole.staff) return false;
    return user.username.trim().isEmpty || user.phone.trim().isEmpty;
  }

  Future<void> _startRequestListener() async {
    await _stopRequestListener();
    _requestsSubscription = _firestore
        .collection('requests')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _requests
        ..clear()
        ..addAll(snapshot.docs.map((doc) => AssistanceRequest.fromMap(doc.data(), doc.id)));
      notifyListeners();
    }, onError: (Object error) {
      debugPrint('Request listener error: $error');
    });
  }

  Future<void> _stopRequestListener() async {
    await _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _requests.clear();
  }

  Future<void> refreshAdminData() async {
    _adminDataLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();
      _adminStaffCandidates
        ..clear()
        ..addAll(snapshot.docs.map((doc) => UserProfile.fromMap(doc.data(), doc.id)));
    } catch (e) {
      debugPrint('Admin data refresh error: $e');
    } finally {
      _adminDataLoading = false;
      notifyListeners();
    }
  }

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
      final refreshed = _auth.currentUser;
      if (refreshed == null) return;
      final doc = await _firestore.collection('users').doc(refreshed.uid).get();
      if (doc.exists && doc.data() != null) {
        _currentUser = UserProfile.fromMap(doc.data()!, refreshed.uid);
        if (_currentUser!.name.trim().isEmpty || _currentUser!.email.trim().isEmpty) {
          _currentUser = UserProfile(
            id: refreshed.uid,
            name: _currentUser!.name.trim().isEmpty ? (refreshed.displayName ?? 'RailSahayak User') : _currentUser!.name,
            username: _currentUser!.username,
            email: _currentUser!.email.trim().isEmpty ? (refreshed.email ?? '') : _currentUser!.email,
            phone: _currentUser!.phone,
            role: _currentUser!.role,
            disabilityType: _currentUser!.disabilityType,
            preferredAssistance: _currentUser!.preferredAssistance,
          );
        }
        _needsProfileCompletion = _isProfileIncomplete(_currentUser!);
        if (_currentUser!.role == UserRole.admin) await refreshAdminData();
        if (!_needsProfileCompletion) await _startRequestListener();
      } else if (refreshed.providerData.any((p) => p.providerId == 'google.com')) {
        final name = (refreshed.displayName ?? '').trim().isEmpty ? 'Google User' : refreshed.displayName!.trim();
        _currentUser = UserProfile(id: refreshed.uid, name: name, username: '', email: refreshed.email ?? '', phone: '', role: UserRole.passenger);
        _pendingGoogleUser = refreshed;
        _pendingGoogleName = name;
        _pendingGoogleEmail = refreshed.email ?? '';
        _needsProfileCompletion = true;
      } else {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('Session restore error: $e');
      _currentUser = null;
      _needsProfileCompletion = false;
    } finally {
      _isSessionInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> _isStaffApproved(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final snapshot = await _firestore.collection('staff_requests')
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
      var email = identifier.trim();
      if (email.isEmpty || password.isEmpty) return false;
      if (!isStaff && !email.contains('@')) {
        final query = await _firestore.collection('users')
            .where('username', isEqualTo: email.toLowerCase())
            .limit(1).get();
        if (query.docs.isEmpty) return false;
        email = (query.docs.first.data()['email'] ?? '').toString().trim();
      }
      if (isStaff && !email.contains('@')) return false;
      if (isStaff && !await _isStaffApproved(email)) return false;

      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final firebaseUser = credential.user;
      if (firebaseUser == null) return false;
      final ref = _firestore.collection('users').doc(firebaseUser.uid);
      final doc = await ref.get();

      if (doc.exists && doc.data() != null) {
        var profile = UserProfile.fromMap(doc.data()!, firebaseUser.uid);
        if (profile.role == UserRole.admin) {
          _currentUser = profile;
          _needsProfileCompletion = false;
          await _startRequestListener();
          await refreshAdminData();
          return true;
        }
        if (isStaff) {
          if (profile.role != UserRole.staff) {
            await ref.set({'role': 'staff', 'status': 'approved'}, SetOptions(merge: true));
            profile = UserProfile(id: profile.id, name: profile.name, username: profile.username, email: profile.email, phone: profile.phone, role: UserRole.staff, disabilityType: profile.disabilityType, preferredAssistance: profile.preferredAssistance);
          }
        } else if (profile.role != UserRole.passenger) {
          await _auth.signOut();
          return false;
        }
        _currentUser = profile;
      } else if (isStaff) {
        _currentUser = UserProfile(id: firebaseUser.uid, name: firebaseUser.displayName ?? 'Railway Staff', username: '', email: email, phone: '', role: UserRole.staff);
        await ref.set({..._currentUser!.toMap(), 'status': 'approved'}, SetOptions(merge: true));
      } else {
        await _auth.signOut();
        return false;
      }
      _needsProfileCompletion = false;
      _clearPendingGoogleProfile();
      await _startRequestListener();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code}');
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
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) return false;
      final credential = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      final user = credential.user;
      if (user == null) return false;
      final email = (user.email ?? googleUser.email).trim().toLowerCase();
      if (isStaff && !await _isStaffApproved(email)) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        return false;
      }
      final ref = _firestore.collection('users').doc(user.uid);
      final doc = await ref.get();
      if (doc.exists && doc.data() != null) {
        var profile = UserProfile.fromMap(doc.data()!, user.uid);
        if (profile.role == UserRole.admin) {
          _currentUser = profile;
          _needsProfileCompletion = false;
          await _startRequestListener();
          await refreshAdminData();
          return true;
        }
        if (isStaff) {
          if (profile.role != UserRole.staff) await ref.set({'role': 'staff', 'status': 'approved'}, SetOptions(merge: true));
          _currentUser = UserProfile(id: profile.id, name: profile.name, username: profile.username, email: profile.email, phone: profile.phone, role: UserRole.staff, disabilityType: profile.disabilityType, preferredAssistance: profile.preferredAssistance);
          _needsProfileCompletion = false;
          await _startRequestListener();
          return true;
        }
        if (profile.role != UserRole.passenger) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          return false;
        }
        _currentUser = profile;
        _needsProfileCompletion = _isProfileIncomplete(profile);
        if (!_needsProfileCompletion) await _startRequestListener();
        return true;
      }
      if (isStaff) {
        _currentUser = UserProfile(id: user.uid, name: user.displayName ?? 'Railway Staff', username: '', email: email, phone: '', role: UserRole.staff);
        await ref.set({..._currentUser!.toMap(), 'status': 'approved'});
        _needsProfileCompletion = false;
        await _startRequestListener();
        return true;
      }
      final name = (user.displayName ?? '').trim().isEmpty ? 'Google User' : user.displayName!.trim();
      _currentUser = UserProfile(id: user.uid, name: name, username: '', email: email, phone: '', role: UserRole.passenger);
      _pendingGoogleUser = user;
      _pendingGoogleName = name;
      _pendingGoogleEmail = email;
      _needsProfileCompletion = true;
      return true;
    } catch (e) {
      debugPrint('Google login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitRequest({required String pnr, required String trainNo, required String coach, required List<String> assistanceType, String? notes}) async {
    final user = _currentUser;
    if (user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final request = AssistanceRequest(id: '', pnr: pnr, trainNo: trainNo, coach: coach, passengerId: user.id, passengerName: user.name, passengerPhone: user.phone, status: 'Requested', assistanceType: assistanceType, timestamp: DateTime.now(), notes: notes?.trim().isEmpty ?? true ? null : notes!.trim());
      await _firestore.collection('requests').add(request.toMap());
      return true;
    } catch (e) {
      debugPrint('Submit request error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    final data = <String, dynamic>{'status': status};
    final user = _currentUser;
    if (user != null && user.role == UserRole.staff && status == 'Assigned') {
      data['staffId'] = user.id;
      data['staffName'] = user.name;
    }
    await _firestore.collection('requests').doc(requestId).update(data);
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _stopRequestListener();
      await _auth.signOut();
      try { await _googleSignIn.signOut(); } catch (_) {}
      _currentUser = null;
      _needsProfileCompletion = false;
      _clearPendingGoogleProfile();
      _adminStaffCandidates.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
