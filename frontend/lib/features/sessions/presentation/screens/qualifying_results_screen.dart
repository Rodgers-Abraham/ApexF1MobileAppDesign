import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../sessions/data/sessions_provider.dart';

class QualifyingResultsScreen extends ConsumerWidget {
  final String sessionId;
  const QualifyingResultsScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(sessionDataProvider(sessionId));
    return dataAsync.when(
      loading: () => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'QUALIFYING RESULTS'),
        body: const SkeletonStandingsList(count: 10),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'QUALIFYING RESULTS'),
        body: ErrorRetryWidget(
          message: 'Could not load qualifying results.',
          icon: Icons.timer_outlined,
          onRetry: () =>
              ref.invalidate(sessionDataProvider(sessionId)),
        ),
      ),
      data: (data) => _QualifyingBody(data: data),
    );
  }
}

class _QualifyingBody extends StatefulWidget {
  final Map<String, dynamic> data;
  const _QualifyingBody({required this.data});

  @override
  State<_QualifyingBody> createState() =>
      _QualifyingBodyState();
}

class _QualifyingBodyState extends State<_QualifyingBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late List<String> _segments;

  @override
  void initState() {
    super.initState();
    final lapsMeta = (widget.data['laps'] as Map?) ?? {};
    _segments = (lapsMeta['segment_order'] as List?)
            ?.map((s) => s.toString())
            .toList() ??
        ['Q1', 'Q2', 'Q3'];
    _tabCtrl = TabController(
        length: _segments.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = (widget.data['event']?.toString() ?? '')
        .replaceAll('_', ' ');
    final sessionType =
        widget.data['session_type']?.toString() ?? 'Q';
    final meta = (widget.data['meta'] as Map?) ?? {};
    final circuit = meta['circuit']?.toString() ?? '';

    final lapsMeta = (widget.data['laps'] as Map?) ?? {};
    final segments =
        (lapsMeta['segments'] as Map?) ?? {};
    final pole = lapsMeta['pole'] as Map?;

    return Scaffold(
      backgroundColor: DS.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: DS.bg,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon:
                  Icon(Icons.arrow_back, color: DS.textPrimary),
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
                        width: 3, height: 20, color: DS.yellow),
                    const SizedBox(width: 8),
                    Text(sessionType.toUpperCase(),
                        style: DS.headline(size: 13)),
                    const Spacer(),
                    if (pole != null)
                      DSWidgets.statusChip(
                          'POLE ${pole['code'] ?? ''}',
                          color: DS.purple,
                          size: 7),
                  ]),
                ),

                // Tabs
                Container(
                  color: DS.surface0,
                  child: TabBar(
                    controller: _tabCtrl,
                    labelColor: DS.yellow,
                    unselectedLabelColor: DS.textMuted,
                    indicatorColor: DS.yellow,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle:
                        DS.labelCaps(size: 9, color: DS.yellow),
                    unselectedLabelStyle: DS.labelCaps(
                        size: 9, color: DS.textMuted),
                    tabs: _segments
                        .map((s) => Tab(
                              key: Key('qual_tab_$s'),
                              text: s,
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: _segments.map((seg) {
            final segData =
                segments[seg] as Map? ?? {};
            final finalOrder =
                (segData['final_order'] as List?) ?? [];
            final eliminated =
                (segData['eliminated'] as List?) ?? [];

            if (finalOrder.isEmpty) {
              return Center(
                child: Text('No data for $seg.',
                    style: DS.body(
                        size: 12, color: DS.textMuted)),
              );
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
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
                                size: 7,
                                color: DS.textMuted))),
                    const SizedBox(width: 6),
                    SizedBox(
                        width: 40,
                        child: Text('CODE',
                            style: DS.labelCaps(
                                size: 7,
                                color: DS.textMuted))),
                    Expanded(
                        child: Text('TEAM',
                            style: DS.labelCaps(
                                size: 7,
                                color: DS.textMuted))),
                    SizedBox(
                        width: 76,
                        child: Text('BEST LAP',
                            textAlign: TextAlign.right,
                            style: DS.labelCaps(
                                size: 7,
                                color: DS.textMuted))),
                    SizedBox(
                        width: 60,
                        child: Text('GAP',
                            textAlign: TextAlign.right,
                            style: DS.labelCaps(
                                size: 7,
                                color: DS.textMuted))),
                  ]),
                ),

                // Classified rows
                ...finalOrder.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final d = entry.value as Map;
                  final code = d['code']?.toString() ?? '';
                  final team = d['team']?.toString() ?? '';
                  final color =
                      d['color']?.toString() ?? 'FFFFFF';
                  final bestS =
                      (d['best_s'] as num?)?.toDouble() ?? 0;
                  final gapS =
                      (d['gap_s'] as num?)?.toDouble() ?? 0;
                  final isOverallFastest = idx == 0;
                  final isOut = eliminated.contains(code);

                  String bestFmt = '—';
                  if (bestS > 0) {
                    final m = (bestS ~/ 60).toInt();
                    final s = bestS - m * 60;
                    bestFmt =
                        '$m:${s.toStringAsFixed(3).padLeft(6, '0')}';
                  }
                  final gapFmt = gapS == 0.0
                      ? 'LEADER'
                      : '+${gapS.toStringAsFixed(3)}';

                  final tcVal =
                      int.tryParse('FF$color', radix: 16) ??
                          0xFFFFFFFF;
                  final teamColor = Color(tcVal);

                  return Container(
                    key: Key('qual_row_${code}_$seg'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOut
                          ? DS.surface0
                          : DS.surface1,
                      border: Border(
                          left: BorderSide(
                              color: isOut
                                  ? DS.outline
                                  : teamColor,
                              width: 3),
                          bottom: BorderSide(
                              color: DS.outline,
                              width: 0.5)),
                    ),
                    child: Row(children: [
                      SizedBox(
                          width: 28,
                          child: Row(children: [
                            Text('P${idx + 1}',
                                style: DS.telemetry(
                                    size: 11,
                                    color: isOut
                                        ? DS.textMuted
                                        : DS.textPrimary)),
                            if (isOut)
                              Padding(
                                padding:
                                    const EdgeInsets.only(
                                        left: 2),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 3,
                                          vertical: 1),
                                  decoration: BoxDecoration(
                                    color: DS.red
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        DS.aeroCornerSm,
                                  ),
                                  child: Text('OUT',
                                      style: DS.labelCaps(
                                          size: 6,
                                          color: DS.red)),
                                ),
                              ),
                          ])),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: 40,
                          child: Text(
                            code,
                            style: DS.driverCode(
                                size: 12,
                                color: isOverallFastest
                                    ? DS.purple
                                    : isOut
                                        ? DS.textMuted
                                        : DS.textPrimary),
                          )),
                      Expanded(
                          child: Text(team,
                              style: DS.labelCaps(
                                  size: 7,
                                  color: DS.textMuted),
                              overflow: TextOverflow.ellipsis)),
                      SizedBox(
                          width: 76,
                          child: Text(bestFmt,
                              textAlign: TextAlign.right,
                              style: DS.telemetry(
                                  size: 10,
                                  color: isOverallFastest
                                      ? DS.purple
                                      : isOut
                                          ? DS.textMuted
                                          : DS.textPrimary))),
                      SizedBox(
                          width: 60,
                          child: Text(gapFmt,
                              textAlign: TextAlign.right,
                              style: DS.telemetry(
                                  size: 9,
                                  color: DS.textMuted))),
                    ]),
                  );
                }),

                // Final grid after Q3 / last segment
                if (seg == _segments.last &&
                    lapsMeta['final_grid'] != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    child: Row(children: [
                      Container(
                          width: 3,
                          height: 16,
                          color: DS.teal),
                      const SizedBox(width: 8),
                      Text('FINAL GRID',
                          style:
                              DS.labelCaps(size: 9, color: DS.teal)),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  ...(lapsMeta['final_grid'] as List? ?? [])
                      .asMap()
                      .entries
                      .map((e) {
                    final d = e.value as Map;
                    final code = d['code']?.toString() ?? '';
                    final isPole = e.key == 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: DS.outline,
                                width: 0.5)),
                      ),
                      child: Row(children: [
                        SizedBox(
                            width: 28,
                            child: Text('P${e.key + 1}',
                                style: DS.telemetry(
                                    size: 11,
                                    color: DS.textMuted))),
                        const SizedBox(width: 6),
                        Text(
                          code,
                          style: DS.driverCode(
                              size: 12,
                              color: isPole
                                  ? DS.purple
                                  : DS.textPrimary),
                        ),
                        if (isPole) ...[
                          const SizedBox(width: 6),
                          DSWidgets.statusChip('POLE',
                              color: DS.purple, size: 7),
                        ],
                      ]),
                    );
                  }),
                ],
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
