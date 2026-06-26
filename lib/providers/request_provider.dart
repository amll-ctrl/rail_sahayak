import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/assistance_request.dart';

class RequestProvider extends ChangeNotifier {
  UserProfile? _currentUser;
  bool _isLoading = false;
  
  // Storage for mock data (active during development or before Firebase is linked)
  final List<AssistanceRequest> _mockRequests = [];
  final Map<String, UserProfile> _mockUsers = {};

  RequestProvider() {
    _loadMockData();
  }

  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  
  List<AssistanceRequest> get requests => List.unmodifiable(_mockRequests);

  List<AssistanceRequest> get passengerRequests {
    if (_currentUser == null) return [];
    return _mockRequests.where((r) => r.passengerId == _currentUser!.id).toList();
  }

  List<AssistanceRequest> get staffRequests {
    return _mockRequests; // Staff sees all requests for coordination
  }

  // Populate mock data for testing
  void _loadMockData() {
    // Add a default passenger and staff user
    _mockUsers['passenger1'] = UserProfile(
      id: 'passenger1',
      name: 'Ramesh Kumar',
      email: 'ramesh@gmail.com',
      phone: '9876543210',
      role: UserRole.passenger,
      disabilityType: 'Wheelchair user',
      preferredAssistance: 'Needs boarding ramp assistance and wheelchair transfer.',
    );

    _mockUsers['staff1'] = UserProfile(
      id: 'staff1',
      name: 'Inspector Sunil Dutt',
      email: 'sunil@railnet.gov.in',
      phone: '9988776655',
      role: UserRole.staff,
    );

    // Seed mock assistance requests
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
        assistanceType: ['Wheelchair boarding assistance', 'Luggage support'],
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        staffId: 'staff1',
        staffName: 'Inspector Sunil Dutt',
        notes: 'Has heavy luggage, needs wheelchair from main entrance platform 1.',
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
        assistanceType: ['Elderly assistance', 'Guiding hand'],
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        notes: 'Passenger is 82 years old, walking slowly. Needs help climbing steps into the coach.',
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
        assistanceType: ['Visual guidance assistance'],
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        staffId: 'staff1',
        staffName: 'Inspector Sunil Dutt',
        notes: 'Visually impaired. Guided from station entry directly to seat 32.',
      )
    ]);
  }

  // Auth Operations
  Future<bool> login(String email, String password, bool isStaff) async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Try finding in mock users
    UserProfile? foundUser;
    for (var user in _mockUsers.values) {
      if (user.email.toLowerCase() == email.trim().toLowerCase() && 
          ((isStaff && user.role == UserRole.staff) || (!isStaff && user.role == UserRole.passenger))) {
        foundUser = user;
        break;
      }
    }

    // Default auto-creation if not found to make testing seamless
    if (foundUser == null) {
      final String dummyId = isStaff ? 'staff_${DateTime.now().millisecondsSinceEpoch}' : 'passenger_${DateTime.now().millisecondsSinceEpoch}';
      foundUser = UserProfile(
        id: dummyId,
        name: isStaff ? 'Station Support Staff' : 'Demo Passenger',
        email: email,
        phone: '9999999999',
        role: isStaff ? UserRole.staff : UserRole.passenger,
        disabilityType: isStaff ? null : 'Elderly Support',
        preferredAssistance: isStaff ? null : 'Requires walking assistance.',
      );
      _mockUsers[dummyId] = foundUser;
    }

    _currentUser = foundUser;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? disabilityType,
    String? preferredAssistance,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final String userId = '${role == UserRole.staff ? "staff" : "passenger"}_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = UserProfile(
      id: userId,
      name: name,
      email: email,
      phone: phone,
      role: role,
      disabilityType: disabilityType,
      preferredAssistance: preferredAssistance,
    );

    _mockUsers[userId] = newUser;
    _currentUser = newUser;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // Request Operations
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

    await Future.delayed(const Duration(milliseconds: 800));

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
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> updateRequestStatus(String requestId, String newStatus, {String? staffId, String? staffName}) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final oldReq = _mockRequests[index];
      _mockRequests[index] = oldReq.copyWith(
        status: newStatus,
        staffId: staffId ?? oldReq.staffId,
        staffName: staffName ?? oldReq.staffName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
