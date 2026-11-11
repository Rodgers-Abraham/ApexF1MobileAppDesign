import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../sessions/data/sessions_provider.dart';

// ── Data model ─────────────────────────────────────────────────────────────

class _QualEntry {
  final String code, team, color, compound;
  final double bestLapS;
  final double? s1, s2, s3;
  final bool isOverallFastest;

  const _QualEntry({
    required this.code,
    required this.team,
    required this.color,
    required this.bestLapS,
    this.s1,
    this.s2,
    this.s3,
    required this.compound,
    required this.isOverallFastest,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────

class QualifyingReplayScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const QualifyingReplayScreen({super.key, required this.sessionId});

  @override
  ConsumerState<QualifyingReplayScreen> createState() =>
      _QualifyingReplayScreenState();
}

class _QualifyingReplayScreenState
    extends ConsumerState<QualifyingReplayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<String> _segments = [];
  Map<String, dynamic> _segmentsData = {};
  Map<String, List<Map<String, dynamic>>> _segmentTimelines = {};
  Map<String, List<String>> _eliminated = {};
  Map<String, dynamic>? _pole;
  List<Map<String, dynamic>> _finalGrid = [];

  final Map<String, int> _timelineIdx = {};
  final Map<String, double> _sessionTimeS = {};
  final Map<String, Map<String, _QualEntry>> _driverBests = {};
  bool _isPlaying = false;
  int _speed = 1;
  Timer? _playTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _playTimer?.cancel();
    super.dispose();
  }

  void _initFromData(Map<String, dynamic> data) {
    if (_initialized) return;
    _initialized = true;

    final laps = (data['laps'] as Map<String, dynamic>?) ?? {};
    _segments = List<String>.from(
        (laps['segment_order'] as List?) ?? ['Q1', 'Q2', 'Q3']);
    final segs = (laps['segments'] as Map<String, dynamic>?) ?? {};
    _segmentsData = segs;
    _pole = laps['pole'] as Map<String, dynamic>?;
    _finalGrid =
        List<Map<String, dynamic>>.from((laps['final_grid'] as List?) ?? []);

    for (final seg in _segments) {
      final segData = (segs[seg] as Map<String, dynamic>?) ?? {};
      _segmentTimelines[seg] = List<Map<String, dynamic>>.from(
          (segData['timeline'] as List?) ?? []);
      _eliminated[seg] =
          List<String>.from((segData['eliminated'] as List?) ?? []);
      _timelineIdx[seg] = 0;
      _sessionTimeS[seg] = 0;
      _driverBests[seg] = {};
    }

    _tabCtrl.dispose();
    _tabCtrl = TabController(length: _segments.length, vsync: this);
  }

