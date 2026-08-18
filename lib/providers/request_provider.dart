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

  List<AssistanceRequest> get passengerRequests {
    if (_currentUser == null) return [];
    return _requests
        .where((r) => r.passengerId == _currentUser!.id)
        .toList();
  }

  List<AssistanceRequest> get staffRequests => List.unmodifiable(_requests);

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

      final doc = await _firestore
          .collection('users')
          .doc(refreshedUser.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final firestoreName = (data['name'] ?? '').toString().trim();
        final firestoreEmail = (data['email'] ?? '').toString().trim();
        final restoredName = firestoreName.isNotEmpty
            ? firestoreName
            : ((refreshedUser.displayName ?? '').trim().isNotEmpty
                ? refreshedUser.displayName!.trim()
                : 'Google User');
        final restoredEmail = firestoreEmail.isNotEmpty
            ? firestoreEmail
            : (refreshedUser.email ?? '').trim();

        _currentUser = UserProfile(
          id: refreshedUser.uid,
          name: restoredName,
          username: (data['username'] ?? '').toString(),
          email: restoredEmail,
          phone: (data['phone'] ?? '').toString(),
          role: (data['role'] ?? 'passenger').toString().toLowerCase() == 'staff'
              ? UserRole.staff
              : UserRole.passenger,
          disabilityType: data['disabilityType'],
          preferredAssistance: data['preferredAssistance'],
        );

        final isGoogleUser = refreshedUser.providerData.any(
          (provider) => provider.providerId == 'google.com',
        );
        if (isGoogleUser) {
          _pendingGoogleUser = refreshedUser;
          _pendingGoogleName = restoredName;
          _pendingGoogleEmail = restoredEmail;
        }

        _needsProfileCompletion = _isProfileIncomplete(_currentUser!);
        if (!_needsProfileCompletion) {
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
        final restoredEmail = (refreshedUser.email ?? '').trim();

        _currentUser = UserProfile(
          id: refreshedUser.uid,
          name: restoredName,
          username: '',
          email: restoredEmail,
          phone: '',
          role: UserRole.passenger,
        );
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
        final usernameQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        if (usernameQuery.docs.isEmpty) return false;
        final userData = usernameQuery.docs.first.data();
        final storedEmail = userData['email'];
        if (storedEmail == null || storedEmail.toString().trim().isEmpty) {
          return false;
        }
        email = storedEmail.toString().trim();
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) return false;

      final profileDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (!profileDoc.exists || profileDoc.data() == null) {
        await _auth.signOut();
        return false;
      }

      final profileData = profileDoc.data()!;
      final roleString =
          (profileData['role'] ?? 'passenger').toString().toLowerCase();
      final userRole = roleString == 'staff'
          ? UserRole.staff
          : UserRole.passenger;

      if (isStaff && userRole != UserRole.staff) {
        await _auth.signOut();
        return false;
      }
      if (!isStaff && userRole != UserRole.passenger) {
        await _auth.signOut();
        return false;
      }

      _currentUser = UserProfile(
        id: firebaseUser.uid,
        name: profileData['name'] ??
            firebaseUser.displayName ??
            'RailSahayak User',
        username: profileData['username'] ?? '',
        email: profileData['email'] ?? firebaseUser.email ?? email,
        phone: profileData['phone'] ?? '',
        role: userRole,
        disabilityType: profileData['disabilityType'],
        preferredAssistance: profileData['preferredAssistance'],
      );

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
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) return false;

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return false;

      final profileRef =
          _firestore.collection('users').doc(firebaseUser.uid);
      final profileDoc = await profileRef.get();

      if (profileDoc.exists && profileDoc.data() != null) {
        final profileData = profileDoc.data()!;
        final roleString =
            (profileData['role'] ?? 'passenger').toString().toLowerCase();
        final storedRole = roleString == 'staff'
            ? UserRole.staff
            : UserRole.passenger;

        final profileUser = UserProfile(
          id: firebaseUser.uid,
          name: profileData['name'] ??
              firebaseUser.displayName ??
              'RailSahayak User',
          username: profileData['username'] ?? '',
          email: profileData['email'] ??
              firebaseUser.email ??
              googleUser.email,
          phone: profileData['phone'] ?? '',
          role: storedRole,
          disabilityType: profileData['disabilityType'],
          preferredAssistance: profileData['preferredAssistance'],
        );

        final profileIncomplete = _isProfileIncomplete(profileUser);
        if (profileIncomplete) {
          _currentUser = UserProfile(
            id: profileUser.id,
            name: profileUser.name,
            username: profileUser.username,
            email: profileUser.email,
            phone: profileUser.phone,
            role: isStaff ? UserRole.staff : UserRole.passenger,
            disabilityType: profileUser.disabilityType,
            preferredAssistance: profileUser.preferredAssistance,
          );
        } else {
          final selectedRole =
              isStaff ? UserRole.staff : UserRole.passenger;
          if (selectedRole != storedRole) {
            await _auth.signOut();
            await _googleSignIn.signOut();
            _currentUser = null;
            _needsProfileCompletion = false;
            _clearPendingGoogleProfile();
            return false;
          }
          _currentUser = profileUser;
        }

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

      final email = firebaseUser.email ?? googleUser.email;
      final displayName =
          firebaseUser.displayName ?? googleUser.displayName ?? 'Google User';

      _currentUser = UserProfile(
        id: firebaseUser.uid,
        name: displayName,
        username: '',
        email: email,
        phone: '',
        role: isStaff ? UserRole.staff : UserRole.passenger,
      );

      _pendingGoogleUser = firebaseUser;
      _pendingGoogleEmail = email;
      _pendingGoogleName = displayName;
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

  String _formatIndianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return phone.trim();
  }

  void _resetPhoneVerificationState() {
    _phoneVerificationId = null;
    _phoneResendToken = null;
    _pendingVerifiedPhone = null;
    _phoneVerificationInProgress = false;
    _phoneVerified = false;
    _phoneVerificationError = null;
  }

  Future<bool> sendPhoneOtp(String phone, {bool resend = false}) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _phoneVerificationError =
          'You must be signed in before verifying your phone number.';
      notifyListeners();
      return false;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[0-9]{10}$').hasMatch(cleanPhone)) {
      _phoneVerificationError =
          'Enter a valid 10-digit Indian phone number.';
      notifyListeners();
      return false;
    }

    final formattedPhone = _formatIndianPhone(cleanPhone);
    _phoneVerificationError = null;
    _phoneVerified = false;
    _pendingVerifiedPhone = cleanPhone;
    _phoneVerificationId = null;
    _phoneVerificationInProgress = true;
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        forceResendingToken: resend ? _phoneResendToken : null,
        verificationCompleted: (credential) async {
          try {
            final currentUser = _auth.currentUser;
            if (currentUser == null) {
              _phoneVerificationError =
                  'Your sign-in session expired. Please sign in again.';
              notifyListeners();
              return;
            }
            await currentUser.linkWithCredential(credential);
            _phoneVerified = true;
            _pendingVerifiedPhone = cleanPhone;
            _phoneVerificationInProgress = false;
            _phoneVerificationError = null;
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use') {
              _phoneVerificationError =
                  'This phone number is already linked to another account.';
            } else if (e.code == 'provider-already-linked') {
              _phoneVerified = true;
              _pendingVerifiedPhone = cleanPhone;
              _phoneVerificationInProgress = false;
              _phoneVerificationError = null;
            } else {
              _phoneVerificationError =
                  'Could not link this phone number. Please try again.';
            }
          } catch (_) {
            _phoneVerificationError =
                'Could not verify this phone number. Please try again.';
          }
          notifyListeners();
        },
        verificationFailed: (FirebaseAuthException e) {
          _phoneVerificationInProgress = false;
          _phoneVerificationError =
              e.message ?? 'Could not send the verification code.';
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _phoneVerificationId = verificationId;
          _phoneResendToken = resendToken;
          _phoneVerificationInProgress = false;
          _phoneVerificationError = null;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _phoneVerificationId = verificationId;
          _phoneVerificationInProgress = false;
          notifyListeners();
        },
      );
      return true;
    } catch (_) {
      _phoneVerificationInProgress = false;
      _phoneVerificationError =
          'Could not start phone verification. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPhoneOtp(String otp) async {
    final firebaseUser = _auth.currentUser;
    final verificationId = _phoneVerificationId;
    final pendingPhone = _pendingVerifiedPhone;

    if (firebaseUser == null) {
      _phoneVerificationError =
          'Your sign-in session expired. Please sign in again.';
      notifyListeners();
      return false;
    }
    if (verificationId == null || verificationId.isEmpty) {
      _phoneVerificationError = 'Please request a new OTP first.';
      notifyListeners();
      return false;
    }

    final code = otp.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _phoneVerificationError = 'Enter the 6-digit OTP.';
      notifyListeners();
      return false;
    }

    _phoneVerificationInProgress = true;
    _phoneVerificationError = null;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await firebaseUser.linkWithCredential(credential);
      _phoneVerified = true;
      _pendingVerifiedPhone = pendingPhone;
      _phoneVerificationInProgress = false;
      _phoneVerificationError = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _phoneVerificationInProgress = false;
      _phoneVerificationError =
          e.message ?? 'Could not verify the OTP.';
      if (e.code == 'provider-already-linked') {
        _phoneVerified = true;
        _phoneVerificationError = null;
      }
      notifyListeners();
      return _phoneVerified;
    } catch (_) {
      _phoneVerificationInProgress = false;
      _phoneVerificationError =
          'Could not verify the OTP. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? disabilityType,
    String? preferredAssistance,
  }) async {
    if (role != UserRole.passenger) {
      debugPrint('Public signup rejected for non-passenger role.');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final cleanName = name.trim();
      final cleanUsername = username.trim().toLowerCase();
      final cleanEmail = email.trim().toLowerCase();
      final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');

      if (cleanName.isEmpty ||
          cleanUsername.length < 3 ||
          !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername) ||
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail) ||
          !RegExp(r'^[0-9]{10}$').hasMatch(cleanPhone) ||
          password.length < 6) {
        return false;
      }

      final usernameCheck = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();
      if (usernameCheck.docs.isNotEmpty) {
        return false;
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) return false;

      await firebaseUser.updateDisplayName(cleanName);

      final newUser = UserProfile(
        id: firebaseUser.uid,
        name: cleanName,
        username: cleanUsername,
        email: cleanEmail,
        phone: '',
        role: UserRole.passenger,
        disabilityType: disabilityType,
        preferredAssistance: preferredAssistance,
      );

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(newUser.toMap());

      _currentUser = newUser;
      _needsProfileCompletion = true;
      _resetPhoneVerificationState();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase signup error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Signup error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeProfile({
    required String username,
    required String phone,
  }) async {
    final user = _currentUser;
    final firebaseUser = _auth.currentUser;
    if (user == null || firebaseUser == null) return false;

    final cleanUsername = username.trim().toLowerCase();
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');

    if (cleanUsername.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername) ||
        !RegExp(r'^[0-9]{10}$').hasMatch(cleanPhone)) {
      return false;
    }

    if (!_phoneVerified || _pendingVerifiedPhone != cleanPhone) {
      _phoneVerificationError =
          'Please verify your phone number with the OTP first.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();
      if (usernameQuery.docs.isNotEmpty &&
          usernameQuery.docs.first.id != firebaseUser.uid) {
        _phoneVerificationError = 'Username already exists.';
        return false;
      }

      final updatedUser = UserProfile(
        id: user.id,
        name: user.name,
        username: cleanUsername,
        email: user.email,
        phone: cleanPhone,
        role: user.role,
        disabilityType: user.disabilityType,
        preferredAssistance: user.preferredAssistance,
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set(
        updatedUser.toMap(),
        SetOptions(merge: true),
      );

      _currentUser = updatedUser;
      _needsProfileCompletion = false;
      _clearPendingGoogleProfile();
      _resetPhoneVerificationState();
      await _startRequestListener();
      return true;
    } on FirebaseException catch (e) {
      debugPrint('Profile completion Firestore error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Profile completion error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _stopRequestListener();
    _currentUser = null;
    _needsProfileCompletion = false;
    _clearPendingGoogleProfile();
    _resetPhoneVerificationState();
    notifyListeners();

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase sign-out error: $e');
    }
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }
  }

  void _clearPendingGoogleProfile() {
    _pendingGoogleUser = null;
    _pendingGoogleEmail = null;
    _pendingGoogleName = null;
  }

  Future<void> _startRequestListener() async {
    await _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _requests.clear();

    final user = _currentUser;
    if (user == null) {
      notifyListeners();
      return;
    }

    Query<Map<String, dynamic>> query =
        _firestore.collection('requests');
    if (user.role == UserRole.passenger) {
      query = query.where('passengerId', isEqualTo: user.id);
    }

    _requestsSubscription = query.snapshots().listen(
      (snapshot) {
        final loaded = snapshot.docs.map((doc) {
          return AssistanceRequest.fromMap(doc.data(), doc.id);
        }).toList();
        loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _requests
          ..clear()
          ..addAll(loaded);
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Firestore request listener error: $error');
      },
    );
  }

  Future<void> _stopRequestListener() async {
    await _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _requests.clear();
  }

  Future<bool> submitRequest({
    required String pnr,
    required String trainNo,
    required String coach,
    required List<String> assistanceType,
    String? notes,
  }) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final user = _currentUser!;
      final requestRef = _firestore.collection('requests').doc();
      await requestRef.set({
        'pnr': pnr.trim(),
        'trainNo': trainNo.trim(),
        'coach': coach.trim(),
        'passengerId': user.id,
        'passengerName': user.name,
        'passengerPhone': user.phone,
        'status': 'Requested',
        'assistanceType': assistanceType,
        'timestamp': FieldValue.serverTimestamp(),
        'notes': notes?.trim(),
      });
      return true;
    } catch (e) {
      debugPrint('Submit request error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateRequestStatus(
    String requestId,
    String newStatus, {
    String? staffId,
    String? staffName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = <String, dynamic>{'status': newStatus};
      if (staffId != null) data['staffId'] = staffId;
      if (staffName != null) data['staffName'] = staffName;
      await _firestore.collection('requests').doc(requestId).update(data);
      return true;
    } catch (e) {
      debugPrint('Update request status error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
