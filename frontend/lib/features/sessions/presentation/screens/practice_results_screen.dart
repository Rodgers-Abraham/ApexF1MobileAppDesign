import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../sessions/data/sessions_provider.dart';

class PracticeResultsScreen extends ConsumerWidget {
  final String sessionId;
  const PracticeResultsScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(sessionDataProvider(sessionId));
    return dataAsync.when(
      loading: () => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'PRACTICE RESULTS'),
        body: const SkeletonStandingsList(count: 10),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'PRACTICE RESULTS'),
        body: ErrorRetryWidget(
          message: 'Could not load practice results.',
          icon: Icons.timer_outlined,
          onRetry: () =>
              ref.invalidate(sessionDataProvider(sessionId)),
        ),
      ),
      data: (data) => _PracticeBody(data: data),
    );
  }
}

class _PracticeBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PracticeBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final event =
        (data['event']?.toString() ?? '').replaceAll('_', ' ');
    final sessionType =
        data['session_type']?.toString() ?? 'P1';
    final meta = (data['meta'] as Map?) ?? {};
    final circuit = meta['circuit']?.toString() ?? '';

    final lapsMeta = (data['laps'] as Map?) ?? {};
    final finalOrder =
        (lapsMeta['final_order'] as List?) ?? [];
    final hasSectorTimes =
        lapsMeta['has_sector_times'] == true;
    final sessionDurationS =
        (lapsMeta['session_duration_s'] as num?)?.toDouble();

    String durationLabel = '';
    if (sessionDurationS != null && sessionDurationS > 0) {
      final m = (sessionDurationS ~/ 60).toInt();
      durationLabel = '$m min';
    }

    return Scaffold(
      backgroundColor: DS.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: DS.bg,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: DS.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.toUpperCase(),
                    style: DS.headline(size: 15)),
                if (circuit.isNotEmpty)
                  Text(circuit,
                      style: DS.labelCaps(
                          size: 7, color: DS.textMuted)),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header strip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  color: DS.surface0,
                  child: Row(children: [
                    Container(
                        width: 3, height: 20, color: DS.teal),
                    const SizedBox(width: 8),
                    Text(sessionType.toUpperCase(),
                        style: DS.headline(size: 13)),
                    const Spacer(),
                    if (durationLabel.isNotEmpty)
                      DSWidgets.statusChip(durationLabel,
                          color: DS.teal, size: 7),
                  ]),
                ),

                if (finalOrder.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No timing data available.',
                          style: DS.body(
                              size: 12, color: DS.textMuted)),
                    ),
                  )
                else ...[
                  // Column headers
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    color: DS.surface0,
                    child: Row(children: [
                      SizedBox(
                          width: 28,
                          child: Text('P',
                              style: DS.labelCaps(
                                  size: 7, color: DS.textMuted))),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: 40,
                          child: Text('CODE',
                              style: DS.labelCaps(
                                  size: 7, color: DS.textMuted))),
                      Expanded(
                          child: Text('TEAM',
                              style: DS.labelCaps(
                                  size: 7, color: DS.textMuted))),
                      SizedBox(
                          width: 70,
                          child: Text('BEST LAP',
                              textAlign: TextAlign.right,
                              style: DS.labelCaps(
                                  size: 7, color: DS.textMuted))),
                      SizedBox(
                          width: 60,
                          child: Text('GAP',
                              textAlign: TextAlign.right,
                              style: DS.labelCaps(
                                  size: 7, color: DS.textMuted))),
                      SizedBox(
                          width: 36,
                          child: Text('LAPS',
                              textAlign: TextAlign.right,
                              style: DS.labelCaps(
                                  size: 7, color: DS.textMuted))),
                    ]),
                  ),

                  // Rows
                  ...finalOrder.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final d = entry.value as Map;
                    final code = d['code']?.toString() ?? '';
                    final team = d['team']?.toString() ?? '';
                    final color = d['color']?.toString() ?? 'FFFFFF';
                    final bestS =
                        (d['best_s'] as num?)?.toDouble() ?? 0;
                    final gapS =
                        (d['gap_s'] as num?)?.toDouble() ?? 0;
                    final laps =
                        (d['laps_completed'] as num?)?.toInt();
                    final isOverallFastest =
                        idx == 0; // leader = overall fastest

                    String bestFormatted = '—';
                    if (bestS > 0) {
                      final m = (bestS ~/ 60).toInt();
                      final s = bestS - m * 60;
                      bestFormatted =
                          '$m:${s.toStringAsFixed(3).padLeft(6, '0')}';
                    }
                    String gapFormatted =
                        gapS == 0.0 ? 'LEADER' : '+${gapS.toStringAsFixed(3)}';

                    final teamColorVal =
                        int.tryParse('FF$color', radix: 16) ??
                            0xFFFFFFFF;
                    final teamColor = Color(teamColorVal);

                    return Container(
                      key: Key('practice_row_$code'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: DS.surface1,
                        border: Border(
                            left: BorderSide(
                                color: teamColor, width: 3),
                            bottom: BorderSide(
                                color: DS.outline, width: 0.5)),
                      ),
                      child: Row(children: [
                        SizedBox(
                            width: 28,
                            child: Text('P${idx + 1}',
                                style: DS.telemetry(
                                    size: 11,
                                    color: DS.textPrimary))),
                        const SizedBox(width: 6),
                        SizedBox(
                            width: 40,
                            child: Text(
                              code,
                              style: DS.driverCode(
                                  size: 12,
                                  color: isOverallFastest
                                      ? DS.purple
                                      : DS.textPrimary),
                            )),
                        Expanded(
                            child: Text(team,
                                style: DS.labelCaps(
                                    size: 7,
                                    color: DS.textMuted),
                                overflow: TextOverflow.ellipsis)),
                        SizedBox(
                            width: 70,
                            child: Text(bestFormatted,
                                textAlign: TextAlign.right,
                                style: DS.telemetry(
                                    size: 10,
                                    color: isOverallFastest
                                        ? DS.purple
                                        : DS.textPrimary))),
                        SizedBox(
                            width: 60,
                            child: Text(gapFormatted,
                                textAlign: TextAlign.right,
                                style: DS.telemetry(
                                    size: 9,
                                    color: DS.textMuted))),
                        SizedBox(
                            width: 36,
                            child: Text(
                                laps != null ? '$laps' : '—',
                                textAlign: TextAlign.right,
                                style: DS.labelCaps(
                                    size: 8,
                                    color: DS.textMuted))),
                      ]),
                    );
                  }),

                  // Note if no sector times
                  if (!hasSectorTimes)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          12, 12, 12, 0),
                      child: Text(
                        'Sector times not available for this session.',
                        style: DS.body(
                            size: 10, color: DS.textMuted),
                      ),
                    ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
