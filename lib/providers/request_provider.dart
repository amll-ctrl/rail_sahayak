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
  String? _lastLoginError;
  final List<AssistanceRequest> _requests = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSubscription;
  final List<UserProfile> _adminStaffCandidates = [];
  bool _adminDataLoading = false;

  RequestProvider() { _restoreSession(); }
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get needsProfileCompletion => _needsProfileCompletion;
  bool get needsGoogleProfileCompletion => _needsProfileCompletion;
  bool get isSessionInitialized => _isSessionInitialized;
  String get pendingGoogleName => _pendingGoogleName ?? '';
  String get pendingGoogleEmail => _pendingGoogleEmail ?? '';
  String? get lastLoginError => _lastLoginError;
  List<AssistanceRequest> get requests => List.unmodifiable(_requests);
  List<UserProfile> get adminStaffCandidates => List.unmodifiable(_adminStaffCandidates);
  bool get isAdminDataLoading => _adminDataLoading;
  bool get phoneVerificationInProgress => false;
  bool get phoneVerified => true;
  String? get phoneVerificationError => null;
  List<AssistanceRequest> get passengerRequests { final user = _currentUser; if (user == null) return []; return _requests.where((r) => r.passengerId == user.id).toList(); }
  List<AssistanceRequest> get staffRequests => List.unmodifiable(_requests);
  void _clearPendingGoogleProfile() { _pendingGoogleUser = null; _pendingGoogleEmail = null; _pendingGoogleName = null; }
  bool _isProfileIncomplete(UserProfile user) => user.role != UserRole.admin && user.role != UserRole.staff && (user.username.trim().isEmpty || user.phone.trim().isEmpty);

  Future<void> _startRequestListener() async {
    await _stopRequestListener();
    final user = _currentUser;
    if (user == null) return;
    Query<Map<String, dynamic>> query = _firestore.collection('requests');
    if (user.role == UserRole.passenger) query = query.where('passengerId', isEqualTo: user.id);
    _requestsSubscription = query.snapshots().listen((snapshot) {
      final loaded = snapshot.docs.map((doc) => AssistanceRequest.fromMap(doc.data(), doc.id)).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _requests..clear()..addAll(loaded);
      notifyListeners();
    }, onError: (Object error) { debugPrint('Request listener error: $error'); });
  }
  Future<void> _stopRequestListener() async { await _requestsSubscription?.cancel(); _requestsSubscription = null; _requests.clear(); }

  Future<void> refreshAdminData() async {
    _adminDataLoading = true; notifyListeners();
    try { final snapshot = await _firestore.collection('users').where('role', isEqualTo: 'staff').get(); _adminStaffCandidates..clear()..addAll(snapshot.docs.map((doc) => UserProfile.fromMap(doc.data(), doc.id))); }
    catch (e) { debugPrint('Admin data refresh error: $e'); }
    finally { _adminDataLoading = false; notifyListeners(); }
  }

  Future<void> setAdminSession({required String uid, required Map<String, dynamic> data}) async {
    _currentUser = UserProfile(
      id: uid,
      name: (data['name'] ?? 'Administrator').toString(),
      username: (data['username'] ?? '').toString(),
      email: (data['email'] ?? _auth.currentUser?.email ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      role: UserRole.admin,
    );
    _needsProfileCompletion = false;
    _clearPendingGoogleProfile();
    _isSessionInitialized = true;
    await _startRequestListener();
    await refreshAdminData();
    notifyListeners();
  }

  Future<void> completePassengerSignupSession(UserProfile user) async { _currentUser = user; _needsProfileCompletion = false; _clearPendingGoogleProfile(); _isSessionInitialized = true; await _startRequestListener(); notifyListeners(); }

  Future<void> _restoreSession() async {
    try {
      final firebaseUser = _auth.currentUser; if (firebaseUser == null) return;
      await firebaseUser.reload(); final refreshed = _auth.currentUser; if (refreshed == null) return;
      final adminDoc = await _firestore.collection('admin').doc(refreshed.uid).get();
      if (adminDoc.exists && adminDoc.data() != null) {
        final data = adminDoc.data()!;
        if (data['role']?.toString().toLowerCase() == 'admin' && data['approved'] == true) {
          await setAdminSession(uid: refreshed.uid, data: data);
          return;
        }
        await _auth.signOut();
        return;
      }
      final doc = await _firestore.collection('users').doc(refreshed.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawProfile = UserProfile.fromMap(data, refreshed.uid);
        final hydratedName = rawProfile.name.trim().isEmpty ? ((refreshed.displayName ?? '').trim().isNotEmpty ? refreshed.displayName!.trim() : 'RailSahayak User') : rawProfile.name;
        final hydratedEmail = rawProfile.email.trim().isEmpty ? (refreshed.email ?? '') : rawProfile.email;
        _currentUser = UserProfile(id: refreshed.uid, name: hydratedName, username: rawProfile.username, email: hydratedEmail, phone: rawProfile.phone, role: rawProfile.role, disabilityType: rawProfile.disabilityType, preferredAssistance: rawProfile.preferredAssistance);
        if (rawProfile.name.trim().isEmpty || rawProfile.email.trim().isEmpty) {
          await _firestore.collection('users').doc(refreshed.uid).set({'name': hydratedName, 'email': hydratedEmail, 'role': rawProfile.role == UserRole.staff ? 'staff' : 'passenger'}, SetOptions(merge: true));
        }
        _needsProfileCompletion = _isProfileIncomplete(_currentUser!);
        if (!_needsProfileCompletion) await _startRequestListener();
      } else if (refreshed.providerData.any((p) => p.providerId == 'google.com')) {
        final name = (refreshed.displayName ?? '').trim().isEmpty ? 'Google User' : refreshed.displayName!.trim();
        _currentUser = UserProfile(id: refreshed.uid, name: name, username: '', email: refreshed.email ?? '', phone: '', role: UserRole.passenger);
        _pendingGoogleUser = refreshed; _pendingGoogleName = name; _pendingGoogleEmail = refreshed.email ?? ''; _needsProfileCompletion = true;
      } else { await _auth.signOut(); }
    } catch (e) { debugPrint('Session restore error: $e'); _currentUser = null; _needsProfileCompletion = false; }
    finally { _isSessionInitialized = true; notifyListeners(); }
  }

  Future<bool> _isStaffApproved(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    try {
      final userSnapshot = await _firestore.collection('users').where('email', isEqualTo: normalized).where('role', isEqualTo: 'staff').where('status', isEqualTo: 'approved').limit(1).get();
      if (userSnapshot.docs.isNotEmpty) return true;
    } catch (e) { debugPrint('Staff users approval check error: $e'); }
    try {
      final requestSnapshot = await _firestore.collection('staff_requests').where('email', isEqualTo: normalized).where('status', isEqualTo: 'approved').limit(1).get();
      return requestSnapshot.docs.isNotEmpty;
    } catch (e) { debugPrint('Staff request approval check error: $e'); return false; }
  }

  Future<bool> login(String identifier, String password, bool isStaff) async {
    _isLoading = true;
    _lastLoginError = null;
    notifyListeners();
    try {
      var email = identifier.trim();
      if (email.isEmpty || password.isEmpty) { _lastLoginError = 'Please enter your email and password.'; return false; }
      if (!isStaff && !email.contains('@')) {
        final query = await _firestore.collection('users').where('username', isEqualTo: email.toLowerCase()).limit(1).get();
        if (query.docs.isEmpty) { _lastLoginError = 'No passenger account was found for that username.'; return false; }
        email = (query.docs.first.data()['email'] ?? '').toString().trim();
      }
      if (isStaff && !email.contains('@')) { _lastLoginError = 'Staff login requires the approved company email address.'; return false; }
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final firebaseUser = credential.user;
      if (firebaseUser == null) { _lastLoginError = 'Firebase did not return a user account.'; return false; }
      final ref = _firestore.collection('users').doc(firebaseUser.uid);
      final doc = await ref.get();
      if (isStaff) {
        final approvedByUsers = doc.exists && doc.data() != null && doc.data()!['role'] == 'staff' && doc.data()!['status'] == 'approved';
        final approvedByRequest = await _isStaffApproved(email);
        if (!approvedByUsers && !approvedByRequest) { await _auth.signOut(); _lastLoginError = 'This Firebase account exists, but the administrator has not approved this staff email yet.'; return false; }
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final name = (data['name'] ?? '').toString().trim().isEmpty ? (firebaseUser.displayName ?? 'Railway Staff') : data['name'].toString();
          _currentUser = UserProfile.fromMap({...data, 'role': 'staff', 'name': name, 'email': email}, firebaseUser.uid);
          await ref.set({'role': 'staff', 'status': 'approved', 'email': email, 'name': name}, SetOptions(merge: true));
        } else {
          _currentUser = UserProfile(id: firebaseUser.uid, name: firebaseUser.displayName ?? 'Railway Staff', username: email.split('@').first.toLowerCase(), email: email, phone: '', role: UserRole.staff);
          await ref.set({..._currentUser!.toMap(), 'status': 'approved'}, SetOptions(merge: true));
        }
        _needsProfileCompletion = false;
        _clearPendingGoogleProfile();
        await _startRequestListener();
        return true;
      }
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawProfile = UserProfile.fromMap(data, firebaseUser.uid);
        if (rawProfile.role != UserRole.passenger) { await _auth.signOut(); _lastLoginError = 'This account is not registered as a passenger.'; return false; }
        final name = rawProfile.name.trim().isEmpty ? ((firebaseUser.displayName ?? '').trim().isNotEmpty ? firebaseUser.displayName!.trim() : 'RailSahayak User') : rawProfile.name;
        final profileEmail = rawProfile.email.trim().isEmpty ? (firebaseUser.email ?? email) : rawProfile.email;
        _currentUser = UserProfile(id: firebaseUser.uid, name: name, username: rawProfile.username, email: profileEmail, phone: rawProfile.phone, role: UserRole.passenger, disabilityType: rawProfile.disabilityType, preferredAssistance: rawProfile.preferredAssistance);
        await ref.set({'name': name, 'email': profileEmail, 'role': 'passenger'}, SetOptions(merge: true));
      } else {
        await _auth.signOut();
        _lastLoginError = 'No RailSahayak profile was found for this Firebase account.';
        return false;
      }
      _needsProfileCompletion = false;
      _clearPendingGoogleProfile();
      await _startRequestListener();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found': _lastLoginError = 'No Firebase account exists for this email.'; break;
        case 'wrong-password':
        case 'invalid-credential': _lastLoginError = 'The email or password is incorrect.'; break;
        case 'user-disabled': _lastLoginError = 'This Firebase account has been disabled.'; break;
        case 'too-many-requests': _lastLoginError = 'Too many login attempts. Please wait and try again.'; break;
        default: _lastLoginError = e.message ?? 'Firebase login failed (${e.code}).';
      }
      debugPrint('Login error: ${e.code}');
      return false;
    } catch (e) {
      _lastLoginError = 'Login failed: $e';
      debugPrint('Login error: $e');
      return false;
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<bool> signInWithGoogle({bool isStaff = false}) async {
    _isLoading = true;
    _lastLoginError = null;
    notifyListeners();
    try {
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        _lastLoginError = 'Google Sign-In returned no ID token.';
        return false;
      }
      final credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final user = credential.user;
      if (user == null) {
        _lastLoginError = 'Firebase did not return a Google user account.';
        return false;
      }
      final email = (user.email ?? googleUser.email).trim().toLowerCase();
      final googleName = (user.displayName ?? googleUser.displayName ?? '').trim();
      if (isStaff && !await _isStaffApproved(email)) { await _auth.signOut(); await _googleSignIn.signOut(); _lastLoginError = 'This Google account is not approved for Railway Staff access.'; return false; }
      final ref = _firestore.collection('users').doc(user.uid); final doc = await ref.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final profile = UserProfile.fromMap(data, user.uid);
        final hydratedName = profile.name.trim().isEmpty ? (googleName.isNotEmpty ? googleName : 'Google User') : profile.name;
        final hydratedEmail = profile.email.trim().isEmpty ? email : profile.email;
        if (profile.role == UserRole.admin) { _currentUser = profile; _needsProfileCompletion = false; await _startRequestListener(); await refreshAdminData(); return true; }
        if (isStaff) { if (profile.role != UserRole.staff) await ref.set({'role': 'staff', 'status': 'approved'}, SetOptions(merge: true)); _currentUser = UserProfile(id: profile.id, name: hydratedName, username: profile.username, email: hydratedEmail, phone: profile.phone, role: UserRole.staff, disabilityType: profile.disabilityType, preferredAssistance: profile.preferredAssistance); _needsProfileCompletion = false; await _startRequestListener(); return true; }
        if (profile.role != UserRole.passenger) { await _auth.signOut(); await _googleSignIn.signOut(); _lastLoginError = 'This account is not registered as a passenger.'; return false; }
        _currentUser = UserProfile(id: profile.id, name: hydratedName, username: profile.username, email: hydratedEmail, phone: profile.phone, role: UserRole.passenger, disabilityType: profile.disabilityType, preferredAssistance: profile.preferredAssistance);
        if (profile.name.trim().isEmpty || profile.email.trim().isEmpty) await ref.set({'name': hydratedName, 'email': hydratedEmail, 'role': 'passenger'}, SetOptions(merge: true));
        _needsProfileCompletion = _isProfileIncomplete(_currentUser!); if (!_needsProfileCompletion) await _startRequestListener(); return true;
      }
      if (isStaff) { _currentUser = UserProfile(id: user.uid, name: googleName.isEmpty ? 'Railway Staff' : googleName, username: '', email: email, phone: '', role: UserRole.staff); await ref.set({..._currentUser!.toMap(), 'status': 'approved'}); _needsProfileCompletion = false; await _startRequestListener(); return true; }
      final name = googleName.isEmpty ? 'Google User' : googleName;
      _currentUser = UserProfile(id: user.uid, name: name, username: '', email: email, phone: '', role: UserRole.passenger); _pendingGoogleUser = user; _pendingGoogleName = name; _pendingGoogleEmail = email; _needsProfileCompletion = true; return true;
    } on GoogleSignInException catch (e) {
      _lastLoginError = 'Google Sign-In failed: ${e.code}${e.description != null ? ' — ${e.description}' : ''}';
      debugPrint('Google login error: code=${e.code}, description=${e.description}, details=${e.details}');
      return false;
    } on FirebaseAuthException catch (e) {
      _lastLoginError = 'Firebase Google Sign-In failed: ${e.code}${e.message != null ? ' — ${e.message}' : ''}';
      debugPrint('Firebase Google login error: code=${e.code}, message=${e.message}');
      return false;
    } catch (e, stackTrace) {
      _lastLoginError = 'Google Sign-In failed: $e';
      debugPrint('Google login error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<bool> submitRequest({required String pnr, required String trainNo, required String coach, required List<String> assistanceType, String? notes}) async {
    final user = _currentUser; if (user == null) return false; _isLoading = true; notifyListeners();
    try { final request = AssistanceRequest(id: '', pnr: pnr, trainNo: trainNo, coach: coach, passengerId: user.id, passengerName: user.name, passengerPhone: user.phone, status: 'Requested', assistanceType: assistanceType, timestamp: DateTime.now(), notes: notes?.trim().isEmpty ?? true ? null : notes!.trim()); await _firestore.collection('requests').add(request.toMap()); return true; }
    catch (e) { debugPrint('Submit request error: $e'); return false; }
    finally { _isLoading = false; notifyListeners(); }
  }
