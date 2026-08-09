import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../home/screens/dashboard_screen.dart';
import '../services/assessment_service.dart';

class ResultsScreen extends StatelessWidget {
  final CompleteResult result;

  const ResultsScreen({super.key, required this.result});

  Color _colorFor(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('sever') || s.contains('high')) return const Color(0xFFD32F2F);
    if (s.contains('moderate')) return const Color(0xFFF5A623);
    return const Color(0xFF34A853);
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

  double _gaugeFraction(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return 0.85;
      case 'moderate':
        return 0.5;
      default:
        return 0.15;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _colorFor(result.riskLevel);

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
              "Thank you for sharing. We've prepared your results.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: MindColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),

            // ── Overall summary card with gauge ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MindColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MindColors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_riskIcon, color: riskColor, size: 20),
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
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    height: 48,
                    child: CustomPaint(
                      painter: _GaugePainter(
                          fraction: _gaugeFraction(result.riskLevel)),
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
                  data: e.value,
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
  final InstrumentResult data;

  const _ScoreCard({required this.instrumentKey, required this.data});

  String get _displayName {
    const names = {
      'gad7': 'GAD-7 — Anxiety',
      'phq9': 'PHQ-9 — Depression',
      'dass_stress': 'DASS — Stress',
    };
    return names[instrumentKey] ?? instrumentKey.toUpperCase();
  }

  Color _severityColor(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('sever') || s.contains('high')) return const Color(0xFFD32F2F);
    if (s.contains('moderate')) return const Color(0xFFF5A623);
    return const Color(0xFF34A853);
  }

  @override
  Widget build(BuildContext context) {
    final score = data.score;
    final maxScore = data.maxScore;
    final label = data.label;
    final severity = data.severity;
    final note = data.clinicalNote;
    final color = _severityColor(severity);

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
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
              color: color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$score / $maxScore',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: MindColors.onSurfaceVariant,
            ),
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

// ── Gauge painter ─────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double fraction;
  const _GaugePainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - 4;
    const startAngle = math.pi;
    const sweep = math.pi;

    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final colors = [
      const Color(0xFF34A853),
      const Color(0xFFF5A623),
      const Color(0xFFD32F2F),
    ];
    final segment = sweep / colors.length;
    for (var i = 0; i < colors.length; i++) {
      bandPaint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + segment * i,
        segment,
        false,
        bandPaint,
      );
    }

    final needleAngle =
        startAngle + sweep * fraction.clamp(0.0, 1.0);
    final needleEnd = Offset(
      center.dx + radius * 0.85 * math.cos(needleAngle),
      center.dy + radius * 0.85 * math.sin(needleAngle),
    );
    final needlePaint = Paint()
      ..color = MindColors.onSurface
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 4, Paint()..color = MindColors.onSurface);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction;
}
