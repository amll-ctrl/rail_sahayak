class TrainStop {
  final String stationCode;
  final String stationName;
  final String? scheduledArrival;
  final String? scheduledDeparture;
  final String? actualArrival;
  final String? actualDeparture;
  final int? delayMinutes;
  final String? platform;
  final int sequence;

  const TrainStop({
    required this.stationCode,
    required this.stationName,
    required this.sequence,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.actualArrival,
    this.actualDeparture,
    this.delayMinutes,
    this.platform,
  });

  factory TrainStop.fromMap(Map<String, dynamic> map) => TrainStop(
        stationCode: '${map['stationCode'] ?? map['code'] ?? ''}',
        stationName: '${map['stationName'] ?? map['name'] ?? ''}',
        sequence: int.tryParse('${map['sequence'] ?? 0}') ?? 0,
        scheduledArrival: map['scheduledArrival']?.toString() ?? map['arrival']?.toString(),
        scheduledDeparture: map['scheduledDeparture']?.toString() ?? map['departure']?.toString(),
        actualArrival: map['actualArrival']?.toString(),
        actualDeparture: map['actualDeparture']?.toString(),
        delayMinutes: int.tryParse('${map['delayMinutes'] ?? 0}'),
        platform: map['platform']?.toString(),
      );
}

class TrainInfo {
  final String number;
  final String name;
  final String? sourceCode;
  final String? destinationCode;
  final String? status;
  final String? currentStation;
  final int delayMinutes;
  final String? lastUpdatedAt;
  final List<TrainStop> stops;

  const TrainInfo({
    required this.number,
    required this.name,
    required this.delayMinutes,
    required this.stops,
    this.sourceCode,
    this.destinationCode,
    this.status,
    this.currentStation,
    this.lastUpdatedAt,
  });

  factory TrainInfo.fromMap(Map<String, dynamic> map) {
    final train = Map<String, dynamic>.from(map['train'] ?? const {});
    final live = Map<String, dynamic>.from(map['liveData'] ?? map['live'] ?? const {});
    final location = Map<String, dynamic>.from(live['currentLocation'] ?? const {});
    final rawRoute = (map['route'] as List?) ?? const [];

    return TrainInfo(
      number: '${train['number'] ?? map['trainNumber'] ?? ''}',
      name: '${train['name'] ?? map['trainName'] ?? 'Train'}',
      sourceCode: train['sourceCode']?.toString() ?? map['sourceStation']?.toString(),
      destinationCode: train['destinationCode']?.toString() ?? map['destinationStation']?.toString(),
      status: live['status']?.toString() ?? live['type']?.toString() ?? location['status']?.toString(),
      currentStation: location['stationCode']?.toString() ?? location['stationName']?.toString(),
      delayMinutes: int.tryParse('${live['overallDelayMinutes'] ?? map['delayMinutes'] ?? 0}') ?? 0,
      lastUpdatedAt: live['lastUpdatedAt']?.toString() ?? map['lastUpdatedAt']?.toString(),
      stops: rawRoute.map((item) => TrainStop.fromMap(Map<String, dynamic>.from(item as Map))).toList(),
    );
  }
}