  String get _activeSeg =>
      _segments.isNotEmpty ? _segments[_tabCtrl.index] : 'Q1';

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _startTimer();
    } else {
      _playTimer?.cancel();
    }
  }

  void _startTimer() {
    _playTimer?.cancel();
    const tickMs = 200;
    _playTimer = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
      if (!mounted) return;
      final seg = _activeSeg;
      final advance = _speed.toDouble() * (tickMs / 1000.0);
      final tl = _segmentTimelines[seg] ?? [];
      final maxT = tl.isNotEmpty
          ? (tl.last['session_time_s'] as num?)?.toDouble() ?? 1200.0
          : 1200.0;
      _sessionTimeS[seg] =
          ((_sessionTimeS[seg] ?? 0) + advance).clamp(0, maxT);

      var newIdx = _timelineIdx[seg] ?? 0;
      while (newIdx < tl.length) {
        final t = (tl[newIdx]['session_time_s'] as num?)?.toDouble() ?? 0;
        if (t > (_sessionTimeS[seg] ?? 0)) break;
        _applyEntry(seg, tl[newIdx]);
        newIdx++;
      }
      _timelineIdx[seg] = newIdx;

      if ((_sessionTimeS[seg] ?? 0) >= maxT) {
        _playTimer?.cancel();
        setState(() => _isPlaying = false);
        if (_tabCtrl.index < _segments.length - 1) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) setState(() => _tabCtrl.index++);
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  void _applyEntry(String seg, Map<String, dynamic> entry) {
    final code = entry['code']?.toString() ?? '';
    if (code.isEmpty) return;
    _driverBests[seg]![code] = _QualEntry(
      code: code,
      team: entry['team']?.toString() ?? '',
      color: entry['color']?.toString() ?? 'FFFFFF',
      bestLapS: (entry['lap_time_s'] as num?)?.toDouble() ?? 0,
      s1: (entry['s1'] as num?)?.toDouble(),
      s2: (entry['s2'] as num?)?.toDouble(),
      s3: (entry['s3'] as num?)?.toDouble(),
      compound: entry['compound']?.toString() ?? 'UNKNOWN',
      isOverallFastest: entry['is_overall_fastest'] == true,
    );
  }

  void _cycleSpeed() {
    const speeds = [1, 5, 10, 30];
    final idx = speeds.indexOf(_speed);
    setState(() {
      _speed = speeds[(idx + 1) % speeds.length];
      if (_isPlaying) {
        _playTimer?.cancel();
        _startTimer();
      }
    });
  }

  String _fmtLap(double s) {
    final m = s ~/ 60;
    final rem = s - m * 60;
    return '$m:${rem.toStringAsFixed(3).padLeft(6, '0')}';
  }

  Widget _buildQualRow(_QualEntry entry, int pos, double gap, Color teamColor,
      bool inDropZone, bool isElim) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: inDropZone
            ? DS.red.withValues(alpha: 0.08)
            : (isElim ? DS.surface0 : DS.surface1),
        borderRadius: DS.aeroCornerSm,
        border: Border(
            left: BorderSide(
                color: inDropZone
                    ? DS.red
                    : (entry.isOverallFastest ? DS.purple : teamColor),
                width: 3)),
      ),
      child: Row(children: [
        SizedBox(
            width: 28,
            child: Text('P${pos + 1}',
                style: DS.telemetry(
                    size: 11,
                    color: isElim ? DS.textMuted : DS.textPrimary))),
        SizedBox(
            width: 40,
            child: Text(entry.code,
                style: DS.driverCode(
                    size: 12,
                    color: entry.isOverallFastest
                        ? DS.purple
                        : (isElim ? DS.textMuted : DS.textPrimary)))),
        Expanded(
            child: Text(_fmtLap(entry.bestLapS),
                style: DS.telemetry(
                    size: 12,
                    color: entry.isOverallFastest
                        ? DS.purple
                        : (isElim ? DS.textMuted : DS.textPrimary)))),
        if (gap > 0.001)
          Text('+${gap.toStringAsFixed(3)}s',
              style: DS.telemetry(size: 10, color: DS.textMuted))
        else
          Text('LEADER',
              style: DS.labelCaps(size: 8, color: DS.teal)),
        const SizedBox(width: 8),
        if (isElim) DSWidgets.statusChip('OUT', color: DS.red, size: 7),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(sessionDataProvider(widget.sessionId));

    return dataAsync.when(
      loading: () => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'QUALIFYING REPLAY'),
        body: const SkeletonStandingsList(count: 10),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'QUALIFYING REPLAY'),
        body: ErrorRetryWidget(
          message: 'Could not load session.',
          icon: Icons.timer_outlined,
          onRetry: () =>
              ref.invalidate(sessionDataProvider(widget.sessionId)),
        ),
      ),
      data: (data) {
        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _initFromData(data));
          });
          return Scaffold(
            backgroundColor: DS.bg,
            appBar: DSAppBar(subtitle: 'QUALIFYING REPLAY'),
            body: const SkeletonStandingsList(count: 10),
          );
        }

        final eventName =
            (data['event'] as String? ?? '').replaceAll('_', ' ');
        final seg = _activeSeg;
        final segBests = _driverBests[seg] ?? {};
        final eliminated = _eliminated[seg] ?? [];
        final segData =
            (_segmentsData[seg] as Map<String, dynamic>?) ?? {};
        final nextSegDriverCount = seg != _segments.last
            ? ((_segmentsData[_segments[_segments.indexOf(seg) + 1]]
                    as Map?)?['driver_count'] as num?)
                ?.toInt() ??
                0
            : 0;

        final activeBests = segBests.values.toList()
          ..sort((a, b) => a.bestLapS.compareTo(b.bestLapS));
        final leaderLap =
            activeBests.isNotEmpty ? activeBests.first.bestLapS : 0.0;
        final cutLine =
            nextSegDriverCount > 0 ? nextSegDriverCount : activeBests.length;

        return Scaffold(
          backgroundColor: DS.bg,
          appBar: PreferredSize(
            preferredSize:
                const Size.fromHeight(kToolbarHeight + 48),
            child: Column(children: [
              DSAppBar(subtitle: 'QUALIFYING // $eventName'),
              Container(
                color: DS.surface0,
                child: TabBar(
                  controller: _tabCtrl,
                  tabs: _segments.map((s) => Tab(text: s)).toList(),
                  indicator: BoxDecoration(
                      color: DS.textPrimary,
                      borderRadius: DS.aeroCornerSm),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: DS.bg,
                  unselectedLabelColor: DS.textMuted,
                  dividerColor: Colors.transparent,
                  labelStyle: DS.driverCode(size: 11),
                ),
              ),
            ]),
          ),
          body: Column(children: [
            Expanded(
              child: activeBests.isEmpty
                  ? Center(
                      child: Text('WAITING FOR TIMING DATA',
                          style: DS.labelCaps(
                              size: 10, color: DS.textMuted)))
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      itemCount: activeBests.length,
                      itemBuilder: (ctx, i) {
                        final entry = activeBests[i];
                        final gap = entry.bestLapS - leaderLap;
                        final colorVal = int.tryParse(
                                'FF${entry.color}',
                                radix: 16) ??
                            0xFFFFFFFF;
                        final teamColor = Color(colorVal);
                        final inDropZone =
                            nextSegDriverCount > 0 && i >= cutLine;
                        final isElim =
                            eliminated.contains(entry.code);

                        if (nextSegDriverCount > 0 &&
                            i == cutLine &&
                            !isElim) {
                          return Column(children: [
                            Container(
                                height: 2,
                                color: DS.red,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 2)),
                            _buildQualRow(entry, i, gap, teamColor,
                                inDropZone, isElim),
                          ]);
                        }
                        return _buildQualRow(
                            entry, i, gap, teamColor, inDropZone, isElim);
                      },
                    ),
            ),
            Container(
              color: DS.surface0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(children: [
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: DS.orange, shape: BoxShape.circle),
                    child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: DS.surface2,
                        borderRadius: DS.aeroCornerSm,
                        border: Border.all(color: DS.outline)),
                    child: Text('${_speed}×',
                        style: DS.labelCaps(
                            size: 10, color: DS.textPrimary)),
                  ),
                ),
                const Spacer(),
                if (_pole != null)
                  DSWidgets.statusChip(
                      'POLE: ${_pole!['code']}',
                      color: DS.purple,
                      size: 8),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
