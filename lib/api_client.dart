import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class HermesApi {
  // Android 模拟器用 10.0.2.2，真机用 127.0.0.1
  static const String baseUrl = 'http://127.0.0.1:8765';

  /// 发送消息，返回 Hermes 回复
  static Future<String> sendMessage({
    required String text,
    String? sessionId,
    String? imagePath,
  }) async {
    final body = <String, dynamic>{
      'text': text,
    };
    if (sessionId != null) body['session_id'] = sessionId;
    if (imagePath != null) {
      // 图片转 base64
      final bytes = await File(imagePath).readAsBytes();
      body['image'] = base64Encode(bytes);
    }

    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] ?? '';
    }
    throw Exception('API error: ${response.statusCode}');
  }

  /// 获取 session_id
  static Future<String?> getSessionId(String responseBody) async {
    try {
      final data = jsonDecode(responseBody);
      return data['session_id'];
    } catch (_) {
      return null;
    }
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
