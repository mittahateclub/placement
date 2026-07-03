import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

class _Result {
  final String id;
  final Map<String, dynamic> data;
  _Result(this.id, this.data);

  String? get testId => data['testId'] as String?;
  String get title => (data['testTitle'] as String?) ?? 'Untitled Test';
  int get totalQuestions => (data['totalQuestions'] as num?)?.toInt() ?? 0;
  String? get universityId => data['universityId'] as String?;
  String? get userId => data['userId'] as String?;
  DateTime? get submittedAt => toDate(data['submittedAt']);

  num get score =>
      (data['score'] as num?) ?? (data['attemptedQuestions'] as num?) ?? 0;

  double get percentage {
    final p = data['percentage'];
    if (p is num) return p.toDouble();
    return totalQuestions > 0 ? score / totalQuestions * 100 : 0;
  }
}

/// Performance across all assessments + per-test peer analysis
/// (reads the same test_results / testResults collections as the website).
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  List<_Result> _results = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    try {
      final snaps = await Future.wait([
        _db
            .collection('test_results')
            .where('userId', isEqualTo: uid)
            .get(),
        _db.collection('testResults').where('userId', isEqualTo: uid).get(),
      ]);
      final combined = [
        for (final snap in snaps)
          for (final d in snap.docs) _Result(d.id, d.data()),
      ]..sort((a, b) => (b.submittedAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.submittedAt?.millisecondsSinceEpoch ?? 0));
      if (mounted) {
        setState(() {
          _results = combined;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAnalysis(_Result result) async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scrollController) => _AnalysisSheet(
          result: result,
          uid: uid,
          scrollController: scrollController,
        ),
      ),
    );
  }

  static Color _pctColor(double pct) => pct >= 80
      ? AppColors.success
      : pct >= 60
          ? AppColors.amber
          : AppColors.danger;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageHeader(
            title: 'My Results',
            subtitle: 'Track your performance across all assessments.',
          ),
          const SizedBox(height: 16),
          if (_results.isEmpty)
            const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: "You haven't completed any tests yet.",
              subtitle:
                  'Take tests from the web portal — results will show here.',
            )
          else ...[
            // ── Summary stats ──
            Builder(builder: (context) {
              final avg = _results
                      .map((r) => r.percentage)
                      .reduce((a, b) => a + b) /
                  _results.length;
              final best = _results
                  .map((r) => r.percentage)
                  .reduce((a, b) => a > b ? a : b);
              return Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.emoji_events_outlined,
                      color: AppColors.blue,
                      value: '${_results.length}',
                      label: 'Tests Taken',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      icon: Icons.trending_up_rounded,
                      color: AppColors.success,
                      value: '${avg.toStringAsFixed(1)}%',
                      label: 'Average',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      icon: Icons.workspace_premium_outlined,
                      color: AppColors.amber,
                      value: '${best.toStringAsFixed(1)}%',
                      label: 'Best Score',
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 14),

            // ── Result cards ──
            ..._results.map((r) {
              final pct = r.percentage;
              final color = _pctColor(pct);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(r.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.display(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.2,
                                                  color: scheme.onSurface)),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatDate(r.submittedAt),
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: scheme.onSurface
                                                    .withValues(alpha: 0.45)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Score ${r.score} / ${r.totalQuestions}',
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface
                                                    .withValues(alpha: 0.7)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 54,
                                      height: 54,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned.fill(
                                            child: CircularProgressIndicator(
                                              value: (pct / 100).clamp(0, 1),
                                              strokeWidth: 4,
                                              strokeCap: StrokeCap.round,
                                              color: color,
                                              backgroundColor: color
                                                  .withValues(alpha: 0.15),
                                            ),
                                          ),
                                          Text(
                                            '${pct.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: color),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _showAnalysis(r),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                  ),
                                  icon: const Icon(Icons.bar_chart_rounded,
                                      size: 15),
                                  label: const Text('View Analysis'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Bottom sheet computing rank / percentile / peer board for a test,
/// mirroring the website's analysis modal.
class _AnalysisSheet extends StatefulWidget {
  final _Result result;
  final String uid;
  final ScrollController scrollController;

  const _AnalysisSheet({
    required this.result,
    required this.uid,
    required this.scrollController,
  });

  @override
  State<_AnalysisSheet> createState() => _AnalysisSheetState();
}

class _AnalysisSheetState extends State<_AnalysisSheet> {
  bool _loading = true;
  String _error = '';
  int _rank = 0;
  int _participants = 0;
  double _percentile = 0;
  double _average = 0;
  double _top = 0;
  List<(String, num, double, bool)> _board = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final testId = widget.result.testId;
      if (testId == null) {
        throw Exception('This result record is missing its test reference.');
      }
      final snap = await FirebaseFirestore.instance
          .collection('test_results')
          .where('testId', isEqualTo: testId)
          .get();

      final all = snap.docs.map((d) => _Result(d.id, d.data())).toList();
      final scoped = all
          .where((r) =>
              r.universityId != null &&
              r.universityId == widget.result.universityId)
          .toList();
      final peers = scoped.isNotEmpty ? scoped : all;

      peers.sort((a, b) {
        final pctDelta = b.percentage.compareTo(a.percentage);
        if (pctDelta != 0) return pctDelta;
        final scoreDelta = b.score.compareTo(a.score);
        if (scoreDelta != 0) return scoreDelta;
        return (a.submittedAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(b.submittedAt?.millisecondsSinceEpoch ?? 0);
      });

      final myIndex = peers.indexWhere(
          (r) => r.id == widget.result.id || r.userId == widget.uid);
      final rank = myIndex >= 0 ? myIndex + 1 : peers.length;
      final total = peers.length;

      var anon = 1;
      final board = peers.map((r) {
        final isYou = r.userId == widget.uid || r.id == widget.result.id;
        final label = isYou ? 'You' : 'Anonymous ${anon++}';
        return (label, r.score, r.percentage, isYou);
      }).toList();

      if (mounted) {
        setState(() {
          _rank = rank;
          _participants = total;
          _percentile = total > 0
              ? ((total - rank) / total * 1000).round() / 10
              : 0;
          _average = total > 0
              ? peers.map((r) => r.percentage).reduce((a, b) => a + b) / total
              : 0;
          _top = total > 0 ? peers.first.percentage : 0;
          _board = board;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text('Detailed Analysis',
            style: AppTheme.display(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface)),
        Text(widget.result.title,
            style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: LoadingDots()))
        else if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Text(_error,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 13)),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.leaderboard_outlined,
                  color: AppColors.accent,
                  value: '#$_rank',
                  label: 'Your Rank',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.groups_outlined,
                  color: AppColors.blue,
                  value: '$_participants',
                  label: 'Participants',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.percent_rounded,
                  color: AppColors.success,
                  value: '$_percentile%',
                  label: 'Percentile',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.timeline_rounded,
                  color: AppColors.amber,
                  value: '${_average.toStringAsFixed(1)}%',
                  label: 'Class Avg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const FieldLabel('Peer Performance'),
              const Spacer(),
              Text('Top: ${_top.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.45))),
            ],
          ),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, row) in _board.indexed) ...[
                  if (i > 0) const Divider(),
                  Container(
                    color: row.$4
                        ? AppColors.blue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('#${i + 1}',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.4))),
                        ),
                        Expanded(
                          child: Text(row.$1,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: row.$4
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: row.$4 ? AppColors.blue : null)),
                        ),
                        Text('${row.$2}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${row.$3.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
