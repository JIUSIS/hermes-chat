import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TaskStatus {
  final String status; // thinking | calling_tool | done
  final String? response;
  final String? toolName;

  final String? sessionId;

  TaskStatus({required this.status, this.response, this.toolName, this.sessionId});

  factory TaskStatus.fromJson(Map<String, dynamic> json) {
    return TaskStatus(
      status: json['status'] ?? 'thinking',
      response: json['response'],
      toolName: json['tool_name'],
      sessionId: json['session_id'],
    );
  }
}

class HermesApi {
  static const String baseUrl = 'http://127.0.0.1:8765';

  /// 发送消息，返回 (response, sessionId)
  static Future<(String, String?)> sendMessage({
    required String text,
    String? sessionId,
    String? filePath,
    void Function(TaskStatus)? onStatus,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chat'));

    request.fields['text'] = text;
    if (sessionId != null) request.fields['session_id'] = sessionId;
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final taskId = data['task_id'];

    // 轮询直到完成
    String? resultSessionId;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 300));
      final statusResp = await http
          .get(Uri.parse('$baseUrl/status/$taskId'))
          .timeout(const Duration(seconds: 5));
      if (statusResp.statusCode != 200) continue;

      final status = TaskStatus.fromJson(jsonDecode(statusResp.body));
      onStatus?.call(status);

      if (status.sessionId != null) resultSessionId = status.sessionId;

      if (status.status == 'done') {
        return (status.response ?? '', resultSessionId ?? sessionId);
      }
    }
  }

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
