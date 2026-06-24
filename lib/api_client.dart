import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class HermesApi {
  // Android 模拟器用 10.0.2.2，真机用 127.0.0.1
  static const String baseUrl = 'http://127.0.0.1:8765';

  /// 发送消息（支持附件），返回 Hermes 回复
  static Future<String> sendMessage({
    required String text,
    String? sessionId,
    String? imagePath,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chat'));

    request.fields['text'] = text;
    if (sessionId != null) request.fields['session_id'] = sessionId;

    // 附件：multipart 上传文件
    if (imagePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] ?? '';
    }
    throw Exception('API error: ${response.statusCode}');
  }

  /// 健康检查
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
