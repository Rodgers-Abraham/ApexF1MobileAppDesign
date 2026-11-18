import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../sessions/data/sessions_provider.dart';

class RaceResultsScreen extends ConsumerWidget {
  final String sessionId;
  const RaceResultsScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(sessionDataProvider(sessionId));
    return dataAsync.when(
      loading: () => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'RACE RESULTS'),
        body: const SkeletonStandingsList(count: 12),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'RACE RESULTS'),
        body: ErrorRetryWidget(
          message: 'Could not load race results.',
          icon: Icons.flag_outlined,
          onRetry: () => ref.invalidate(sessionDataProvider(sessionId)),
        ),
      ),
      data: (data) => _RaceResultsBody(data: data),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _RaceResultsBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RaceResultsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final event =
        (data['event']?.toString() ?? '').replaceAll('_', ' ');
    final sessionType =
        data['session_type']?.toString() ?? 'Race';
    final meta = (data['meta'] as Map?) ?? {};
    final circuit = meta['circuit']?.toString() ?? '';
    final country = meta['country']?.toString() ?? '';

    final rawResults = (data['results'] as List?) ?? [];
    final hasOfficialResults = rawResults.isNotEmpty &&
        rawResults.first is Map &&
        (rawResults.first as Map).containsKey('code');

    final lapsMeta = (data['laps'] as Map?) ?? {};
    final lapsList = (lapsMeta['laps'] as List?) ?? [];
    final lastLapPositions = lapsList.isNotEmpty
        ? (lapsList.last['positions'] as List? ?? [])
        : <dynamic>[];

    final events = (data['events'] as List?) ?? [];
    final weather = data['weather'] as Map?;

    // Determine winner code
    String winner = '';
    if (hasOfficialResults) {
      final first = rawResults
          .whereType<Map>()
          .where((r) => r['pos'] == 1)
          .firstOrNull;
      winner = first?['code']?.toString() ?? '';
    } else if (lastLapPositions.isNotEmpty) {
      final first = lastLapPositions
          .whereType<Map>()
          .where((p) => p['pos'].toString() == '1')
          .firstOrNull;
      winner = first?['code']?.toString() ?? '';
    }

    // Truncation note
    final totalLaps = (lapsMeta['total_laps'] as num?)?.toInt() ?? 0;
    final payloadLapCount = lapsList.length;
    final isTruncated =
        totalLaps > 0 && payloadLapCount < totalLaps;

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
                  Text(
                    '$circuit${country.isNotEmpty ? " · $country" : ""}',
                    style:
                        DS.labelCaps(size: 7, color: DS.textMuted),
                  ),
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
                        width: 3, height: 20, color: DS.red),
                    const SizedBox(width: 8),
                    Text(sessionType.toUpperCase(),
                        style: DS.headline(size: 13)),
                    const Spacer(),
                    if (winner.isNotEmpty) ...[
                      DSWidgets.statusChip('P1 $winner',
                          color: DS.yellow, size: 8),
                      const SizedBox(width: 6),
                    ],
                    if (!hasOfficialResults)
                      DSWidgets.statusChip('PROVISIONAL',
                          color: DS.orange, size: 7),
                  ]),
                ),

                // Truncation note
                if (isTruncated)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: DS.yellow.withValues(alpha: 0.08),
                      borderRadius: DS.aeroCornerSm,
                      border: Border.all(
                          color: DS.yellow.withValues(alpha: 0.4))),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 13, color: DS.yellow),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Session ended early — $payloadLapCount of $totalLaps scheduled laps run.',
                          style: DS.labelCaps(
                              size: 8, color: DS.yellow),
                        ),
                      ),
                    ]),
                  ),

                const SizedBox(height: 8),

                // Classification table
                _ClassificationTable(
                  rawResults: rawResults,
                  lastLapPositions: lastLapPositions,
                  hasOfficialResults: hasOfficialResults,
                  dnsDrivers:
                      (lapsMeta['dns_drivers'] as List? ?? [])
                          .map((d) => d.toString())
                          .toList(),
                ),
                const SizedBox(height: 16),

                // Summary header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('RACE SUMMARY',
                      style: DS.labelCaps(
                          size: 9, color: DS.textMuted)),
                ),
                const SizedBox(height: 8),

                ..._buildSummaryCards(
                    rawResults, events, lapsMeta, weather),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSummaryCards(
    List rawResults,
    List events,
    Map lapsMeta,
    Map? weather,
  ) {
    final cards = <Widget>[];

    // 1. Fastest lap
    final flEntry = rawResults
        .where((r) => r is Map && r['fastest_lap'] == true)
        .firstOrNull as Map?;
    if (flEntry != null) {
      cards.add(_SummaryCard(
        key: const Key('summary_fastest_lap'),
        icon: Icons.timer_outlined,
        color: DS.purple,
        title: 'FASTEST LAP',
        content:
            '${flEntry['code']} — ${flEntry['fastest_lap_time'] ?? '—'} (Lap ${flEntry['fastest_lap_num'] ?? '—'})',
      ));
    }

    // 2. Biggest climber
    if (rawResults.isNotEmpty &&
        (rawResults.first as Map? ?? {}).containsKey('grid')) {
      int bestGain = 0;
      String bestCode = '';
      for (final r in rawResults) {
        final rm = r as Map;
        final pos = (rm['pos'] as num?)?.toInt() ?? 99;
        final grid = (rm['grid'] as num?)?.toInt() ?? 0;
        if (grid > 0 && pos > 0 && pos <= 20) {
          final gain = grid - pos;
          if (gain > bestGain) {
            bestGain = gain;
            bestCode = rm['code']?.toString() ?? '';
          }
        }
      }
      if (bestGain > 0 && bestCode.isNotEmpty) {
        cards.add(_SummaryCard(
          key: const Key('summary_biggest_climber'),
          icon: Icons.trending_up,
          color: DS.green,
          title: 'BIGGEST CLIMBER',
          content: '$bestCode +$bestGain positions',
        ));
      }
    }

    // 3. Pit stops
    final pitSummary = _buildPitSummary(lapsMeta);
    if (pitSummary != null) {
      cards.add(_PitSummaryCard(
          key: const Key('summary_pit_stops'),
          summary: pitSummary));
    }

    // 4. Track events
    final trackEvents = events
        .whereType<Map>()
        .where((e) => {'SAFETY_CAR', 'VSC', 'RED_FLAG', 'PENALTY', 'YELLOW_FLAG'}
            .contains(e['type']?.toString()))
        .toList();
    if (trackEvents.isNotEmpty) {
      cards.add(_TrackEventsCard(
          key: const Key('summary_track_events'),
          events: trackEvents));
    }

    // 5. Retirements
    final retirements = events
        .whereType<Map>()
        .where((e) => e['type']?.toString() == 'DNF')
        .toList();
    if (retirements.isNotEmpty) {
      cards.add(_RetirementsCard(
          key: const Key('summary_retirements'),
          retirements: retirements));
    }

    // 6. Weather
    if (weather != null) {
      cards.add(_WeatherCard(
          key: const Key('summary_weather'), weather: weather));
    }

    // 7. Estimated overtakes
    final overtakeCount = _estimateOvertakes(lapsMeta);
    if (overtakeCount > 0) {
      cards.add(_SummaryCard(
        key: const Key('summary_overtakes'),
        icon: Icons.swap_vert_rounded,
        color: DS.teal,
        title: 'ON-TRACK OVERTAKES (ESTIMATED)',
        content:
            '$overtakeCount net position changes · net only, excludes pit-lane moves',
        small: true,
      ));
    }

    // 8. Driver of the Day — no legitimate data source
    // TODO: add when a data source becomes available.

    return cards;
  }

  Map? _buildPitSummary(Map lapsMeta) {
    final laps = lapsMeta['laps'] as List? ?? [];
    if (laps.isEmpty) return null;
    final stopsByDriver = <String, int>{};
    for (final lap in laps) {
      final lapMap = lap as Map;
      for (final pos in (lapMap['positions'] as List? ?? [])) {
        final pm = pos as Map;
        if (pm['is_pit_in'] == true) {
          final code = pm['code']?.toString() ?? '';
          if (code.isEmpty) continue;
          stopsByDriver[code] = (stopsByDriver[code] ?? 0) + 1;
        }
      }
    }
    if (stopsByDriver.isEmpty) return null;
    final maxStops =
        stopsByDriver.values.reduce((a, b) => a > b ? a : b);
    return {'stops_by_driver': stopsByDriver, 'max_stops': maxStops};
  }

  int _estimateOvertakes(Map lapsMeta) {
    final laps = lapsMeta['laps'] as List? ?? [];
    if (laps.length < 2) return 0;
    int total = 0;
    final prev = <String, int>{};
    for (final lap in laps) {
      for (final pos in ((lap as Map)['positions'] as List? ?? [])) {
        final pm = pos as Map;
        if (pm['status']?.toString() != 'RACING') continue;
        final code = pm['code']?.toString() ?? '';
        if (code.isEmpty) continue;
        final curr = (pm['pos'] as num?)?.toInt() ?? 99;
        final p = prev[code];
        if (p != null && curr > 0 && curr < p) total++;
        if (curr > 0) prev[code] = curr;
      }
    }
    return total;
  }
}

