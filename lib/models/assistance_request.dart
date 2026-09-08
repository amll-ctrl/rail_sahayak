import 'package:cloud_firestore/cloud_firestore.dart';

class AssistanceRequest {
  final String id;
  final String pnr;
  final String trainNo;
  final String trainNumber;
  final String coach;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String status;
  final List<String> assistanceType;
  final DateTime timestamp;
  final String? staffId;
  final String? staffName;
  final String? notes;
  final String travelClass;
  final String farePreference;
  final bool upgradeRequested;
  final DateTime? journeyDate;
  final String boardingStation;
  final String? seat;
  final String? platform;
  final String? currentLocation;
  final DateTime? atStationAt;
  final DateTime? acknowledgedAt;
  final DateTime? locatedAt;
  final DateTime? boardingAt;
  final DateTime? boardedAt;
  final DateTime? completedAt;
  final DateTime? escalatedAt;

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
    this.journeyDate,
    this.boardingStation = '',
    this.seat,
    this.platform,
    this.currentLocation,
    this.atStationAt,
    this.acknowledgedAt,
    this.locatedAt,
    this.boardingAt,
    this.boardedAt,
    this.completedAt,
    this.escalatedAt,
  });

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory AssistanceRequest.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
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
        : RegExp(r'^\d{5}')
                .firstMatch(displayTrain)
                ?.group(0) ??
            '';

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
      assistanceType: List<String>.from(
        map['assistanceType'] ?? const [],
      ),
      timestamp: parsedTime,
      staffId: map['staffId']?.toString(),
      staffName: map['staffName']?.toString(),
      notes: map['notes']?.toString(),
      travelClass: (map['travelClass'] ?? 'Not specified').toString(),
      farePreference:
          (map['farePreference'] ?? 'concession').toString(),
      upgradeRequested: map['upgradeRequested'] == true,
      journeyDate: _date(map['journeyDate']),
      boardingStation:
          (map['boardingStation'] ?? '').toString(),
      seat: map['seat']?.toString(),
      platform: map['platform']?.toString(),
      currentLocation: map['currentLocation']?.toString(),
      atStationAt: _date(map['atStationAt']),
      acknowledgedAt: _date(map['acknowledgedAt']),
      locatedAt: _date(map['locatedAt']),
      boardingAt: _date(map['boardingAt']),
      boardedAt: _date(map['boardedAt']),
      completedAt: _date(map['completedAt']),
      escalatedAt: _date(map['escalatedAt']),
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
      'journeyDate': journeyDate == null
          ? null
          : Timestamp.fromDate(journeyDate!),
      'boardingStation': boardingStation,
      'seat': seat,
      'platform': platform,
      'currentLocation': currentLocation,
      'atStationAt': atStationAt == null
          ? null
          : Timestamp.fromDate(atStationAt!),
      'acknowledgedAt': acknowledgedAt == null
          ? null
          : Timestamp.fromDate(acknowledgedAt!),
      'locatedAt': locatedAt == null
          ? null
          : Timestamp.fromDate(locatedAt!),
      'boardingAt': boardingAt == null
          ? null
          : Timestamp.fromDate(boardingAt!),
      'boardedAt': boardedAt == null
          ? null
          : Timestamp.fromDate(boardedAt!),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'escalatedAt': escalatedAt == null
          ? null
          : Timestamp.fromDate(escalatedAt!),
    };
  }

  AssistanceRequest copyWith({
    String? status,
    String? staffId,
    String? staffName,
    String? notes,
    String? platform,
    String? currentLocation,
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
      notes: notes ?? this.notes,
      travelClass: travelClass,
      farePreference: farePreference,
      upgradeRequested: upgradeRequested,
      journeyDate: journeyDate,
      boardingStation: boardingStation,
      seat: seat,
      platform: platform ?? this.platform,
      currentLocation: currentLocation ?? this.currentLocation,
      atStationAt: atStationAt,
      acknowledgedAt: acknowledgedAt,
      locatedAt: locatedAt,
      boardingAt: boardingAt,
      boardedAt: boardedAt,
      completedAt: completedAt,
      escalatedAt: escalatedAt,
    );
  }
}