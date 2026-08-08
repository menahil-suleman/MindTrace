import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../home/screens/dashboard_screen.dart';
import '../services/assessment_service.dart';

class ResultsScreen extends StatelessWidget {
  final CompleteResult result;

  const ResultsScreen({super.key, required this.result});

  Color get _riskColor {
    switch (result.riskLevel) {
      case 'high':
        return const Color(0xFF93000A);
      case 'moderate':
        return const Color(0xFF7D5A00);
      default:
        return const Color(0xFF1A6B3C);
    }
  }

  IconData get _riskIcon {
    switch (result.riskLevel) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'moderate':
        return Icons.info_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Your Results',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MindColors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (_) => false,
            ),
            child: const Text(
              'Dashboard',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w600,
                color: MindColors.primaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Complete badge ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: MindColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 44,
                  color: MindColors.primaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assessment Complete',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: MindColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thank you for sharing. We\'ve prepared your results.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: MindColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),

            // ── Framing message ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MindColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MindColors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_riskIcon, color: _riskColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.framing,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: MindColors.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Scores per instrument ───────────────────────────────────────
            const Text(
              'YOUR SCORES',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: MindColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...result.scores.entries.map((e) => _ScoreCard(
                  instrumentKey: e.key,
                  data: e.value as Map<String, dynamic>,
                )),
            const SizedBox(height: 24),

            // ── Recommendations ─────────────────────────────────────────────
            const Text(
              'RECOMMENDATIONS',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: MindColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...result.recommendations.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: MindColors.primaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          color: MindColors.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Actions ─────────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  (_) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MindColors.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
                child: const Text(
                  'Go to Dashboard',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'You can retake assessments anytime from your dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: MindColors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Score card ────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String instrumentKey;
  final Map<String, dynamic> data;

  const _ScoreCard({required this.instrumentKey, required this.data});

  String get _displayName {
    const names = {
      'gad7': 'GAD-7 — Anxiety',
      'phq9': 'PHQ-9 — Depression',
      'dass_stress': 'DASS — Stress',
    };
    return names[instrumentKey] ?? instrumentKey.toUpperCase();
  }

  Color get _severityColor {
    switch (data['severity']) {
      case 'severe':
      case 'extremely_severe':
      case 'moderately_severe':
        return const Color(0xFF93000A);
      case 'moderate':
        return const Color(0xFF7D5A00);
      default:
        return const Color(0xFF1A6B3C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = data['score'] as int? ?? 0;
    final maxScore = data['max_score'] as int? ?? 21;
    final label = data['label'] as String? ?? '';
    final note = data['clinical_note'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MindColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _displayName,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MindColors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _severityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _severityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: maxScore > 0 ? score / maxScore : 0,
              backgroundColor: MindColors.surfaceContainerLow,
              color: _severityColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$score / $maxScore',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: MindColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: MindColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
