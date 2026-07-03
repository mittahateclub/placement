import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/resume_data.dart';
import '../services/ats_scorer.dart';
import 'common.dart';

/// ATS score panel: ring + category bars + expandable breakdown.
class AtsPanel extends StatefulWidget {
  final ResumeData data;
  final List<String> keywords;

  const AtsPanel({super.key, required this.data, this.keywords = const []});

  @override
  State<AtsPanel> createState() => _AtsPanelState();
}

class _AtsPanelState extends State<AtsPanel> {
  bool _expanded = false;

  static Color _color(num pct) => pct >= 75
      ? AppColors.success
      : pct >= 50
          ? AppColors.amber
          : AppColors.danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = AtsScorer.score(widget.data, widget.keywords);
    final gradeColor = _color(b.total);

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScoreRing(score: b.total, color: gradeColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('ATS Score',
                              style: AppTheme.display(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface)),
                          const SizedBox(width: 8),
                          Pill(label: b.gradeLabel, color: gradeColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How well your resume performs against ATS parsing.',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.45)),
                      ),
                      const SizedBox(height: 12),
                      _bar('Contact Info', b.contact.score, b.contact.max),
                      _bar('Section Coverage', b.sections.score, b.sections.max),
                      _bar('Keyword Match', b.keywords.score, b.keywords.max),
                      _bar('Content Depth', b.depth.score, b.depth.max),
                      _bar('Quality Signals', b.quality.score, b.quality.max),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expanded ? 'Hide Details' : 'View Detailed Breakdown',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface.withValues(alpha: 0.55)),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _details('Contact Info', b.contact.details),
                  _details('Section Coverage', b.sections.details),
                  if (widget.keywords.isNotEmpty) ...[
                    const FieldLabel('Keyword Match'),
                    if (b.keywords.matched.isNotEmpty)
                      _keywordWrap(
                          'Matched (${b.keywords.matched.length})',
                          b.keywords.matched,
                          AppColors.success),
                    if (b.keywords.missing.isNotEmpty)
                      _keywordWrap(
                          'Missing (${b.keywords.missing.length})',
                          b.keywords.missing,
                          AppColors.danger),
                    const SizedBox(height: 12),
                  ],
                  _details('Content Depth', b.depth.details),
                  _details('Quality Signals', b.quality.details),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(String label, int score, int max) {
    final pct = max > 0 ? score / max : 0.0;
    final color = _color(pct * 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              Text('$score/$max',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(title),
          ...items.map((item) {
            final color = item.startsWith('✓')
                ? AppColors.success
                : item.startsWith('△')
                    ? AppColors.amber
                    : AppColors.danger;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(item,
                  style: TextStyle(fontSize: 11.5, color: color)),
            );
          }),
        ],
      ),
    );
  }

  Widget _keywordWrap(String label, List<String> words, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45))),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: words
                .map((kw) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border:
                            Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Text(kw,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: color,
            ),
          ),
          Center(
            child: Text('$score',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ],
      ),
    );
  }
}
