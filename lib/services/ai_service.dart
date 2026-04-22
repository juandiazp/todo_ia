import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Aquí pondrás la URL que nos dé n8n más adelante
  final String webhookUrl =
      // "https://juan25.app.n8n.cloud/webhook-test/ia-notas";
      "https://juan25.app.n8n.cloud/webhook/ia-notas";

  Future<void> processNoteIA(
    String noteId,
    String content,
    String action,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": noteId,
          "content": content,
          "action": action, // 'summarize' o 'checklist'
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Error en la IA");
      }
    } catch (e) {
      print("Error conectando con n8n: $e");
    }
  }
}
