import 'package:cloud_firestore/cloud_firestore.dart';

class AssistanceRequest {
  final String id;
  final String pnr;
  final String trainNo;
  final String coach;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String status; // Requested, Assigned, Assisting, Completed, Cancelled
  final List<String> assistanceType; // Wheelchair, Luggage Porter, Guiding Hand, etc.
  final DateTime timestamp;
  final String? staffId;
  final String? staffName;
  final String? notes;

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
    this.staffId,
    this.staffName,
    this.notes,
  });

  // Convert Firestore Document to AssistanceRequest object
  factory AssistanceRequest.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedTime;
    var rawTimestamp = map['timestamp'];
    if (rawTimestamp is Timestamp) {
      parsedTime = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTime = DateTime.parse(rawTimestamp);
    } else {
      parsedTime = DateTime.now();
    }

    return AssistanceRequest(
      id: docId,
      pnr: map['pnr'] ?? '',
      trainNo: map['trainNo'] ?? '',
      coach: map['coach'] ?? '',
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      passengerPhone: map['passengerPhone'] ?? '',
      status: map['status'] ?? 'Requested',
      assistanceType: List<String>.from(map['assistanceType'] ?? []),
      timestamp: parsedTime,
      staffId: map['staffId'],
      staffName: map['staffName'],
      notes: map['notes'],
    );
  }

  // Convert AssistanceRequest to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'pnr': pnr,
      'trainNo': trainNo,
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
    };
  }

  // Helper method to create a copy of the request with some updated fields
  AssistanceRequest copyWith({
    String? status,
    String? staffId,
    String? staffName,
  }) {
    return AssistanceRequest(
      id: id,
      pnr: pnr,
      trainNo: trainNo,
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
    );
  }
}
