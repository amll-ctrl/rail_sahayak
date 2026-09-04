import 'package:cloud_functions/cloud_functions.dart';

import '../models/train_info.dart';

class TrainService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<TrainInfo> getTrainInfo(String trainNumber) async {
    final normalized = trainNumber.replaceAll(RegExp(r'\D'), '');
    if (normalized.length != 5) {
      throw const FormatException('Enter a valid 5-digit train number.');
    }

    final callable = _functions.httpsCallable(
      'getTrainInfo',
      options: HttpsCallableOptions(timeout: Duration(seconds: 20)),
    );
    final result = await callable.call({'trainNumber': normalized});
    final data = Map<String, dynamic>.from(result.data as Map);
    return TrainInfo.fromMap(data);
  }
}
