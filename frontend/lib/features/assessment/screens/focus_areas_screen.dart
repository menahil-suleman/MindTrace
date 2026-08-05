import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/assessment_models.dart';
import '../services/assessment_service.dart';
import '../widgets/assessment_header.dart';
import 'questionnaire_flow_screen.dart';

/// "Path / Condition Classification" screen — matches UI reference image 3.
/// Calls POST /assessment/classify with the finished intake conversation,
/// then lists which questionnaires will run next.
class FocusAreasScreen extends StatefulWidget {
  final List<ChatMessage> intakeHistory;

  const FocusAreasScreen({super.key, required this.intakeHistory});

  @override
  State<FocusAreasScreen> createState() => _FocusAreasScreenState();
}

class _FocusAreasScreenState extends State<FocusAreasScreen> {
  final _assessmentService = AssessmentService();
  ClassifyResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _classify();
  }

  Future<void> _classify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _assessmentService.classify(widget.intakeHistory);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
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

  // Icon per instrument — purely visual, mirrors image 3's per-row icons.
  IconData _iconFor(String key) {
    switch (key) {
      case 'gad7':
        return Icons.self_improvement_rounded;
      case 'phq9':
        return Icons.sentiment_dissatisfied_rounded;
      case 'dass_stress':
        return Icons.bolt_rounded;
      default:
        return Icons.psychology_alt_rounded;
    }
  }

  String _tagFor(String key) {
    switch (key) {
      case 'gad7':
        return 'GAD-7';
      case 'phq9':
        return 'PHQ-9';
      case 'dass_stress':
        return 'DASS';
      default:
        return key.toUpperCase();
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
                stepIndex: 3,
                totalSteps: 5,
                onBack: () => Navigator.of(context).maybePop(),
                onExit: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: MindColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MindColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _classify, child: const Text('Retry')),
          ],
        ),
      );
    }

    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MindColors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: MindColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.psychology_alt, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Thanks. Based on your responses so far, I'd like to understand "
                  "a bit more about a few areas.",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text("We'll focus on:",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: result.questionnaires.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final key = result.questionnaires[i];
              final label = result.displayNames[key] ?? key;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: MindColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: MindColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconFor(key), size: 18, color: MindColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MindColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_tagFor(key), style: Theme.of(context).textTheme.labelLarge),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: MindColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This should take a few minutes.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: MindColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuestionnaireFlowScreen(classifyResult: result),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Continue'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