// ── Classification table ───────────────────────────────────────────────────

class _ClassificationTable extends StatelessWidget {
  final List rawResults;
  final List lastLapPositions;
  final bool hasOfficialResults;
  final List<String> dnsDrivers;

  const _ClassificationTable({
    required this.rawResults,
    required this.lastLapPositions,
    required this.hasOfficialResults,
    required this.dnsDrivers,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_ResultRow>[];

    if (hasOfficialResults) {
      for (final r in rawResults) {
        final rm = r as Map;
        rows.add(_ResultRow(
          pos: (rm['pos'] as num?)?.toInt() ?? 99,
          code: rm['code']?.toString() ?? '',
          name: rm['name']?.toString() ?? '',
          team: rm['team']?.toString() ?? '',
          timeOrGap: rm['time']?.toString(),
          status: rm['status']?.toString() ?? 'Finished',
          points: (rm['points'] as num?)?.toDouble(),
          grid: (rm['grid'] as num?)?.toInt(),
          isFastestLap: rm['fastest_lap'] == true,
        ));
      }
    } else {
      for (final p in lastLapPositions) {
        final pm = p as Map;
        rows.add(_ResultRow(
          pos: (pm['pos'] as num?)?.toInt() ?? 99,
          code: pm['code']?.toString() ?? '',
          name: '',
          team: pm['team']?.toString() ?? '',
          timeOrGap: null,
          status: pm['status']?.toString() ?? 'RACING',
          points: null,
          grid: null,
          isFastestLap: pm['is_fastest_lap_of_race'] == true,
        ));
      }
      for (final code in dnsDrivers) {
        rows.add(_ResultRow(
          pos: 99,
          code: code,
          name: '',
          team: '',
          timeOrGap: null,
          status: 'DNS',
          points: null,
          grid: null,
          isFastestLap: false,
        ));
      }
    }

    rows.sort((a, b) => a.pos.compareTo(b.pos));

    return Column(children: [
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
              child: Text('DRIVER / TEAM',
                  style: DS.labelCaps(
                      size: 7, color: DS.textMuted))),
          SizedBox(
              width: 80,
              child: Text('TIME/STATUS',
                  textAlign: TextAlign.right,
                  style: DS.labelCaps(
                      size: 7, color: DS.textMuted))),
          if (hasOfficialResults)
            SizedBox(
                width: 32,
                child: Text('PTS',
                    textAlign: TextAlign.right,
                    style: DS.labelCaps(
                        size: 7, color: DS.textMuted))),
        ]),
      ),
      ...rows.map((row) =>
          _ResultRowWidget(row: row, showPoints: hasOfficialResults)),
    ]);
  }
}

