import 'package:cloud_functions/cloud_functions.dart';

class AssistanceWorkflowService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> markPassengerAtStation({
    required String requestId,
    String? platform,
    String? location,
  }) async {
    await _functions.httpsCallable('markPassengerAtStation').call({
      'requestId': requestId,
      'platform': platform?.trim() ?? '',
      'location': location?.trim() ?? '',
    });
  }

  Future<void> updateStatus(String requestId, String status) async {
    await _functions.httpsCallable('updateAssistanceStatus').call({
      'requestId': requestId,
      'status': status,
    });
  }

  Future<void> escalate(String requestId) async {
    await _functions.httpsCallable('escalateAssistanceRequest').call({
      'requestId': requestId,
    });
  }
}
