import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../../assessment/models/assessment_models.dart';
import '../../auth/services/auth_service.dart';

// Re-export ChatMessage so existing imports of this file still work
export '../../assessment/models/assessment_models.dart' show ChatMessage;

/// What the backend returns from POST /chatbot/intake
class ChatResponse {
  final String reply;
  /// 'chatting' | 'assessment_ready' | 'crisis'
  final String status;

  const ChatResponse({required this.reply, required this.status});

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
        reply: json['reply'] as String,
        status: json['status'] as String,
      );
}

class ChatException implements Exception {
  final String message;
  const ChatException(this.message);
}

class ChatService {
  final _authService = AuthService();

  Future<ChatResponse> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final token = await _authService.getSavedToken();
    if (token == null) throw const ChatException('Not authenticated.');

    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/chatbot/intake'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'message': message,
            'history': history.map((m) => m.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return ChatResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }

    final body = _tryDecode(response.body);
    final detail = body?['detail'];
    if (detail is String) throw ChatException(detail);
    throw ChatException('Request failed (${response.statusCode})');
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