class _ResultRow {
  final int pos;
  final String code, name, team;
  final String? timeOrGap;
  final String status;
  final double? points;
  final int? grid;
  final bool isFastestLap;

  const _ResultRow({
    required this.pos,
    required this.code,
    required this.name,
    required this.team,
    required this.timeOrGap,
    required this.status,
    required this.points,
    required this.grid,
    required this.isFastestLap,
  });
}

class _ResultRowWidget extends StatelessWidget {
  final _ResultRow row;
  final bool showPoints;
  const _ResultRowWidget({required this.row, required this.showPoints});

  @override
  Widget build(BuildContext context) {
    final isActive =
        row.status == 'Finished' || row.status == 'RACING';
    final isDnf = !isActive &&
        row.status != 'DNS' &&
        row.status != 'DSQ';
    final isDns = row.status == 'DNS';
    final isDsq = row.status == 'DSQ';

    final posColor = isActive ? DS.textPrimary : DS.textMuted;

    String gridDelta = '';
    if (row.grid != null &&
        row.grid! > 0 &&
        row.pos > 0 &&
        isActive) {
      final delta = row.grid! - row.pos;
      if (delta > 0) {
        gridDelta = '+$delta';
      } else if (delta < 0) {
        gridDelta = '$delta';
      }
    }

    final statusText = isDnf
        ? 'DNF'
        : isDns
            ? 'DNS'
            : isDsq
                ? 'DSQ'
                : isActive
                    ? (row.timeOrGap ??
                        (row.pos == 1 ? 'WINNER' : '—'))
                    : row.status;

    return Container(
      key: Key('result_row_${row.code}'),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDnf || isDns || isDsq
            ? DS.surface0
            : DS.surface1,
        border: Border(
            bottom: BorderSide(color: DS.outline, width: 0.5)),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text(
            row.pos <= 22 ? 'P${row.pos}' : '—',
            style: DS.telemetry(size: 11, color: posColor),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Row(children: [
            Text(row.code,
                style: DS.driverCode(size: 12, color: posColor)),
            if (row.isFastestLap) ...[
              const SizedBox(width: 3),
              Icon(Icons.timer_outlined,
                  size: 10, color: DS.purple),
            ],
          ]),
        ),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (row.name.isNotEmpty)
                  Text(row.name,
                      style: DS.body(size: 11, color: posColor),
                      overflow: TextOverflow.ellipsis),
                if (row.team.isNotEmpty)
                  Text(row.team,
                      style:
                          DS.labelCaps(size: 7, color: DS.textMuted),
                      overflow: TextOverflow.ellipsis),
              ]),
        ),
        SizedBox(
          width: 80,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  statusText,
                  textAlign: TextAlign.right,
                  style: DS.telemetry(
                    size: 10,
                    color: isDnf || isDns || isDsq
                        ? DS.red
                        : DS.textPrimary,
                  ),
                ),
                if (gridDelta.isNotEmpty)
                  Text(gridDelta,
                      textAlign: TextAlign.right,
                      style: DS.labelCaps(
                          size: 7,
                          color: gridDelta.startsWith('+')
                              ? DS.green
                              : DS.red)),
              ]),
        ),
        if (showPoints) ...[
          SizedBox(
            width: 32,
            child: Text(
              row.points != null && row.points! > 0
                  ? row.points! == row.points!.truncateToDouble()
                      ? '${row.points!.toInt()}'
                      : row.points!.toStringAsFixed(1)
                  : '—',
              textAlign: TextAlign.right,
              style: DS.telemetry(size: 10, color: DS.teal),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Summary cards ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, content;
  final bool small;
  const _SummaryCard(
      {super.key,
      required this.icon,
      required this.color,
      required this.title,
      required this.content,
      this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DS.surface1,
        borderRadius: DS.aeroCornerSm,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: DS.labelCaps(size: 7, color: color)),
              const SizedBox(height: 2),
              Text(content,
                  style: small
                      ? DS.body(size: 10)
                      : DS.body(size: 12)),
            ])),
      ]),
    );
  }
}

