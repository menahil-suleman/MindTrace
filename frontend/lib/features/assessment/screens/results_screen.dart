import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../auth/services/auth_service.dart';
import '../models/assessment_models.dart';

/// "Results Summary" screen — matches UI reference image 1. Rendered from
/// the CompleteResult returned by POST /assessment/complete.
class ResultsScreen extends StatefulWidget {
  final CompleteResult result;

  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    AuthService().getCurrentUser().then((u) {
      if (mounted) setState(() => _name = u.username);
    }).catchError((_) {});
  }

  // green → amber → red across low/moderate/high (and per-instrument
  // minimal/mild/moderate/severe) severity strings from the backend.
  Color _colorFor(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('sever') || s.contains('high')) return const Color(0xFFD32F2F);
    if (s.contains('moderate')) return const Color(0xFFF5A623);
    return const Color(0xFF34A853);
  }

  String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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
    final result = widget.result;
    final riskColor = _colorFor(result.riskLevel);

    return Scaffold(
      backgroundColor: MindColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: MindColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: MindColors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assessment Complete!',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(
                          _name.isEmpty
                              ? "Here's a summary of your results."
                              : "Thank you, $_name. Here's a summary of your results.",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: MindColors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Overall Summary card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MindColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, color: MindColors.primary),
                        const SizedBox(width: 10),
                        Text('Overall Summary',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Overall Risk Level',
                                  style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 4),
                              Text(
                                _titleCase(result.riskLevel),
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: riskColor,
                                      fontSize: 28,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text('Based on your responses',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: MindColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          height: 70,
                          child: CustomPaint(
                            painter: _GaugePainter(fraction: _gaugeFraction(result.riskLevel)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Area Breakdown ─────────────────────────────────────────
              Text('Area Breakdown',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...result.scores.entries.map((e) => _AreaRow(
                    label: e.value.label.isEmpty ? _titleCase(e.key) : e.value.label,
                    severity: e.value.severity,
                    fraction: e.value.maxScore == 0 ? 0 : e.value.score / e.value.maxScore,
                    color: _colorFor(e.value.severity),
                  )),
              const SizedBox(height: 16),

              // ── Support banner ────────────────────────────────────────
              // Informational only — no backend endpoint for a support/
              // resources page exists yet, so this isn't tappable.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: MindColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: MindColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("You're not alone.",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  )),
                          Text('Support is available whenever you need it.',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // No "Download Full Report" / "Book a Session" buttons —
              // neither has a backend endpoint, so they're left out rather
              // than stubbed. Only real, wired action: return to Start.
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Done'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: MindColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Your results are confidential and secure.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: MindColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  final String label;
  final String severity;
  final double fraction;
  final Color color;

  const _AreaRow({
    required this.label,
    required this.severity,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.circle, size: 10, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: MindColors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            severity.isEmpty ? '' : '${severity[0].toUpperCase()}${severity.substring(1)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Semi-circle gauge with a green→amber→red band and a needle — mirrors
/// the dial in image 1's Overall Summary card.
class _GaugePainter extends CustomPainter {
  final double fraction; // 0.0–1.0 position of the needle along the arc

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

    final colors = [const Color(0xFF34A853), const Color(0xFFF5A623), const Color(0xFFD32F2F)];
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

    final needleAngle = startAngle + sweep * fraction.clamp(0.0, 1.0);
    final needleEnd = Offset(
      center.dx + radius * 0.85 * math.cos(needleAngle),
      center.dy + radius * 0.85 * math.sin(needleAngle),
    );
    final needlePaint = Paint()
      ..color = MindColors.onSurface
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 4, Paint()..color = MindColors.onSurface);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.fraction != fraction;
}
