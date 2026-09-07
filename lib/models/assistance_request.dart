import 'package:cloud_firestore/cloud_firestore.dart';

class AssistanceRequest {
  final String id;
  final String pnr;
  // Kept as the display label for backward compatibility with existing requests.
  final String trainNo;
  // New canonical train number used for live data lookups.
  final String trainNumber;
  final String coach;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String status; // Requested, Assigned, Assisting, Completed, Cancelled
  final List<String> assistanceType;
  final DateTime timestamp;
  final String? staffId;
  final String? staffName;
  final String? notes;
  final String travelClass;
  final String farePreference; // concession or full_fare
  final bool upgradeRequested;

  AssistanceRequest({
    required this.id,
    required this.pnr,
    required this.trainNo,
    required this.coach,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.status,
    required this.assistanceType,
    required this.timestamp,
    this.trainNumber = '',
    this.staffId,
    this.staffName,
    this.notes,
    this.travelClass = 'Not specified',
    this.farePreference = 'concession',
    this.upgradeRequested = false,
  });

  factory AssistanceRequest.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedTime;
    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is Timestamp) {
      parsedTime = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    final displayTrain = (map['trainNo'] ?? '').toString();
    final storedNumber = (map['trainNumber'] ?? '').toString();
    final derivedNumber = storedNumber.isNotEmpty
        ? storedNumber
        : RegExp(r'^\d{5}').firstMatch(displayTrain)?.group(0) ?? '';

    return AssistanceRequest(
      id: docId,
      pnr: (map['pnr'] ?? '').toString(),
      trainNo: displayTrain,
      trainNumber: derivedNumber,
      coach: (map['coach'] ?? '').toString(),
      passengerId: (map['passengerId'] ?? '').toString(),
      passengerName: (map['passengerName'] ?? '').toString(),
      passengerPhone: (map['passengerPhone'] ?? '').toString(),
      status: (map['status'] ?? 'Requested').toString(),
      assistanceType: List<String>.from(map['assistanceType'] ?? const []),
      timestamp: parsedTime,
      staffId: map['staffId']?.toString(),
      staffName: map['staffName']?.toString(),
      notes: map['notes']?.toString(),
      travelClass: (map['travelClass'] ?? 'Not specified').toString(),
      farePreference: (map['farePreference'] ?? 'concession').toString(),
      upgradeRequested: map['upgradeRequested'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pnr': pnr,
      'trainNo': trainNo,
      'trainNumber': trainNumber,
      'coach': coach,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'status': status,
      'assistanceType': assistanceType,
      'timestamp': Timestamp.fromDate(timestamp),
      'staffId': staffId,
      'staffName': staffName,
      'notes': notes,
      'travelClass': travelClass,
      'farePreference': farePreference,
      'upgradeRequested': upgradeRequested,
    };
  }

  AssistanceRequest copyWith({
    String? status,
    String? staffId,
    String? staffName,
  }) {
    return AssistanceRequest(
      id: id,
      pnr: pnr,
      trainNo: trainNo,
      trainNumber: trainNumber,
      coach: coach,
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      status: status ?? this.status,
      assistanceType: assistanceType,
      timestamp: timestamp,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      notes: notes,
      travelClass: travelClass,
      farePreference: farePreference,
      upgradeRequested: upgradeRequested,
    );
  }
}
