import 'dart:async';
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

  // ---------------------------------------------------------------------------
  // Phone verification / OTP
  // ---------------------------------------------------------------------------

  String? _phoneVerificationId;
  int? _phoneResendToken;
  String? _pendingVerifiedPhone;
  bool _phoneVerificationInProgress = false;
  bool _phoneVerified = false;
  String? _phoneVerificationError;

  bool get phoneVerificationInProgress =>
      _phoneVerificationInProgress;

  bool get phoneVerified => _phoneVerified;

  String? get phoneVerificationError =>
      _phoneVerificationError;

  // These are kept for compatibility with the Google
  // authentication flow.
  User? _pendingGoogleUser;
  String? _pendingGoogleEmail;
  String? _pendingGoogleName;

  // Live assistance requests loaded from Firestore.
  final List<AssistanceRequest> _requests = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSubscription;

  RequestProvider() {
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
      List.unmodifiable(_requests);

  List<AssistanceRequest> get passengerRequests {
    if (_currentUser == null) return [];

    return _requests
        .where((r) => r.passengerId == _currentUser!.id)
        .toList();
  }

  List<AssistanceRequest> get staffRequests =>
      List.unmodifiable(_requests);

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

        await _startRequestListener();
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
      await _startRequestListener();

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

  Future<bool> signInWithGoogle({bool isStaff = false}) async {
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

        final storedRole =
            roleString == 'staff'
                ? UserRole.staff
                : UserRole.passenger;

        final profileUser = UserProfile(
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
          role: storedRole,
          disabilityType:
              profileData['disabilityType'],
          preferredAssistance:
              profileData[
                  'preferredAssistance'],
        );

        final profileIncomplete =
            _isProfileIncomplete(profileUser);

        // Google login has the Passenger / Railway Staff selector.
        //
        // If this Google profile is incomplete, allow the selected role to
        // become the role that will be saved when the profile is completed.
        // This fixes an account that was created by Google but never finished.
        //
        // If the profile is already complete, NEVER silently change its role
        // just because the login toggle was changed. The stored Firestore role
        // remains authoritative for completed accounts.
        if (profileIncomplete) {
          _currentUser = UserProfile(
            id: profileUser.id,
            name: profileUser.name,
            username: profileUser.username,
            email: profileUser.email,
            phone: profileUser.phone,
            role: isStaff
                ? UserRole.staff
                : UserRole.passenger,
            disabilityType:
                profileUser.disabilityType,
            preferredAssistance:
                profileUser.preferredAssistance,
          );
        } else {
          final selectedRole = isStaff
              ? UserRole.staff
              : UserRole.passenger;

          if (selectedRole != storedRole) {
            debugPrint(
              'Google login rejected: selected role does not match '
              'the existing account role.',
            );

            await _auth.signOut();
            await _googleSignIn.signOut();
            _currentUser = null;
            _needsProfileCompletion = false;
            _clearPendingGoogleProfile();
            return false;
          }

          _currentUser = profileUser;
        }

        // -----------------------------------------------------
        // Profile completion check
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

        // Only start the request listener once the account has a usable
        // RailSahayak profile. Incomplete Google accounts finish profile setup
        // first, then completeProfile() starts the listener.
        if (!_needsProfileCompletion) {
          await _startRequestListener();
        }

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
  role: isStaff ? UserRole.staff : UserRole.passenger,
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
  // PHONE OTP VERIFICATION
  // ===========================================================================

  String _formatIndianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10) {
      return '+91$digits';
    }

    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }

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

  Future<bool> sendPhoneOtp(
    String phone, {
    bool resend = false,
  }) async {
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

    // Keep the exact 10-digit number that this OTP belongs to.
    // completeProfile() uses this value to make sure the verified
    // number is the same number currently entered in the form.
    _pendingVerifiedPhone = cleanPhone;

    _phoneVerificationId = null;
    _phoneVerificationInProgress = true;
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        forceResendingToken:
            resend ? _phoneResendToken : null,

        verificationCompleted:
            (PhoneAuthCredential credential) async {
          try {
            final currentUser = _auth.currentUser;

            if (currentUser == null) {
              _phoneVerificationError =
                  'Your sign-in session expired. Please sign in again.';
              return;
            }

            await currentUser.linkWithCredential(
              credential,
            );

            _phoneVerified = true;
            _pendingVerifiedPhone = cleanPhone;
            _phoneVerificationInProgress = false;
            _phoneVerificationError = null;

            debugPrint(
              'Phone automatically verified: $formattedPhone',
            );
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

            debugPrint(
              'Automatic phone verification error: ${e.code}',
            );
          } catch (e) {
            _phoneVerificationError =
                'Could not verify this phone number. Please try again.';
            debugPrint(
              'Automatic phone verification error: $e',
            );
          }

          notifyListeners();
        },

        verificationFailed:
            (FirebaseAuthException e) {
          _phoneVerificationInProgress = false;

          switch (e.code) {
            case 'invalid-phone-number':
              _phoneVerificationError =
                  'The phone number is invalid.';
              break;
            case 'too-many-requests':
              _phoneVerificationError =
                  'Too many verification attempts. Please try again later.';
              break;
            case 'quota-exceeded':
              _phoneVerificationError =
                  'SMS verification quota exceeded. Please try again later.';
              break;
            default:
              _phoneVerificationError =
                  e.message ??
                  'Could not send the verification code.';
          }

          debugPrint(
            'Phone verification failed: ${e.code} ${e.message}',
          );

          notifyListeners();
        },

        codeSent: (
          String verificationId,
          int? resendToken,
        ) {
          _phoneVerificationId = verificationId;
          _phoneResendToken = resendToken;
          _phoneVerificationInProgress = false;
          _phoneVerificationError = null;

          debugPrint(
            'OTP sent to $formattedPhone',
          );

          notifyListeners();
        },

        codeAutoRetrievalTimeout:
            (String verificationId) {
          _phoneVerificationId = verificationId;
          _phoneVerificationInProgress = false;
          notifyListeners();
        },
      );

      return true;
    } on FirebaseAuthException catch (e) {
      _phoneVerificationInProgress = false;
      _phoneVerificationError =
          e.message ??
          'Could not start phone verification.';
      debugPrint(
        'Phone OTP error: ${e.code} ${e.message}',
      );
      notifyListeners();
      return false;
    } catch (e) {
      _phoneVerificationInProgress = false;
      _phoneVerificationError =
          'Could not start phone verification. Please try again.';
      debugPrint(
        'Phone OTP error: $e',
      );
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
      _phoneVerificationError =
          'Please request a new OTP first.';
      notifyListeners();
      return false;
    }

    final code = otp.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _phoneVerificationError =
          'Enter the 6-digit OTP.';
      notifyListeners();
      return false;
    }

    _phoneVerificationInProgress = true;
    _phoneVerificationError = null;
    notifyListeners();

    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      await firebaseUser.linkWithCredential(
        credential,
      );

      _phoneVerified = true;
      _pendingVerifiedPhone = pendingPhone;
      _phoneVerificationInProgress = false;
      _phoneVerificationError = null;

      debugPrint(
        'Phone OTP verified successfully.',
      );

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _phoneVerificationInProgress = false;

      switch (e.code) {
        case 'invalid-verification-code':
          _phoneVerificationError =
              'Incorrect OTP. Please check the code and try again.';
          break;
        case 'session-expired':
          _phoneVerificationError =
              'This OTP has expired. Please request a new one.';
          break;
        case 'credential-already-in-use':
          _phoneVerificationError =
              'This phone number is already linked to another account.';
          break;
        case 'provider-already-linked':
          _phoneVerified = true;
          _phoneVerificationError = null;
          break;
        default:
          _phoneVerificationError =
              e.message ??
              'Could not verify the OTP.';
      }

      debugPrint(
        'Phone OTP verification failed: ${e.code}',
      );

      notifyListeners();
      return _phoneVerified;
    } catch (e) {
      _phoneVerificationInProgress = false;
      _phoneVerificationError =
          'Could not verify the OTP. Please try again.';
      debugPrint(
        'Phone OTP verification error: $e',
      );
      notifyListeners();
      return false;
    }
  }

  void clearPhoneVerificationError() {
    _phoneVerificationError = null;
    notifyListeners();
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
    final cleanPhone =
        phone.replaceAll(RegExp(r'[\s-]'), '');

    if (cleanUsername.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername) ||
        !RegExp(r'^[0-9]{10}$').hasMatch(cleanPhone)) {
      debugPrint('Invalid profile completion data.');
      return false;
    }

    // A phone number must be proven to belong to the current account before
    // it can be stored as the user's verified phone number.
    if (!_phoneVerified ||
        _pendingVerifiedPhone != cleanPhone) {
      debugPrint(
        'Profile completion rejected: '
        'phoneVerified=$_phoneVerified, '
        'pending=$_pendingVerifiedPhone, '
        'entered=$cleanPhone',
      );

      _phoneVerificationError =
          'Please verify your phone number with the OTP first.';
      notifyListeners();
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
      _resetPhoneVerificationState();
      await _startRequestListener();

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
      await _startRequestListener();

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
    await _stopRequestListener();

    // Clear local routing state immediately so the app can return to LoginScreen
    // even if a provider's sign-out API is temporarily unavailable.
    _currentUser = null;
    _needsProfileCompletion = false;
    _clearPendingGoogleProfile();
    _resetPhoneVerificationState();
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

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
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
  // FIRESTORE REQUEST LISTENER
  // ===========================================================================

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

    // Staff can see every assistance request.
    // Passengers only receive their own requests.
    if (user.role == UserRole.passenger) {
      query = query.where('passengerId', isEqualTo: user.id);
    }

    _requestsSubscription = query.snapshots().listen(
      (snapshot) {
        final loaded = snapshot.docs.map((doc) {
          return AssistanceRequest.fromMap(
            doc.data(),
            doc.id,
          );
        }).toList();

        // Sort newest first locally. This avoids requiring a Firestore
        // composite index when the passenger filter is active.
        loaded.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        );

        _requests
          ..clear()
          ..addAll(loaded);

        debugPrint(
          'Firestore requests updated: ${_requests.length}',
        );
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
    final user = _currentUser;
    if (user == null || user.role != UserRole.passenger) {
      debugPrint('Cannot submit request: no passenger is logged in.');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final docRef = _firestore.collection('requests').doc();

      final request = AssistanceRequest(
        id: docRef.id,
        pnr: pnr.trim(),
        trainNo: trainNo.trim(),
        coach: coach.trim().toUpperCase(),
        passengerId: user.id,
        passengerName: user.name,
        passengerPhone: user.phone,
        status: 'Requested',
        assistanceType: List<String>.from(assistanceType),
        timestamp: DateTime.now(),
        notes: notes?.trim(),
      );

      await docRef.set(request.toMap());

      debugPrint('Assistance request created: ${docRef.id}');
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore submit request error: ${e.code} ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('Submit request error: $e');
      return false;
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
    final user = _currentUser;
    if (user == null || user.role != UserRole.staff) {
      debugPrint('Cannot update request: no staff member is logged in.');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final requestRef =
          _firestore.collection('requests').doc(requestId);

      final data = <String, dynamic>{
        'status': newStatus,
      };

      if (staffId != null) {
        data['staffId'] = staffId;
      }
      if (staffName != null) {
        data['staffName'] = staffName;
      }

      await requestRef.update(data);

      debugPrint(
        'Request $requestId updated to $newStatus',
      );
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore update request error: ${e.code} ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('Update request error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}