import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/assessment_service.dart';
import '../widgets/assessment_header.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/option_tiles.dart';
import 'crisis_screen.dart';
import 'results_screen.dart';

/// Renders the currently-active question plus a running Q&A chat log —
/// matches UI reference images 5 & 6 (radio-style options, answered
/// questions shown as chat bubbles). Drives POST /assessment/questionnaire
/// one question at a time, across every instrument /classify picked.
class QuestionnaireFlowScreen extends StatefulWidget {
  final ClassifyResult classifyResult;

  const QuestionnaireFlowScreen({super.key, required this.classifyResult});

  @override
  State<QuestionnaireFlowScreen> createState() => _QuestionnaireFlowScreenState();
}

class _QuestionnaireFlowScreenState extends State<QuestionnaireFlowScreen> {
  final _assessmentService = AssessmentService();
  final _scrollController = ScrollController();

  int _instrumentIndex = 0;
  List<int> _answers = []; // answers so far for the current instrument
  QuestionOut? _currentQuestion;
  final List<ChatMessage> _log = []; // rendered Q&A for the current instrument
  final Map<String, ScoreEntry> _finishedScores = {};

  bool _loading = true;
  String? _error;
  int? _selectedValue; // value picked for the current question, pre-submit

  String get _currentInstrument => widget.classifyResult.questionnaires[_instrumentIndex];

  @override
  void initState() {
    super.initState();
    _fetchQuestion();
  }

  @override
  void dispose() {
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

  Future<void> _fetchQuestion() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedValue = null;
    });
    try {
      final step = await _assessmentService.fetchQuestionnaireStep(
        questionnaire: _currentInstrument,
        questionIndex: _answers.length,
        answers: _answers,
      );
      if (!mounted) return;

      if (step.status == 'crisis') {
        setState(() => _loading = false);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CrisisScreen(
              trigger: 'phq9_q9',
              triggerMessage: '${_currentInstrument}_safety_item',
            ),
          ),
        );
        // A safety-critical answer ends the assessment here — leave the
        // questionnaire flow once the person confirms they're safe.
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (step.status == 'complete') {
        _finishedScores[_currentInstrument] = ScoreEntry(
          score: step.score ?? 0,
          answers: List.of(_answers),
        );
        _advanceToNextInstrumentOrFinish();
        return;
      }

      setState(() {
        _currentQuestion = step.question;
        _log.add(ChatMessage(role: 'assistant', content: step.question!.text));
        _loading = false;
      });
      _scrollToBottom();
    } on AssessmentException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not connect to server. Check your connection.';
        _loading = false;
      });
    }
  }

  void _advanceToNextInstrumentOrFinish() {
    final isLast = _instrumentIndex == widget.classifyResult.questionnaires.length - 1;
    if (isLast) {
      _submitComplete();
      return;
    }
    setState(() {
      _instrumentIndex += 1;
      _answers = [];
      _log.clear();
    });
    _fetchQuestion();
  }

  Future<void> _submitComplete() async {
    setState(() => _loading = true);
    try {
      final result = await _assessmentService.completeAssessment(_finishedScores);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
      );
    } on AssessmentException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not connect to server. Check your connection.';
        _loading = false;
      });
    }
  }

  void _selectOption(AnswerOption option) {
    if (_loading) return;
    setState(() => _selectedValue = option.value);
  }

  Future<void> _submitAnswer() async {
    if (_selectedValue == null || _currentQuestion == null) return;
    final question = _currentQuestion!;
    final chosen = question.options.firstWhere((o) => o.value == _selectedValue);

    setState(() {
      _log.add(ChatMessage(role: 'user', content: chosen.label));
      _answers = [..._answers, chosen.value];
      _currentQuestion = null;
    });
    _scrollToBottom();
    await _fetchQuestion();
  }

  int get _overallStepIndex {
    // Progress across ALL instruments combined, for the header bar.
    final perInstrumentTotal = widget.classifyResult.totalQuestions == 0
        ? 1
        : widget.classifyResult.totalQuestions;
    final doneBefore = _finishedScores.values.fold<int>(0, (sum, s) => sum + s.answers.length);
    return (doneBefore + _answers.length).clamp(0, perInstrumentTotal);
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
                stepIndex: _overallStepIndex,
                totalSteps: widget.classifyResult.totalQuestions == 0
                    ? 1
                    : widget.classifyResult.totalQuestions,
                onBack: () => Navigator.of(context).maybePop(),
                onExit: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: MindColors.error)),
                ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _log.length + (_loading && _currentQuestion == null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _log.length) return const TypingIndicator();
              final msg = _log[index];
              return msg.role == 'user'
                  ? UserChatBubble(message: msg.content)
                  : BotChatBubble(message: msg.content);
            },
          ),
        ),
        if (_currentQuestion != null) ...[
          const SizedBox(height: 8),
          ..._currentQuestion!.options.map(
            (o) => AnswerOptionTile(
              label: o.label,
              valueSuffix: '(${o.value})',
              selected: _selectedValue == o.value,
              onTap: () => _selectOption(o),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _selectedValue == null ? null : _submitAnswer,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Next'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
