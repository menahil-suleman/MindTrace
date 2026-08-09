import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/assessment_service.dart';
import '../widgets/assessment_header.dart';
import '../widgets/chat_bubble.dart';
import 'crisis_screen.dart';
import 'focus_areas_screen.dart';

/// Chatbot Intake screen — freeform conversation with POST /chatbot/intake.
/// Visual style matches UI reference images 7–9 (chat bubbles, typing dots,
/// pill-shaped message input). The backend intake endpoint is plain
/// free-text chat (no structured multiple-choice endpoint), so this screen
/// is a straightforward chat UI rather than the button-driven mock in the
/// reference images.
class ChatbotIntakeScreen extends StatefulWidget {
  const ChatbotIntakeScreen({super.key});

  @override
  State<ChatbotIntakeScreen> createState() => _ChatbotIntakeScreenState();
}

class _ChatbotIntakeScreenState extends State<ChatbotIntakeScreen> {
  final _assessmentService = AssessmentService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Full history sent to the backend (includes the hidden opening turn).
  final List<ChatMessage> _apiHistory = [];
  // What's actually rendered — hides the synthetic opening message.
  final List<ChatMessage> _visibleMessages = [];

  bool _sending = false;
  bool _crisisTriggered = false;
  bool _assessmentReady = false;
  String? _errorText;
  String _lastUserMessage = '';

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// The backend requires a non-empty user message to open the conversation,
  /// but the reference UI shows the bot speaking first. We send a minimal
  /// kickoff message and never render it — only the bot's opening reply.
  Future<void> _startConversation() async {
    setState(() => _sending = true);
    try {
      final response = await _assessmentService.sendIntakeMessage(
        message: "Hi, I'm ready to begin.",
        history: const [],
      );
      _apiHistory.add(const ChatMessage(role: 'user', content: "Hi, I'm ready to begin."));
      _apiHistory.add(ChatMessage(role: 'assistant', content: response.reply));
      _visibleMessages.add(ChatMessage(role: 'assistant', content: response.reply));
      _lastUserMessage = "Hi, I'm ready to begin.";
      await _handleStatus(response.status);
    } on AssessmentException catch (e) {
      _errorText = e.message;
    } catch (_) {
      _errorText = 'Could not connect to server. Check your connection.';
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _crisisTriggered || _assessmentReady) return;

    setState(() {
      _visibleMessages.add(ChatMessage(role: 'user', content: text));
      _sending = true;
      _errorText = null;
    });
    _lastUserMessage = text;
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _assessmentService.sendIntakeMessage(
        message: text,
        history: List.of(_apiHistory),
      );
      _apiHistory.add(ChatMessage(role: 'user', content: text));
      _apiHistory.add(ChatMessage(role: 'assistant', content: response.reply));
      setState(() {
        _visibleMessages.add(ChatMessage(role: 'assistant', content: response.reply));
      });
      await _handleStatus(response.status);
    } on AssessmentException catch (e) {
      setState(() => _errorText = e.message);
    } catch (_) {
      setState(() => _errorText = 'Could not connect to server. Check your connection.');
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _handleStatus(String status) async {
    if (status == 'crisis') {
      setState(() => _crisisTriggered = true);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CrisisScreen(trigger: 'keyword', triggerMessage: _lastUserMessage),
        ),
      );
      // Backend doesn't hard-stop the conversation after a crisis turn —
      // re-enable input once the person confirms they're safe.
      if (mounted) setState(() => _crisisTriggered = false);
    } else if (status == 'assessment_ready') {
      setState(() => _assessmentReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MindColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              AssessmentHeader(
                stepIndex: 2,
                totalSteps: 5,
                onBack: () => Navigator.of(context).maybePop(),
                onExit: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 16),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_errorText!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: MindColors.error)),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _visibleMessages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _visibleMessages.length) {
                      return const TypingIndicator();
                    }
                    final msg = _visibleMessages[index];
                    return msg.role == 'user'
                        ? UserChatBubble(message: msg.content)
                        : BotChatBubble(message: msg.content);
                  },
                ),
              ),
              if (_assessmentReady) _ReadyBanner(history: List.of(_apiHistory)),
              if (!_crisisTriggered && !_assessmentReady) _MessageInputBar(
                controller: _controller,
                enabled: !_sending,
                onSend: _sendMessage,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: 'Type a message...'),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: MindColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onSend : null,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyBanner extends StatelessWidget {
  final List<ChatMessage> history;
  const _ReadyBanner({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MindColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: MindColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Intake complete.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FocusAreasScreen(intakeHistory: history),
                ),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}


