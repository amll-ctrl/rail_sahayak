enum UserRole { passenger, staff, admin }

class UserProfile {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final UserRole role;
  final String? disabilityType;
  final String? preferredAssistance;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    this.disabilityType,
    this.preferredAssistance,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String docId) {
    return UserProfile(
      id: docId,
      name: (map['name'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: _roleFromString(map['role']),
      disabilityType: map['disabilityType'],
      preferredAssistance: map['preferredAssistance'],
    );
  }

  static UserRole _roleFromString(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.passenger;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'role': switch (role) {
        UserRole.admin => 'admin',
        UserRole.staff => 'staff',
        UserRole.passenger => 'passenger',
      },
      'disabilityType': disabilityType,
      'preferredAssistance': preferredAssistance,
    };
  }
}
