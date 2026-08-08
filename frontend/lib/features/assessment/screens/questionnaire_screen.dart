import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/assessment_service.dart';
import 'results_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  /// Ordered list of questionnaire keys e.g. ['gad7', 'phq9', 'dass_stress']
  final List<String> questionnaires;
  final Map<String, String> displayNames;
  final Map<String, String> conditionHints;

  const QuestionnaireScreen({
    super.key,
    required this.questionnaires,
    required this.displayNames,
    required this.conditionHints,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _service = AssessmentService();

  // Which instrument are we on (index into widget.questionnaires)
  int _instrumentIndex = 0;

  // Answers collected for the current instrument
  final List<int> _currentAnswers = [];

  // All completed scores: { 'gad7': {'score': 15, 'answers': [...]}, ... }
  final Map<String, Map<String, dynamic>> _allScores = {};

  // Current question being shown
  QuestionResult? _currentQuestion;

  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedValue;   // highlighted option before confirm

  String get _currentKey => widget.questionnaires[_instrumentIndex];

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  // ── Load next question ────────────────────────────────────────────────────
  Future<void> _loadNextQuestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedValue = null;
    });

    try {
      final result = await _service.getQuestion(
        questionnaire: _currentKey,
        questionIndex: _currentAnswers.length,
        answers: List.from(_currentAnswers),
      );

      if (!mounted) return;

      if (result.status == 'crisis') {
        _showCrisisSheet(result.crisisMessage ?? '');
        setState(() => _isLoading = false);
        return;
      }

      if (result.status == 'complete') {
        // Save this instrument's score
        _allScores[_currentKey] = {
          'score': result.score,
          'answers': List.from(_currentAnswers),
        };
        _moveToNextInstrument();
        return;
      }

      setState(() {
        _currentQuestion = result;
        _isLoading = false;
      });
    } on AssessmentException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Could not reach the server. Check your connection.';
        _isLoading = false;
      });
    }
  }

  // ── User picks an answer ──────────────────────────────────────────────────
  void _onAnswer(int value) {
    setState(() => _selectedValue = value);
  }

  // ── Confirm answer ────────────────────────────────────────────────────────
  Future<void> _confirmAnswer() async {
    if (_selectedValue == null) return;
    _currentAnswers.add(_selectedValue!);
    await _loadNextQuestion();
  }

  // ── Move to next instrument ───────────────────────────────────────────────
  Future<void> _moveToNextInstrument() async {
    final nextIndex = _instrumentIndex + 1;

    if (nextIndex >= widget.questionnaires.length) {
      // All instruments done — go to complete
      await _submitComplete();
      return;
    }

    setState(() {
      _instrumentIndex = nextIndex;
      _currentAnswers.clear();
      _selectedValue = null;
    });

    await _loadNextQuestion();
  }

  // ── Submit complete ───────────────────────────────────────────────────────
  Future<void> _submitComplete() async {
    setState(() => _isLoading = true);
    try {
      final result = await _service.complete(_allScores);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(result: result),
        ),
      );
    } on AssessmentException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Could not submit results. Check your connection.';
        _isLoading = false;
      });
    }
  }

  // ── Crisis sheet ──────────────────────────────────────────────────────────
  void _showCrisisSheet(String message) {
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
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: MindColors.onSurface,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.phone_outlined, size: 20),
                label: const Text('Find Help Now',
                    style: TextStyle(
                        fontFamily: 'Manrope', fontWeight: FontWeight.w600)),
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
                  // Continue the assessment — don't penalise honesty
                  _moveToNextInstrument();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: MindColors.onSurface,
                  side:
                      const BorderSide(color: MindColors.outlineVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text("I'm Safe, Continue",
                    style: TextStyle(
                        fontFamily: 'Manrope', fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            const Text('You are not alone. Help is available 24/7.',
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: MindColors.onSurfaceVariant)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Computed progress ─────────────────────────────────────────────────────
  double get _overallProgress {
    final q = _currentQuestion;
    if (q == null) return 0;
    // Questions completed across all instruments so far
    final completedBefore = _allScores.length *
        (q.totalQuestions > 0 ? q.totalQuestions : 7);
    final completedNow = _currentAnswers.length;
    final total = widget.questionnaires.length *
        (q.totalQuestions > 0 ? q.totalQuestions : 7);
    return total > 0 ? (completedBefore + completedNow) / total : 0;
  }

  String get _stepLabel {
    final total = widget.questionnaires.length;
    return 'Step ${_instrumentIndex + 1} of $total';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MindColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.displayNames[_currentKey] ?? _currentKey.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MindColors.onSurface,
              ),
            ),
            Text(
              _stepLabel,
              style: const TextStyle(
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
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _overallProgress,
            backgroundColor: MindColors.surfaceContainerLow,
            color: MindColors.primaryContainer,
            minHeight: 3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: MindColors.primaryContainer,
              ),
            )
          : _errorMessage != null
              ? _ErrorView(
                  message: _errorMessage!,
                  onRetry: _loadNextQuestion,
                )
              : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final q = _currentQuestion;
    if (q == null) return const SizedBox();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time window instruction
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MindColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: MindColors.onSurfaceVariant),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Over the last 2 weeks, how often have you been bothered by:',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            color: MindColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Question text
                Text(
                  q.questionText ?? '',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: MindColors.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Answer options
                ...q.options.map((opt) => _OptionTile(
                      label: opt.label,
                      value: opt.value,
                      selected: _selectedValue == opt.value,
                      onTap: () => _onAnswer(opt.value),
                    )),

                const SizedBox(height: 16),

                // Safety note if critical question
                if (q.safetyCritical)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MindColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 14,
                            color: MindColors.onSurfaceVariant),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'This is from the PHQ-9 questionnaire. '
                            'Your answers are confidential.',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              color: MindColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Bottom action bar ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: MindColors.outlineVariant, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selectedValue != null ? _confirmAnswer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MindColors.primaryContainer,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        MindColors.surfaceContainerLow,
                    disabledForegroundColor: MindColors.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Next Question',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can skip any section if you prefer.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: MindColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? MindColors.primaryContainer.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? MindColors.primaryContainer
                : MindColors.outlineVariant,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? MindColors.primaryContainer
                      : MindColors.outline,
                  width: 2,
                ),
                color: selected
                    ? MindColors.primaryContainer
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? MindColors.primaryContainer
                      : MindColors.onSurface,
                ),
              ),
            ),
            Text(
              '($value)',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: MindColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 48, color: MindColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                color: MindColors.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: MindColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Try Again',
                  style: TextStyle(fontFamily: 'Manrope')),
            ),
          ],
        ),
      ),
    );
  }
}
