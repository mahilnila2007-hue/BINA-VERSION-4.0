/// Message model for ReHab AI Chatbot.
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? quickSuggestions;

  const ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickSuggestions,
  }) : id = id ?? '';
}