class _PitSummaryCard extends StatelessWidget {
  final Map summary;
  const _PitSummaryCard(
      {super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final stops =
        summary['stops_by_driver'] as Map<String, int>;
    final maxStops = summary['max_stops'] as int;
    final sorted = stops.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DS.surface1,
        borderRadius: DS.aeroCornerSm,
        border: Border(
            left: BorderSide(color: DS.teal, width: 3)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.settings_outlined,
                  size: 16, color: DS.teal),
              const SizedBox(width: 8),
              Text('PIT STOPS',
                  style:
                      DS.labelCaps(size: 7, color: DS.teal)),
              const Spacer(),
              Text('MAX $maxStops STOPS',
                  style: DS.labelCaps(
                      size: 7, color: DS.textMuted)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: sorted
                  .take(12)
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                            color: DS.surface2,
                            borderRadius: DS.aeroCornerSm),
                        child: Text('${e.key} ×${e.value}',
                            style: DS.labelCaps(
                                size: 8,
                                color: DS.textPrimary)),
                      ))
                  .toList(),
            ),
          ]),
    );
  }
}

class _TrackEventsCard extends StatelessWidget {
  final List<Map> events;
  const _TrackEventsCard(
      {super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DS.surface1,
        borderRadius: DS.aeroCornerSm,
        border: Border(
            left: BorderSide(color: DS.yellow, width: 3)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.flag_outlined,
                  size: 16, color: DS.yellow),
              const SizedBox(width: 8),
              Text('TRACK EVENTS',
                  style: DS.labelCaps(
                      size: 7, color: DS.yellow)),
            ]),
            const SizedBox(height: 8),
            ...events.take(12).map((e) {
              final type = e['type']?.toString() ?? '';
              final lap = e['lap'];
              final label =
                  e['label']?.toString() ?? type;
              final evColor = type == 'SAFETY_CAR'
                  ? DS.orange
                  : type == 'RED_FLAG'
                      ? DS.red
                      : type == 'PENALTY'
                          ? DS.yellow
                          : DS.textMuted;
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  if (lap != null)
                    SizedBox(
                        width: 40,
                        child: Text('L$lap',
                            style: DS.labelCaps(
                                size: 8,
                                color: DS.textMuted))),
                  Expanded(
                      child: Text(label,
                          style: DS.body(
                              size: 11,
                              color: evColor))),
                ]),
              );
            }),
          ]),
    );
  }
}

