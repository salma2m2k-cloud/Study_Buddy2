import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class BackendStatus {
  final bool aiConfigured;
  final bool reachable;
  BackendStatus({required this.aiConfigured, required this.reachable});
}

class ApiException implements Exception {
  final String
      kind; // 'offline' | 'missing_key' | 'api' | 'network' | 'unknown'
  final String message;
  ApiException(this.kind, this.message);
}

/// Talks to the existing Vercel backend — the same api/chat.js and
/// api/status.js used by the web app. This app never holds the
/// OpenRouter key itself; it only ever calls this backend over HTTPS.
class ApiService {
  Future<BackendStatus> fetchStatus() async {
    try {
      final resp = await http
          .get(Uri.parse('$backendBaseUrl/api/status'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        return BackendStatus(aiConfigured: false, reachable: false);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return BackendStatus(
          aiConfigured: data['configured'] == true, reachable: true);
    } catch (_) {
      return BackendStatus(aiConfigured: false, reachable: false);
    }
  }

  /// Sends the system prompt + this conversation's recent messages, and
  /// returns Sage's reply text. Mirrors the web app's /api/chat contract
  /// exactly: { system, messages } in, { content: [{type:'text', text}] } out.
  Future<String> sendChat({
    required String system,
    required List<Map<String, String>> messages,
  }) async {
    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$backendBaseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system': system,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw ApiException(
        'network',
        'POST ERROR: $e',
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'unknown',
        'RAW SERVER RESPONSE: ${resp.body}',
      );
    }

    if (resp.statusCode != 200) {
      final error = data['error'] as String?;
      if (error == 'missing_api_key') {
        throw ApiException('missing_key',
            'Sage needs an API key. Add OPENROUTER_API_KEY in Vercel → Project Settings → Environment Variables, then redeploy.');
      }
      throw ApiException('api',
          (data['message'] as String?) ?? 'The AI provider returned an error.');
    }

    final content = data['content'] as List?;
    if (content == null)
      return "Sorry, I didn't catch that — could you try again?";
    final text = content
        .where((b) => b is Map && b['type'] == 'text')
        .map((b) => (b as Map)['text'] as String? ?? '')
        .join('\n')
        .trim();
    return text.isEmpty
        ? "Sorry, I didn't catch that — could you try again?"
        : text;
  }
}
