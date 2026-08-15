import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../models/assistance_request.dart';

class RequestProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  UserProfile? _currentUser;

  bool _isLoading = false;

  // ---------------------------------------------------------------------------
  // Profile completion
  // ---------------------------------------------------------------------------

  bool _needsProfileCompletion = false;

  // These are kept for compatibility with the Google
  // authentication flow.
  User? _pendingGoogleUser;
  String? _pendingGoogleEmail;
  String? _pendingGoogleName;

  final List<AssistanceRequest> _mockRequests = [];
  final Map<String, UserProfile> _mockUsers = {};

  RequestProvider() {
    _loadMockData();
    _restoreSession();
  }

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  UserProfile? get currentUser => _currentUser;

  bool get isLoading => _isLoading;

  bool get needsProfileCompletion =>
      _needsProfileCompletion;

  // Kept for compatibility if another screen uses these.
  bool get needsGoogleProfileCompletion =>
      _needsProfileCompletion;

  String get pendingGoogleName =>
      _pendingGoogleName ?? '';

  String get pendingGoogleEmail =>
      _pendingGoogleEmail ?? '';

  List<AssistanceRequest> get requests =>
      List.unmodifiable(_mockRequests);

  List<AssistanceRequest> get passengerRequests {
    if (_currentUser == null) {
      return [];
    }

    return _mockRequests
        .where(
          (r) => r.passengerId == _currentUser!.id,
        )
        .toList();
  }

  List<AssistanceRequest> get staffRequests {
    return _mockRequests;
  }

  // ===========================================================================
  // MOCK DATA
  // ===========================================================================

  void _loadMockData() {
    _mockUsers['passenger1'] = UserProfile(
      id: 'passenger1',
      name: 'Ramesh Kumar',
      username: 'ramesh',
      email: 'ramesh@gmail.com',
      phone: '9876543210',
      role: UserRole.passenger,
      disabilityType: 'Wheelchair user',
      preferredAssistance:
          'Needs boarding ramp assistance and wheelchair transfer.',
    );

    _mockUsers['staff1'] = UserProfile(
      id: 'staff1',
      name: 'Inspector Sunil Dutt',
      username: 'sunil',
      email: 'sunil@railnet.gov.in',
      phone: '9988776655',
      role: UserRole.staff,
    );

    _mockRequests.addAll([
      AssistanceRequest(
        id: 'req_101',
        pnr: '4238765410',
        trainNo: '12626 (Kerala Express)',
        coach: 'B2',
        passengerId: 'passenger1',
        passengerName: 'Ramesh Kumar',
        passengerPhone: '9876543210',
        status: 'Assigned',
        assistanceType: [
          'Wheelchair boarding assistance',
          'Luggage support',
        ],
        timestamp: DateTime.now().subtract(
          const Duration(minutes: 45),
        ),
        staffId: 'staff1',
        staffName: 'Inspector Sunil Dutt',
        notes:
            'Has heavy luggage, needs wheelchair from main entrance platform 1.',
      ),
      AssistanceRequest(
        id: 'req_102',
        pnr: '2105432190',
        trainNo: '12002 (Bhopal Shatabdi)',
        coach: 'C4',
        passengerId: 'passenger2',
        passengerName: 'Saraswathi Devi',
        passengerPhone: '8877665544',
        status: 'Requested',
        assistanceType: [
          'Elderly assistance',
          'Guiding hand',
        ],
        timestamp: DateTime.now().subtract(
          const Duration(minutes: 10),
        ),
        notes:
            'Passenger is 82 years old, walking slowly. Needs help climbing steps into the coach.',
      ),
      AssistanceRequest(
        id: 'req_103',
        pnr: '8765432109',
        trainNo: '12952 (Mumbai Rajdhani)',
        coach: 'A1',
        passengerId: 'passenger3',
        passengerName: 'Amit Sharma',
        passengerPhone: '7766554433',
        status: 'Completed',
        assistanceType: [
          'Visual guidance assistance',
        ],
        timestamp: DateTime.now().subtract(
          const Duration(hours: 2),
        ),
        staffId: 'staff1',
        staffName: 'Inspector Sunil Dutt',
        notes:
            'Visually impaired. Guided from station entry directly to seat 32.',
      ),
    ]);
  }

  // ===========================================================================
  // RESTORE FIREBASE SESSION
  // ===========================================================================

  Future<void> _restoreSession() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      // -----------------------------------------------------------------------
      // Firestore profile exists
      // -----------------------------------------------------------------------

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _currentUser = UserProfile.fromMap(
          data,
          firebaseUser.uid,
        );

        // IMPORTANT:
        // An existing Google account can have a Firestore profile
        // but still be missing username or phone.
        _needsProfileCompletion =
            _isProfileIncomplete(_currentUser!);

        debugPrint(
          'Session restored: ${_currentUser!.email}',
        );

        debugPrint(
          'Profile incomplete: $_needsProfileCompletion',
        );

        notifyListeners();
        return;
      }

      // -----------------------------------------------------------------------
      // No Firestore profile
      // -----------------------------------------------------------------------

      final isGoogleUser =
          firebaseUser.providerData.any(
        (provider) =>
            provider.providerId == 'google.com',
      );

      if (isGoogleUser) {
        _currentUser = UserProfile(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ??
              'Google User',
          username: '',
          email: firebaseUser.email ?? '',
          phone: '',
          role: UserRole.passenger,
        );

        _pendingGoogleUser = firebaseUser;
        _pendingGoogleEmail =
            firebaseUser.email ?? '';
        _pendingGoogleName =
            firebaseUser.displayName ??
                'Google User';

        _needsProfileCompletion = true;

        debugPrint(
          'Google account has no RailSahayak profile.',
        );
      } else {
        // Email/password account without a profile
        // is not allowed into the application.
        await _auth.signOut();

        _currentUser = null;
        _needsProfileCompletion = false;
      }

      notifyListeners();
    } catch (e) {
      debugPrint(
        'Error restoring Firebase session: $e',
      );
    }
  }

  // ===========================================================================
  // PROFILE COMPLETION CHECK
  // ===========================================================================

  bool _isProfileIncomplete(
    UserProfile user,
  ) {
    final username =
        user.username.trim();

    final phone =
        user.phone.trim();

    return username.isEmpty ||
        phone.isEmpty;
  }

  // ===========================================================================
  // LOGIN - EMAIL OR USERNAME
  // ===========================================================================

  Future<bool> login(
    String identifier,
    String password,
    bool isStaff,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final input = identifier.trim();

      if (input.isEmpty ||
          password.isEmpty) {
        return false;
      }

      String email = input;

      // -----------------------------------------------------------------------
      // Username login
      // -----------------------------------------------------------------------

      if (!input.contains('@')) {
        final username =
            input.toLowerCase();

        debugPrint(
          'Looking up username: $username',
        );

        final usernameQuery =
            await _firestore
                .collection('users')
                .where(
                  'username',
                  isEqualTo: username,
                )
                .limit(1)
                .get();

        if (usernameQuery.docs.isEmpty) {
          debugPrint(
            'Username not found: $username',
          );
          return false;
        }

        final userData =
            usernameQuery.docs.first.data();

        final storedEmail =
            userData['email'];

        if (storedEmail == null ||
            storedEmail
                .toString()
                .trim()
                .isEmpty) {
          debugPrint(
            'Username has no email attached.',
          );
          return false;
        }

        email =
            storedEmail.toString().trim();

        debugPrint(
          'Username found. Firebase email: $email',
        );
      }

      // -----------------------------------------------------------------------
      // Firebase Authentication
      // -----------------------------------------------------------------------

      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser =
          credential.user;

      if (firebaseUser == null) {
        return false;
      }

      // -----------------------------------------------------------------------
      // Load Firestore profile
      // -----------------------------------------------------------------------

      final profileDoc =
          await _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .get();

      if (!profileDoc.exists ||
          profileDoc.data() == null) {
        debugPrint(
          'Firebase account exists but Firestore profile is missing.',
        );

        await _auth.signOut();

        return false;
      }

      final profileData =
          profileDoc.data()!;

      // -----------------------------------------------------------------------
      // Determine role
      // -----------------------------------------------------------------------

      final roleString =
          (profileData['role'] ??
                  'passenger')
              .toString()
              .toLowerCase();

      final userRole =
          roleString == 'staff'
              ? UserRole.staff
              : UserRole.passenger;

      // -----------------------------------------------------------------------
      // Check Passenger / Staff selection
      // -----------------------------------------------------------------------

      if (isStaff &&
          userRole != UserRole.staff) {
        debugPrint(
          'Login rejected: account is not a staff account.',
        );

        await _auth.signOut();

        return false;
      }

      if (!isStaff &&
          userRole != UserRole.passenger) {
        debugPrint(
          'Login rejected: account is not a passenger account.',
        );

        await _auth.signOut();

        return false;
      }

      // -----------------------------------------------------------------------
      // Build current user
      // -----------------------------------------------------------------------

      _currentUser = UserProfile(
        id: firebaseUser.uid,
        name: profileData['name'] ??
            firebaseUser.displayName ??
            'RailSahayak User',
        username:
            profileData['username'] ?? '',
        email: profileData['email'] ??
            firebaseUser.email ??
            email,
        phone:
            profileData['phone'] ?? '',
        role: userRole,
        disabilityType:
            profileData['disabilityType'],
        preferredAssistance:
            profileData[
                'preferredAssistance'],
      );

      // Normal email/password accounts should
      // already have complete profiles.
      _needsProfileCompletion = false;

      _clearPendingGoogleProfile();

      debugPrint(
        'Login successful: '
        '${_currentUser!.username}',
      );

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase login error: ${e.code}',
      );

      return false;
    } catch (e) {
      debugPrint(
        'Login error: $e',
      );

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // GOOGLE SIGN-IN
  // ===========================================================================

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint(
        'Starting Google Sign-In...',
      );

      // -----------------------------------------------------------------------
      // Google authentication
      // -----------------------------------------------------------------------

      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      debugPrint(
        'Google account selected: '
        '${googleUser.email}',
      );

      final GoogleSignInAuthentication
          googleAuth =
          googleUser.authentication;

      final String? idToken =
          googleAuth.idToken;

      if (idToken == null) {
        debugPrint(
          'Google login failed: no ID token.',
        );

        return false;
      }

      // -----------------------------------------------------------------------
      // Firebase authentication
      // -----------------------------------------------------------------------

      final credential =
          GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(
        credential,
      );

      final firebaseUser =
          userCredential.user;

      if (firebaseUser == null) {
        debugPrint(
          'Firebase returned no user.',
        );

        return false;
      }

      debugPrint(
        'Firebase Google login successful: '
        '${firebaseUser.uid}',
      );

      // -----------------------------------------------------------------------
      // Firestore profile
      // -----------------------------------------------------------------------

      final profileRef =
          _firestore
              .collection('users')
              .doc(firebaseUser.uid);

      final profileDoc =
          await profileRef.get();

      // -----------------------------------------------------------------------
      // Existing RailSahayak profile
      // -----------------------------------------------------------------------

      if (profileDoc.exists &&
          profileDoc.data() != null) {
        final profileData =
            profileDoc.data()!;

        final roleString =
            (profileData['role'] ??
                    'passenger')
                .toString()
                .toLowerCase();

        final userRole =
            roleString == 'staff'
                ? UserRole.staff
                : UserRole.passenger;

        _currentUser = UserProfile(
          id: firebaseUser.uid,
          name: profileData['name'] ??
              firebaseUser.displayName ??
              'RailSahayak User',
          username:
              profileData['username'] ?? '',
          email: profileData['email'] ??
              firebaseUser.email ??
              googleUser.email,
          phone:
              profileData['phone'] ?? '',
          role: userRole,
          disabilityType:
              profileData['disabilityType'],
          preferredAssistance:
              profileData[
                  'preferredAssistance'],
        );

        // -----------------------------------------------------
        // THIS IS THE IMPORTANT PART
        // -----------------------------------------------------

        _needsProfileCompletion =
            _isProfileIncomplete(
          _currentUser!,
        );

        debugPrint(
          'Existing Google profile loaded.',
        );

        debugPrint(
          'Username: ${_currentUser!.username}',
        );

        debugPrint(
          'Phone: ${_currentUser!.phone}',
        );

        debugPrint(
          'Profile completion required: '
          '$_needsProfileCompletion',
        );

        _pendingGoogleUser =
            firebaseUser;

        _pendingGoogleEmail =
            _currentUser!.email;

        _pendingGoogleName =
            _currentUser!.name;

        return true;
      }

      // -----------------------------------------------------------------------
      // NEW Google user
      // -----------------------------------------------------------------------

      debugPrint(
        'New Google account.',
      );

      final email =
          firebaseUser.email ??
          googleUser.email;

      final displayName =
          firebaseUser.displayName ??
          googleUser.displayName ??
          'Google User';

      // We intentionally DON'T create a completed
      // RailSahayak profile here.
      //
      // The user must choose their username
      // and provide their phone number first.

      _currentUser = UserProfile(
        id: firebaseUser.uid,
        name: displayName,
        username: '',
        email: email,
        phone: '',
        role: UserRole.passenger,
      );

      _pendingGoogleUser =
          firebaseUser;

      _pendingGoogleEmail =
          email;

      _pendingGoogleName =
          displayName;

      _needsProfileCompletion = true;

      debugPrint(
        'New Google user requires profile completion.',
      );

      return true;
    } on GoogleSignInException catch (e) {
      debugPrint(
        'Google Sign-In error: ${e.code}',
      );

      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Google login error: ${e.code}',
      );

      return false;
    } catch (e) {
      debugPrint(
        'Google login error: $e',
      );

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // COMPLETE PROFILE
  // ===========================================================================

  Future<bool> completeProfile({
    required String username,
    required String phone,
  }) async {
    final user = _currentUser;
    final firebaseUser = _auth.currentUser;

    if (user == null || firebaseUser == null) {
      debugPrint('Cannot complete profile: no authenticated user.');
      return false;
    }

    final cleanUsername = username.trim().toLowerCase();
    final cleanPhone = phone.trim();

    if (cleanUsername.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername) ||
        !RegExp(r'^[0-9]{10}$').hasMatch(cleanPhone)) {
      debugPrint('Invalid profile completion data.');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Make sure the username is still available when the save happens.
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty &&
          usernameQuery.docs.first.id != firebaseUser.uid) {
        debugPrint('Username already exists: $cleanUsername');
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

      // Persist the completed profile before changing the routing state.
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(
            updatedUser.toMap(),
            SetOptions(merge: true),
          );

      _currentUser = updatedUser;
      _needsProfileCompletion = false;
      _clearPendingGoogleProfile();

      debugPrint('Profile completed and saved: $cleanUsername');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Profile completion auth error: ${e.code}');
      return false;
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

  // ===========================================================================
  // COMPLETE GOOGLE PROFILE
  // ===========================================================================
  //
  // Kept as a compatibility method in case another screen is still using
  // completeGoogleProfile(). It now uses the same underlying profile system.
  // ===========================================================================

  Future<bool> completeGoogleProfile({
    required String username,
    required String phone,
    required UserRole role,
    String? disabilityType,
    String? preferredAssistance,
  }) async {
    final user = _currentUser;

    if (user == null) {
      debugPrint('No authenticated user for Google profile completion.');
      return false;
    }

    // Preserve any role/disability information supplied by the caller.
    _currentUser = UserProfile(
      id: user.id,
      name: user.name,
      username: user.username,
      email: user.email,
      phone: user.phone,
      role: role,
      disabilityType: disabilityType ?? user.disabilityType,
      preferredAssistance:
          preferredAssistance ?? user.preferredAssistance,
    );

    final success = await completeProfile(
      username: username,
      phone: phone,
    );

    if (!success) {
      // Restore the previous role/profile state if saving failed.
      _currentUser = user;
    }

    return success;
  }

  // ===========================================================================
  // SIGNUP
  // ===========================================================================

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
    _isLoading = true;
    notifyListeners();

    try {
      final cleanName =
          name.trim();

      final cleanUsername =
          username.trim().toLowerCase();

      final cleanEmail =
          email.trim().toLowerCase();

      final cleanPhone =
          phone.trim();

      // -----------------------------------------------------------------------
      // Check username
      // -----------------------------------------------------------------------

      final usernameCheck =
          await _firestore
              .collection('users')
              .where(
                'username',
                isEqualTo: cleanUsername,
              )
              .limit(1)
              .get();

      if (usernameCheck.docs.isNotEmpty) {
        debugPrint(
          'Username already exists: '
          '$cleanUsername',
        );

        return false;
      }

      // -----------------------------------------------------------------------
      // Create Firebase Authentication account
      // -----------------------------------------------------------------------

      final credential =
          await _auth
              .createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser =
          credential.user;

      if (firebaseUser == null) {
        return false;
      }

      // -----------------------------------------------------------------------
      // Firebase display name
      // -----------------------------------------------------------------------

      await firebaseUser.updateDisplayName(
        cleanName,
      );

      // -----------------------------------------------------------------------
      // Create profile
      // -----------------------------------------------------------------------

      final newUser = UserProfile(
        id: firebaseUser.uid,
        name: cleanName,
        username: cleanUsername,
        email: cleanEmail,
        phone: cleanPhone,
        role: role,
        disabilityType:
            disabilityType,
        preferredAssistance:
            preferredAssistance,
      );

      // -----------------------------------------------------------------------
      // Save profile
      // -----------------------------------------------------------------------

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(
            newUser.toMap(),
          );

      _currentUser = newUser;

      _needsProfileCompletion = false;

      debugPrint(
        'Signup successful: '
        '$cleanUsername',
      );

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase signup error: ${e.code}',
      );

      return false;
    } catch (e) {
      debugPrint(
        'Signup error: $e',
      );

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  Future<void> logout() async {
    // Clear local routing state immediately so the app can return to LoginScreen
    // even if a provider's sign-out API is temporarily unavailable.
    _currentUser = null;
    _needsProfileCompletion = false;
    _clearPendingGoogleProfile();
    notifyListeners();

    try {
      await _auth.signOut();
      debugPrint('Firebase logout successful.');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase sign-out error: ${e.code}');
    } catch (e) {
      debugPrint('Firebase sign-out error: $e');
    }

    try {
      await _googleSignIn.signOut();
      debugPrint('Google logout successful.');
    } on GoogleSignInException catch (e) {
      // Google sign-out failure should not block RailSahayak logout.
      debugPrint('Google sign-out error: ${e.code}');
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }

    notifyListeners();
  }

  // ===========================================================================
  // GOOGLE PROFILE HELPERS
  // ===========================================================================

  void _clearPendingGoogleProfile() {
    _pendingGoogleUser = null;
    _pendingGoogleEmail = null;
    _pendingGoogleName = null;
  }

  // ===========================================================================
  // REQUEST OPERATIONS
  // ===========================================================================

  Future<bool> submitRequest({
    required String pnr,
    required String trainNo,
    required String coach,
    required List<String> assistanceType,
    String? notes,
  }) async {
    if (_currentUser == null) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(
        const Duration(
          milliseconds: 800,
        ),
      );

      final newRequest =
          AssistanceRequest(
        id:
            'req_${DateTime.now().millisecondsSinceEpoch}',
        pnr: pnr,
        trainNo: trainNo,
        coach: coach,
        passengerId:
            _currentUser!.id,
        passengerName:
            _currentUser!.name,
        passengerPhone:
            _currentUser!.phone,
        status: 'Requested',
        assistanceType:
            assistanceType,
        timestamp:
            DateTime.now(),
        notes: notes,
      );

      _mockRequests.insert(
        0,
        newRequest,
      );

      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // UPDATE REQUEST STATUS
  // ===========================================================================

  Future<bool> updateRequestStatus(
    String requestId,
    String newStatus, {
    String? staffId,
    String? staffName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      final index =
          _mockRequests.indexWhere(
        (r) => r.id == requestId,
      );

      if (index == -1) {
        return false;
      }

      final oldReq =
          _mockRequests[index];

      _mockRequests[index] =
          oldReq.copyWith(
        status: newStatus,
        staffId:
            staffId ?? oldReq.staffId,
        staffName:
            staffName ?? oldReq.staffName,
      );

      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}