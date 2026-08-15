import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../models/assistance_request.dart';

class RequestProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserProfile? _currentUser;
  bool _isLoading = false;

  final List<AssistanceRequest> _mockRequests = [];
  final Map<String, UserProfile> _mockUsers = {};

  RequestProvider() {
    _loadMockData();
    _restoreSession();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  UserProfile? get currentUser => _currentUser;

  bool get isLoading => _isLoading;

  List<AssistanceRequest> get requests =>
      List.unmodifiable(_mockRequests);

  List<AssistanceRequest> get passengerRequests {
    if (_currentUser == null) return [];

    return _mockRequests
        .where((r) => r.passengerId == _currentUser!.id)
        .toList();
  }

  List<AssistanceRequest> get staffRequests {
    return _mockRequests;
  }

  // ---------------------------------------------------------------------------
  // Mock data
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Restore Firebase session
  // ---------------------------------------------------------------------------

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

      if (doc.exists && doc.data() != null) {
        _currentUser = UserProfile.fromMap(
          doc.data()!,
          firebaseUser.uid,
        );
      } else {
        // Auth account exists but Firestore profile doesn't.
        _currentUser = UserProfile(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'RailSahayak User',
          username: '',
          email: firebaseUser.email ?? '',
          phone: '',
          role: UserRole.passenger,
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring Firebase session: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIN - EMAIL OR USERNAME
  // ---------------------------------------------------------------------------

  Future<bool> login(
    String identifier,
    String password,
    bool isStaff,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final input = identifier.trim();

      if (input.isEmpty || password.isEmpty) {
        return false;
      }

      String email = input;

      // -------------------------------------------------------
      // Username login
      // -------------------------------------------------------

      if (!input.contains('@')) {
        final username = input.toLowerCase();

        debugPrint('Looking up username: $username');

        final usernameQuery = await _firestore
            .collection('users')
            .where(
              'username',
              isEqualTo: username,
            )
            .limit(1)
            .get();

        if (usernameQuery.docs.isEmpty) {
          debugPrint('Username not found: $username');
          return false;
        }

        final userData = usernameQuery.docs.first.data();

        final storedEmail = userData['email'];

        if (storedEmail == null ||
            storedEmail.toString().trim().isEmpty) {
          debugPrint('Username has no email attached.');
          return false;
        }

        email = storedEmail.toString().trim();

        debugPrint('Username found. Firebase email: $email');
      }

      // -------------------------------------------------------
      // Firebase Authentication
      // -------------------------------------------------------

      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        return false;
      }

      // -------------------------------------------------------
      // Load Firestore profile
      // -------------------------------------------------------

      final profileDoc = await _firestore
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

      final profileData = profileDoc.data()!;

      // -------------------------------------------------------
      // Determine role
      // -------------------------------------------------------

      final roleString =
          (profileData['role'] ?? 'passenger')
              .toString()
              .toLowerCase();

      final userRole = roleString == 'staff'
          ? UserRole.staff
          : UserRole.passenger;

      // -------------------------------------------------------
      // Check Passenger / Staff selection
      // -------------------------------------------------------

      if (isStaff && userRole != UserRole.staff) {
        debugPrint(
          'Login rejected: account is not a staff account.',
        );

        await _auth.signOut();
        return false;
      }

      if (!isStaff && userRole != UserRole.passenger) {
        debugPrint(
          'Login rejected: account is not a passenger account.',
        );

        await _auth.signOut();
        return false;
      }

      // -------------------------------------------------------
      // Build current user
      // -------------------------------------------------------

      _currentUser = UserProfile(
        id: firebaseUser.uid,
        name: profileData['name'] ??
            firebaseUser.displayName ??
            'RailSahayak User',
        username: profileData['username'] ?? '',
        email: profileData['email'] ??
            firebaseUser.email ??
            email,
        phone: profileData['phone'] ?? '',
        role: userRole,
        disabilityType: profileData['disabilityType'],
        preferredAssistance:
            profileData['preferredAssistance'],
      );

      debugPrint(
        'Login successful: ${_currentUser!.username}',
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

  // ---------------------------------------------------------------------------
  // SIGNUP
  // ---------------------------------------------------------------------------

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
      final cleanName = name.trim();
      final cleanUsername =
          username.trim().toLowerCase();
      final cleanEmail =
          email.trim().toLowerCase();
      final cleanPhone = phone.trim();

      // -------------------------------------------------------
      // Check username
      // -------------------------------------------------------

      final usernameCheck = await _firestore
          .collection('users')
          .where(
            'username',
            isEqualTo: cleanUsername,
          )
          .limit(1)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        debugPrint(
          'Username already exists: $cleanUsername',
        );

        return false;
      }

      // -------------------------------------------------------
      // Create Firebase Authentication account
      // -------------------------------------------------------

      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        return false;
      }

      // -------------------------------------------------------
      // Firebase display name
      // -------------------------------------------------------

      await firebaseUser.updateDisplayName(
        cleanName,
      );

      // -------------------------------------------------------
      // Create profile
      // -------------------------------------------------------

      final newUser = UserProfile(
        id: firebaseUser.uid,
        name: cleanName,
        username: cleanUsername,
        email: cleanEmail,
        phone: cleanPhone,
        role: role,
        disabilityType: disabilityType,
        preferredAssistance: preferredAssistance,
      );

      // -------------------------------------------------------
      // Save profile to Firestore
      // -------------------------------------------------------

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(newUser.toMap());

      _currentUser = newUser;

      debugPrint(
        'Signup successful: $cleanUsername',
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

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } finally {
      _currentUser = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // REQUEST OPERATIONS
  // ---------------------------------------------------------------------------

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
        const Duration(milliseconds: 800),
      );

      final newRequest = AssistanceRequest(
        id: 'req_${DateTime.now().millisecondsSinceEpoch}',
        pnr: pnr,
        trainNo: trainNo,
        coach: coach,
        passengerId: _currentUser!.id,
        passengerName: _currentUser!.name,
        passengerPhone: _currentUser!.phone,
        status: 'Requested',
        assistanceType: assistanceType,
        timestamp: DateTime.now(),
        notes: notes,
      );

      _mockRequests.insert(0, newRequest);

      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE REQUEST STATUS
  // ---------------------------------------------------------------------------

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
        const Duration(milliseconds: 500),
      );

      final index = _mockRequests.indexWhere(
        (r) => r.id == requestId,
      );

      if (index == -1) {
        return false;
      }

      final oldReq = _mockRequests[index];

      _mockRequests[index] = oldReq.copyWith(
        status: newStatus,
        staffId: staffId ?? oldReq.staffId,
        staffName: staffName ?? oldReq.staffName,
      );

      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}