import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../domain/ocr_result_model.dart';
import '../../../core/network/api_client.dart';

class OcrRepository {
  final ApiClient _api = ApiClient.instance;

  Future<OcrResult> scanReceipt({
    required Uint8List imageBytes,
    required String filename,
    String? groupId,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: filename,
      ),
      if (groupId != null) 'group_id': groupId,
    });

    final response = await _api.postFormData('/ocr/scan', formData);
    return OcrResult.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
