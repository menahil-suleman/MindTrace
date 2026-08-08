import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../assessment/screens/questionnaire_screen.dart';
import '../../assessment/services/assessment_service.dart';
import '../services/chat_service.dart';

class IntakeChatScreen extends StatefulWidget {
  const IntakeChatScreen({super.key});

  @override
  State<IntakeChatScreen> createState() => _IntakeChatScreenState();
}

class _IntakeChatScreenState extends State<IntakeChatScreen> {
  final _chatService = ChatService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  // Full conversation history sent to the backend on every turn
  final List<ChatMessage> _history = [];

  // What's shown in the UI — includes a 'typing' bubble when bot is thinking
  final List<_UIMessage> _uiMessages = [];

  bool _isTyping = false;
  bool _inputLocked = false;
  bool _isClassifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Boot the conversation — send an empty first message to get Mira's greeting
    _bootConversation();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Boot ──────────────────────────────────────────────────────────────────
  /// Sends a silent opening ping so Mira delivers her greeting automatically.
  Future<void> _bootConversation() async {
    setState(() => _isTyping = true);
    try {
      final response = await _chatService.sendMessage(
        message: 'hello',
        history: [],
      );
      _addBotMessage(response.reply);
      _handleStatus(response.status);
    } catch (e) {
      _addBotMessage(
          "Hi, I'm Mira. I'm here to help you understand what you've been feeling. "
          "What's been going on for you lately?");
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _inputLocked) return;

    _textCtrl.clear();
    setState(() {
      _errorMessage = null;
      _inputLocked = true;
      _isTyping = true;
    });

    // Add user bubble immediately
    _addUserMessage(text);

    try {
      final response = await _chatService.sendMessage(
        message: text,
        history: List.from(_history),   // snapshot before we append
      );

      // Append user turn to history AFTER sending
      _history.add(ChatMessage(role: 'user', content: text));

      _addBotMessage(response.reply);
      _history.add(ChatMessage(role: 'assistant', content: response.reply));

      _handleStatus(response.status);
    } on ChatException catch (e) {
      setState(() => _errorMessage = e.message);
      _inputLocked = false;
    } catch (_) {
      setState(() =>
          _errorMessage = 'Could not reach the server. Check your connection.');
      _inputLocked = false;
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  // ── Status handling ───────────────────────────────────────────────────────
  void _handleStatus(String status) {
    switch (status) {
      case 'crisis':
        // Input stays locked — user must tap "I'm Safe" to continue
        setState(() => _inputLocked = true);
        _showCrisisOptions();
        break;
      case 'assessment_ready':
        // Brief delay then show the "continue to questionnaire" button
        setState(() => _inputLocked = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() {});
        });
        break;
      default:
        setState(() => _inputLocked = false);
    }
  }

  void _showCrisisOptions() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MindColors.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MindColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFF93000A), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CRISIS DETECTED — We\'re concerned about your safety.',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF93000A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: open helpline URL
                },
                icon: const Icon(Icons.phone_outlined, size: 20),
                label: const Text(
                  'Find Help Now',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF93000A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _inputLocked = false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: MindColors.onSurface,
                  side: const BorderSide(color: MindColors.outlineVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text(
                  "I'm Safe, Continue",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are not alone. Help is available 24/7.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                color: MindColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Navigate to questionnaire ─────────────────────────────────────────────
  Future<void> _navigateToQuestionnaire() async {
    setState(() => _isClassifying = true);
    try {
      final classifyResult =
          await AssessmentService().classify(_history);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuestionnaireScreen(
            questionnaires: classifyResult.questionnaires,
            displayNames: classifyResult.displayNames,
            conditionHints: classifyResult.conditionHints,
          ),
        ),
      );
    } on AssessmentException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() =>
          _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  // ── Message helpers ───────────────────────────────────────────────────────
  void _addUserMessage(String text) {
    setState(() => _uiMessages.add(_UIMessage(role: 'user', text: text)));
    _scrollToBottom();
  }

  void _addBotMessage(String text) {
    setState(() => _uiMessages.add(_UIMessage(role: 'assistant', text: text)));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Check if last bot message indicates assessment is ready
    // ignore: unused_local_variable
    final assessmentReady = _history.isNotEmpty &&
        _history.last.role == 'assistant' &&
        _history.last.content.contains('[ASSESSMENT_READY]') == false &&
        _inputLocked &&
        _uiMessages.any((m) =>
            m.role == 'assistant' &&
            m.text.toLowerCase().contains('structured questions'));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MindColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assessment',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MindColors.onSurface,
              ),
            ),
            Text(
              'Step 1 of 8',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                color: MindColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Exit',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MindColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _history.length / 20,
            backgroundColor: MindColors.surfaceContainerLow,
            color: MindColors.primaryContainer,
            minHeight: 3,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Message list ────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _uiMessages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator bubble
                if (index == _uiMessages.length && _isTyping) {
                  return _TypingBubble();
                }
                return _MessageBubble(message: _uiMessages[index]);
              },
            ),
          ),

          // ── Error ────────────────────────────────────────────────────────
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: MindColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: Color(0xFF93000A),
                ),
              ),
            ),

          // ── Assessment ready CTA ─────────────────────────────────────────
          if (_inputLocked && !_isTyping && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isClassifying ? null : _navigateToQuestionnaire,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MindColors.primaryContainer,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        MindColors.primaryContainer.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                  child: _isClassifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue to Assessment',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),

          // ── Input bar ────────────────────────────────────────────────────
          if (!_inputLocked || _errorMessage != null)
            _InputBar(
              controller: _textCtrl,
              focusNode: _focusNode,
              onSend: _send,
              locked: _inputLocked,
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── UI message model ──────────────────────────────────────────────────────────

class _UIMessage {
  final String role;
  final String text;
  const _UIMessage({required this.role, required this.text});
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _UIMessage message;
  const _MessageBubble({required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? MindColors.primaryContainer
              : MindColors.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: isUser ? Colors.white : MindColors.onSurface,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: MindColors.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(animation: _anim, delay: 0),
            const SizedBox(width: 4),
            _Dot(animation: _anim, delay: 150),
            const SizedBox(width: 4),
            _Dot(animation: _anim, delay: 300),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Animation<double> animation;
  final int delay;

  const _Dot({required this.animation, required this.delay});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: MindColors.onSurfaceVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool locked;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: MindColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !locked,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                color: MindColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  color: MindColors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: MindColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(
                      color: MindColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: locked ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: locked
                    ? MindColors.surfaceContainerLow
                    : MindColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 20,
                color: locked ? MindColors.onSurfaceVariant : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
