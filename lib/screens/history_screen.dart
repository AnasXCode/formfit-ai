import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/history_period.dart';
import '../models/workout_session.dart';
import '../providers/sessions_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/session_tile.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
        ),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return const _EmptyHistory();
            }
            return TabBarView(
              children: [
                _PeriodTab(view: HistoryView.daily, sessions: sessions),
                _PeriodTab(view: HistoryView.weekly, sessions: sessions),
                _PeriodTab(view: HistoryView.monthly, sessions: sessions),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => _HistoryError(
            onRetry: () => ref.invalidate(sessionsProvider),
          ),
        ),
      ),
    );
  }
}

/// One tab: a summary chart on top, then one card per day / week / month.
/// Tapping a bar in the chart scrolls to that period's card and opens it.
class _PeriodTab extends StatefulWidget {
  const _PeriodTab({required this.view, required this.sessions});

  final HistoryView view;
  final List<WorkoutSession> sessions;

  @override
  State<_PeriodTab> createState() => _PeriodTabState();
}

class _PeriodTabState extends State<_PeriodTab> {
  final ScrollController _scroll = ScrollController();
  final Map<DateTime, GlobalKey> _keys = {};
  final Set<DateTime> _open = {};
  List<PeriodSummary> _periods = const [];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(PeriodSummary p) {
    setState(() {
      if (!_open.remove(p.start)) _open.add(p.start);
    });
  }

  /// Opens [p]'s card and scrolls it into view (used when a bar is tapped).
  Future<void> _reveal(PeriodSummary p) async {
    setState(() => _open.add(p.start));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    var ctx = _keys[p.start]?.currentContext;
    if (ctx == null && _scroll.hasClients) {
      // The card is far down the list and not built yet: jump close to it
      // first, then align it precisely.
      final index = _periods.indexWhere((e) => e.start == p.start);
      final guess = 260.0 + math.max(0, index) * 140.0;
      _scroll.jumpTo(math.min(guess, _scroll.position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      ctx = _keys[p.start]?.currentContext;
    }
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.05,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final periods = buildPeriods(widget.sessions, view);
    _periods = periods;
    // Newest first in the list; the chart reads oldest -> newest.
    final window = periods.take(windowSize(view)).toList().reversed.toList();

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: periods.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return _SummaryChart(view: view, window: window, onSelect: _reveal);
        }
        final period = periods[i - 1];
        return _PeriodCard(
          key: _keys.putIfAbsent(period.start, () => GlobalKey()),
          period: period,
          view: view,
          open: _open.contains(period.start),
          onToggle: () => _toggle(period),
        );
      },
    );
  }
}

class _SummaryChart extends StatelessWidget {
  const _SummaryChart({
    required this.view,
    required this.window,
    required this.onSelect,
  });

  final HistoryView view;
  final List<PeriodSummary> window;
  final void Function(PeriodSummary period) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalReps = window.fold<int>(0, (sum, p) => sum + p.reps);
    final totalSessions = window.fold<int>(0, (sum, p) => sum + p.sessionCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(windowLabel(view), style: textTheme.titleMedium),
              ),
              Text('$totalReps reps', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$totalSessions ${totalSessions == 1 ? 'session' : 'sessions'}',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _BarChart(
            values: [for (final p in window) p.reps],
            labels: [for (final p in window) chartLabel(view, p.start)],
            onTap: (i) => onSelect(window[i]),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Tap a bar to see the details',
              style: textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labels,
    required this.onTap,
  });

  final List<int> values;
  final List<String> labels;
  final void Function(int index) onTap;

  static const double _maxBarHeight = 80;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxValue = math.max(values.fold<int>(0, math.max), 1);
    final lastIndex = values.length - 1;

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              // The whole column (value, bar and label) is the tap target.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      values[i] > 0 ? '${values[i]}' : '',
                      style: textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height:
                      math.max(4.0, _maxBarHeight * values[i] / maxValue),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: values[i] == 0
                            ? scheme.outline.withValues(alpha: 0.5)
                            : (i == lastIndex
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.55)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    super.key,
    required this.period,
    required this.view,
    required this.open,
    required this.onToggle,
  });

  final PeriodSummary period;
  final HistoryView view;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = period;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canOpen = !p.isEmpty;
    final isOpen = open && canOpen;
    final emptyLabel = view == HistoryView.daily ? 'Rest day' : 'No workouts';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: p.isCurrent
              ? AppColors.accent.withValues(alpha: 0.5)
              : scheme.outline.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: canOpen ? onToggle : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: textTheme.titleMedium),
                        if (p.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(p.subtitle!, style: textTheme.bodyMedium),
                        ],
                        if (!p.isEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _MiniStat(
                                icon: Icons.fitness_center_rounded,
                                text:
                                '${p.sessionCount} ${p.sessionCount == 1 ? 'session' : 'sessions'}',
                              ),
                              _MiniStat(
                                icon: Icons.timer_outlined,
                                text: '${p.totalDuration.inMinutes} min',
                              ),
                              _MiniStat(
                                icon: Icons.verified_outlined,
                                text: '${p.avgForm.round()}% form',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (p.isEmpty)
                    Text(
                      emptyLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${p.reps}', style: textTheme.headlineMedium),
                        Text('reps', style: textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Icon(
                          isOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (isOpen) _details(context, p),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, PeriodSummary p) {
    if (view == HistoryView.daily) {
      // Daily: the individual sessions of that day.
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          children: [
            for (final s in p.sessions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SessionTile(session: s),
              ),
          ],
        ),
      );
    }

    // Weekly / monthly: one row per day that had a workout.
    final today = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.5)),
          for (final d in dayTotals(p.sessions))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDayLabel(d.day, today),
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  Text('${d.reps} reps', style: textTheme.titleMedium),
                  const SizedBox(width: 10),
                  Text('${d.sessions}×', style: textTheme.labelSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.primary),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No workouts yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Finish a push-up session and tap Save & Continue to see it here.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Couldn’t load your history.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}