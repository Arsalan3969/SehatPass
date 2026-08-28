import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'models/chat_message.dart';
import 'widgets/ai_welcome_card.dart';
import 'widgets/ai_quick_actions_grid.dart';
import 'widgets/ai_suggested_chips.dart';
import 'widgets/ai_chat_bubble.dart';

const String _aiPlaceholderResponse =
    'Sehat AI is currently in development. AI responses will be available soon.';

class SehatAiScreen extends StatefulWidget {
  const SehatAiScreen({super.key});

  @override
  State<SehatAiScreen> createState() => _SehatAiScreenState();
}

class _SehatAiScreenState extends State<SehatAiScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Whether the chat thread is visible (at least one message sent).
  bool get _hasChatStarted => _messages.isNotEmpty || _isTyping;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _inputController.clear();
    _focusNode.unfocus();

    setState(() {
      _messages.add(ChatMessage(text: trimmed, sender: MessageSender.user));
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate AI response after a short delay.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: _aiPlaceholderResponse,
          sender: MessageSender.ai,
        ));
      });
      _scrollToBottom();
    });
  }

  void _onQuickAction(String actionTitle) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"$actionTitle" — coming soon.',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onSuggestionTapped(String text) {
    _inputController.text = text;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focusNode.requestFocus();
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Ensures layout shrinks when keyboard opens.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            _buildHeader(),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome card (hidden once chat starts to save space)
                    if (!_hasChatStarted) ...[
                      const AiWelcomeCard(),
                      const SizedBox(height: 24),
                    ],

                    // Quick actions
                    if (!_hasChatStarted) ...[
                      AiQuickActionsGrid(onActionTapped: _onQuickAction),
                      const SizedBox(height: 24),
                    ],

                    // Suggested chips (always visible if no chat)
                    if (!_hasChatStarted) ...[
                      AiSuggestedChips(
                          onSuggestionTapped: _onSuggestionTapped),
                      const SizedBox(height: 8),
                    ],

                    // ── Chat messages ────────────────────────────────────
                    if (_hasChatStarted) ...[
                      // Compact mini header when chat has started
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.psychology_outlined,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text('Sehat AI',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.primary)),
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._messages.map(
                        (msg) => AiChatBubble(message: msg),
                      ),
                      if (_isTyping) const AiTypingIndicator(),
                    ],
                  ],
                ),
              ),
            ),

            // ── Chat input bar ───────────────────────────────────────────
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sehat AI', style: AppTextStyles.headingLarge),
                const SizedBox(height: 4),
                Text(
                  'Your personal health assistant',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          // Notification icon — consistent with Home & Medicines
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary, size: 22),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                style: AppTextStyles.bodyLarge,
                textInputAction: TextInputAction.send,
                maxLines: 3,
                minLines: 1,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Ask anything about your health...',
                  hintStyle: AppTextStyles.bodyMedium,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: () => _sendMessage(_inputController.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x252E7D5E),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