class _RetirementsCard extends StatelessWidget {
  final List<Map> retirements;
  const _RetirementsCard(
      {super.key, required this.retirements});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DS.surface1,
        borderRadius: DS.aeroCornerSm,
        border: Border(
            left: BorderSide(
                color: DS.red.withValues(alpha: 0.6),
                width: 3)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.cancel_outlined,
                  size: 16, color: DS.red),
              const SizedBox(width: 8),
              Text('RETIREMENTS',
                  style: DS.labelCaps(
                      size: 7, color: DS.red)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: retirements.map((r) {
                final drivers = (r['drivers'] as List?)
                        ?.join(', ') ??
                    '';
                final lap = r['lap'];
                return Text(
                    '$drivers${lap != null ? " L$lap" : ""}',
                    style: DS.body(
                        size: 11, color: DS.textMuted));
              }).toList(),
            ),
          ]),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final Map weather;
  const _WeatherCard(
      {super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final at = weather['air_temp'];
    final tt = weather['track_temp'];
    final hum = weather['humidity'];
    final rain = weather['rainfall'];
    if (at != null) parts.add('Air ${at}°C');
    if (tt != null) parts.add('Track ${tt}°C');
    if (hum != null) parts.add('${hum}% humidity');
    if (rain == true) parts.add('Rain');
    if (parts.isEmpty) return const SizedBox.shrink();
    return _SummaryCard(
      key: const Key('summary_weather'),
      icon: Icons.wb_sunny_outlined,
      color: DS.teal,
      title: 'WEATHER',
      content: parts.join(' · '),
    );
  }
}
