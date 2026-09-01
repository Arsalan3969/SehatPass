import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'data/sehat_ai_repository.dart';
import 'models/chat_conversation_model.dart';
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
  List<ChatConversationModel> _conversations = [];
  ChatConversationModel? _activeConversation;

  bool _isTyping = false;
  bool _isLoadingHistory = true;
  String? _patientName;

  bool get _hasChatStarted => _messages.isNotEmpty || _isTyping;

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

  // ── Data & History ────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingHistory = true);

    try {
      final results = await Future.wait([
        _repo.getPatientName(),
        _repo.getConversations(),
      ]);

      if (!mounted) return;
      final fetchedName = results[0] as String;
      final conversations = results[1] as List<ChatConversationModel>;

      _patientName = fetchedName;
      _conversations = conversations;

      if (_conversations.isNotEmpty) {
        _activeConversation = _conversations.first;
        final history = await _repo.loadChatHistory(
          conversationId: _activeConversation?.id,
        );
        if (!mounted) return;
        _messages.clear();
        _messages.addAll(history);
      } else {
        _activeConversation = null;
        _messages.clear();
      }

      setState(() => _isLoadingHistory = false);
      if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _startNewChat() async {
    setState(() {
      _activeConversation = null;
      _messages.clear();
      _isTyping = false;
    });
    _inputController.clear();
    Navigator.of(context).maybePop();
  }

  Future<void> _switchConversation(ChatConversationModel conv) async {
    Navigator.of(context).maybePop();
    if (_activeConversation?.id == conv.id) return;

    setState(() {
      _activeConversation = conv;
      _isLoadingHistory = true;
      _messages.clear();
    });

    try {
      final history =
          await _repo.loadChatHistory(conversationId: conv.id);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history);
        _isLoadingHistory = false;
      });
      if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _deleteConversation(ChatConversationModel conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat', style: AppTextStyles.headingSmall),
        content: Text(
          'Delete "${conv.title}"? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.deleteConversation(conv.id);
      final updatedConvs = await _repo.getConversations();
      if (!mounted) return;

      setState(() {
        _conversations = updatedConvs;
        if (_activeConversation?.id == conv.id) {
          if (_conversations.isNotEmpty) {
            _activeConversation = _conversations.first;
          } else {
            _activeConversation = null;
            _messages.clear();
          }
        }
      });

      if (_activeConversation != null) {
        final history = await _repo.loadChatHistory(
          conversationId: _activeConversation?.id,
        );
        if (!mounted) return;
        setState(() {
          _messages.clear();
          _messages.addAll(history);
        });
      }
    }
  }

  Future<void> _clearCurrentChatMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Clear Messages', style: AppTextStyles.headingSmall),
        content: const Text(
          'Are you sure you want to clear all messages in this conversation?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _repo.clearChatHistory(
        conversationId: _activeConversation?.id,
      );
      if (!mounted) return;
      if (success) {
        setState(() {
          _messages.clear();
          _isTyping = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation messages cleared.'),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
      }
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _inputController.clear();
    _focusNode.unfocus();

    // If no active conversation, create one using message snippet as title
    if (_activeConversation == null) {
      final titleSnippet =
          trimmed.length > 28 ? '${trimmed.substring(0, 28)}...' : trimmed;
      final newConv =
          await _repo.createConversation(title: titleSnippet);
      _activeConversation = newConv;
      _conversations = await _repo.getConversations();
    }

    final currentConvId = _activeConversation?.id;

    setState(() {
      _messages.add(ChatMessage(
        text: trimmed,
        sender: MessageSender.user,
        conversationId: currentConvId,
      ));
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final response = await _repo.sendMessage(
        trimmed,
        conversationId: currentConvId,
      );
      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: response.answer,
          sender: MessageSender.ai,
          conversationId: currentConvId,
          citations: response.citations,
        ));
      });
      _scrollToBottom();

      // Refresh conversations list to reflect updated timestamp
      _repo.getConversations().then((updated) {
        if (mounted) {
          setState(() => _conversations = updated);
        }
      });
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

  void _openConversationsDrawer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chat History',
                  style: AppTextStyles.headingMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _startNewChat,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: AppColors.textTertiary),
                          const SizedBox(height: 10),
                          Text(
                            'No previous conversations yet',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final isSelected =
                            _activeConversation?.id == conv.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primarySurface
                                : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => _switchConversation(conv),
                            leading: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                            title: Text(
                              conv.title,
                              style: AppTextStyles.labelMedium.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${conv.createdAt.day}/${conv.createdAt.month}/${conv.createdAt.year}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.textTertiary, size: 18),
                              onPressed: () => _deleteConversation(conv),
                              tooltip: 'Delete Chat',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome card (hidden once chat starts to save space)
                          if (!_hasChatStarted) ...[
                            AiWelcomeCard(patientName: _patientName),
                            const SizedBox(height: 24),
                          ],

                          // Quick actions
                          if (!_hasChatStarted) ...[
                            AiQuickActionsGrid(onActionTapped: _onQuickAction),
                            const SizedBox(height: 24),
                          ],

                          // Suggested chips
                          if (!_hasChatStarted) ...[
                            AiSuggestedChips(
                                onSuggestionTapped: _onSuggestionTapped),
                            const SizedBox(height: 8),
                          ],

                          // ── Chat messages ────────────────────────────────────
                          if (_hasChatStarted) ...[
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
                                        size: 16),
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
                            if (_isTyping)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                margin: const EdgeInsets.only(
                                    right: 48, bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: AppColors.border),
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
    final title = _activeConversation != null
        ? _activeConversation!.title
        : 'Sehat AI';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Chat history / drawer button
          IconButton(
            tooltip: 'Chat History',
            icon: const Icon(Icons.history_rounded,
                color: AppColors.textPrimary, size: 24),
            onPressed: _openConversationsDrawer,
          ),
          const SizedBox(width: 4),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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

          // Start New Chat Button
          IconButton(
            tooltip: 'New Chat',
            icon: const Icon(Icons.edit_note_rounded,
                color: AppColors.primary, size: 26),
            onPressed: _startNewChat,
          ),

          if (_hasChatStarted)
            IconButton(
              tooltip: 'Clear conversation',
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.textSecondary, size: 22),
              onPressed: _clearCurrentChatMessages,
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
