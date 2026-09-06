import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'data/sehat_ai_repository.dart';
import 'models/chat_message.dart';
import 'widgets/ai_welcome_card.dart';
import 'widgets/ai_quick_actions_grid.dart';
import 'widgets/ai_suggested_chips.dart';
import 'widgets/ai_chat_bubble.dart';

class SehatAiScreen extends StatefulWidget {
  final SehatAiRepository? repository;

  const SehatAiScreen({super.key, this.repository});

  @override
  State<SehatAiScreen> createState() => _SehatAiScreenState();
}

class _SehatAiScreenState extends State<SehatAiScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late final SehatAiRepository _repo;

  final List<ChatMessage> _messages = [];

  bool _isTyping = false;
  String? _patientName;

  bool get _isLandingMode => _messages.isEmpty && !_isTyping;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SehatAiRepository.instance;
    _loadInitialData();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Data & Initialization ──────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    try {
      final fetchedName = await _repo.getPatientName();
      if (!mounted) return;
      setState(() {
        _patientName = fetchedName;
      });
    } catch (_) {
      // Non-blocking fallback
    }
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _isTyping = false;
    });
    _inputController.clear();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _inputController.clear();
    _focusNode.unfocus();

    final userMsg = ChatMessage(
      text: trimmed,
      sender: MessageSender.user,
    );

    // Snapshot existing in-session history before adding current query
    final sessionHistory = List<ChatMessage>.from(_messages);

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final response = await _repo.sendMessage(
        trimmed,
        sessionHistory: sessionHistory,
      );
      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: response.answer,
          sender: MessageSender.ai,
          citations: response.citations,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
      });

      final errorMessage = e is SehatAiException
          ? e.message
          : 'Unable to connect to Sehat AI. Please check your connection and try again.';

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onQuickAction(String actionTitle) {
    _sendMessage(actionTitle);
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
                    // Welcome card, quick actions, suggested chips (only shown in landing mode)
                    if (_isLandingMode) ...[
                      AiWelcomeCard(patientName: _patientName),
                      const SizedBox(height: 24),
                      AiQuickActionsGrid(onActionTapped: _onQuickAction),
                      const SizedBox(height: 24),
                      AiSuggestedChips(onSuggestionTapped: _onSuggestionTapped),
                      const SizedBox(height: 8),
                    ],

                    // ── Chat messages ────────────────────────────────────
                    if (!_isLandingMode && (_messages.isNotEmpty || _isTyping)) ...[
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
                              child: const Icon(
                                Icons.psychology_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sehat AI',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: AppColors.primary),
                            ),
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
                      if (_isTyping)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(right: 48, bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sehat AI is thinking...',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sehat AI',
                  style: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Your personal health assistant',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // New Chat / Reset Button
          if (!_isLandingMode)
            IconButton(
              tooltip: 'New Chat',
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.primary, size: 24),
              onPressed: _startNewChat,
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
                onSubmitted: _isTyping ? null : _sendMessage,
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
            onTap: _isTyping ? null : () => _sendMessage(_inputController.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isTyping ? AppColors.textTertiary : AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        _isTyping ? Colors.transparent : const Color(0x252E7D5E),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
