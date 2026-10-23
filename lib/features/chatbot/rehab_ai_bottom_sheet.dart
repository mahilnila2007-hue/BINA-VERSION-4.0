import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/color_palette.dart';
import '../../core/theme/typography.dart';
import '../auth/auth_provider.dart';
import 'chat_message.dart';
import 'rehab_ai_service.dart';

/// Modal bottom sheet for ReHab AI Coach.
/// Accessible, large text, high contrast, and 1-tap suggested rehabilitation queries.
class ReHabAiBottomSheet extends ConsumerStatefulWidget {
  const ReHabAiBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReHabAiBottomSheet(),
    );
  }

  @override
  ConsumerState<ReHabAiBottomSheet> createState() => _ReHabAiBottomSheetState();
}

class _ReHabAiBottomSheetState extends ConsumerState<ReHabAiBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ReHabAiService _aiService = ReHabAiService();

  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'msg_welcome',
      text:
          "Hello Arun! I'm ReHab AI, your rehabilitation assistant.\n\nHow can I help you with your exercise today?",
      isUser: false,
      timestamp: DateTime.now(),
      quickSuggestions: [
        'How should I position the camera?',
        'What does 80% adherence mean?',
        'Why am I getting "bend more"?',
        'What does knee extension mean?',
      ],
    ),
  ];

  bool _isTyping = false;

  void _sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });

    _textController.clear();
    _scrollToBottom();

    final rx = ref.read(currentPrescriptionProvider);
    final sessions = ref.read(patientSessionsProvider);
    final currentAdherence = sessions.isNotEmpty ? sessions.first.adherence : 87.0;

    final responseText = await _aiService.askQuestion(
      query: query,
      currentPrescription: rx,
      currentAdherence: currentAdherence,
    );

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();
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
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.cardBorderLight,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ReHab AI Coach',
                        style: AppTypography.headingMedium().copyWith(fontSize: 20),
                      ),
                      Text(
                        'Rehabilitation Guidance & Form Q&A',
                        style: AppTypography.clinicalCaption(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 26),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorderLight),

          // Message history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageItem(msg);
              },
            ),
          ),

          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('ReHab AI is thinking...', style: AppTypography.clinicalCaption()),
                ],
              ),
            ),

          // Input Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariantLight,
              border: Border(top: BorderSide(color: AppColors.cardBorderLight)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Ask a question about your exercise...',
                        hintStyle: TextStyle(color: AppColors.textTertiaryLight, fontSize: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                      onPressed: () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: msg.isUser ? AppColors.primary : AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
                bottomLeft: !msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
              ),
              border: Border.all(
                color: msg.isUser ? AppColors.primaryDark : AppColors.cardBorderLight,
                width: 1.0,
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: msg.isUser ? Colors.white : AppColors.textPrimaryLight,
                fontWeight: msg.isUser ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),

          // Quick suggestions chips for elderly ease of use
          if (!msg.isUser && msg.quickSuggestions != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: msg.quickSuggestions!.map((suggestion) {
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.6),
                  side: const BorderSide(color: AppColors.primaryLight, width: 1.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _sendMessage(suggestion),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
