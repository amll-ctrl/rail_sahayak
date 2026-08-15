enum UserRole { passenger, staff }

class UserProfile {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final UserRole role;
  final String? disabilityType; // For passenger (e.g. Wheelchair, Visually Impaired, Elderly)
  final String? preferredAssistance; // Specific needs details

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

  // Convert Firestore Document to UserProfile object
  factory UserProfile.fromMap(Map<String, dynamic> map, String docId) {
  return UserProfile(
    id: docId,
    name: map['name'] ?? '',
    username: map['username'] ?? '',
    email: map['email'] ?? '',
    phone: map['phone'] ?? '',
    role: (map['role'] == 'staff')
        ? UserRole.staff
        : UserRole.passenger,
    disabilityType: map['disabilityType'],
    preferredAssistance: map['preferredAssistance'],
  );
}

  // Convert UserProfile to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'role': role == UserRole.staff ? 'staff' : 'passenger',
      'disabilityType': disabilityType,
      'preferredAssistance': preferredAssistance,
    };
  }
}
