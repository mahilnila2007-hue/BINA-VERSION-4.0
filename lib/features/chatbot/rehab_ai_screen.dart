import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/exercise_presets.dart';
import '../../core/theme/color_palette.dart';
import '../auth/auth_provider.dart';
import 'chat_message.dart';
import 'rehab_ai_service.dart';

/// Full-Page ReHab AI Coach Screen (Section 21).
/// Safe rehabilitation assistant with quick question suggestions and clinical guardrails.
class ReHabAiScreen extends ConsumerStatefulWidget {
  const ReHabAiScreen({super.key});

  @override
  ConsumerState<ReHabAiScreen> createState() => _ReHabAiScreenState();
}

class _ReHabAiScreenState extends ConsumerState<ReHabAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ReHabAiService _aiService = ReHabAiService();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Hello! I am ReHab AI, your rehabilitation form coach. How can I assist you with your exercises today?',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  bool _isTyping = false;

  final List<String> _quickSuggestions = [
    'How do I position the camera?',
    'What does this exercise do?',
    'Why did the app say bend more?',
    'How many exercises do I have today?',
    'What does my progress mean?',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });

    _scrollToBottom();

    final prescription = ref.read(currentPrescriptionProvider) ??
        ExercisePresets.kneeExtensionPrescription;
    final sessions = ref.read(patientSessionsProvider);
    final adherence = sessions.isNotEmpty ? sessions.first.adherence : 84.0;

    final responseText = await _aiService.askQuestion(
      query: text,
      currentPrescription: prescription,
      currentAdherence: adherence,
    );

    if (mounted) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: responseText,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.warmWhite,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppPalette.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: AppPalette.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ReHab AI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoalDark,
                  ),
                ),
                Text(
                  'Rehabilitation Form Assistant',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.charcoalMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Safety Disclaimer Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppPalette.amberWarning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppPalette.amberWarning.withOpacity(0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: AppPalette.amberWarning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ReHab AI provides movement guidance and does not diagnose medical conditions.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.charcoalDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),

            // Typing Indicator
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppPalette.orange,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ReHab AI is thinking...',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppPalette.charcoalMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Suggestions Chips
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final suggestion = _quickSuggestions[index];
                  return ActionChip(
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppPalette.orange.withOpacity(0.35),
                    ),
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.charcoalDark,
                      ),
                    ),
                    onPressed: () => _sendMessage(suggestion),
                  );
                },
              ),
            ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(fontSize: 15),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: 'Ask ReHab AI a question...',
                        hintStyle: const TextStyle(
                          color: AppPalette.charcoalMuted,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppPalette.warmWhite,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: AppPalette.orange,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? AppPalette.orange : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(2) : null,
            bottomLeft: !msg.isUser ? const Radius.circular(2) : null,
          ),
          border: msg.isUser
              ? null
              : Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: msg.isUser ? Colors.white : AppPalette.charcoalDark,
            fontWeight: msg.isUser ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
