import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../sessions/data/sessions_provider.dart';

// ── Data model ─────────────────────────────────────────────────────────────

class PracticeEntry {
  final String code;
  final String team;
  final String color; // hex without #
  final double bestLapS;
  final double gapS;
  final double? s1, s2, s3;
  final String compound;
  final int lapsCompleted;
  final bool isOverallFastest;

  const PracticeEntry({
    required this.code,
    required this.team,
    required this.color,
    required this.bestLapS,
    required this.gapS,
    this.s1,
    this.s2,
    this.s3,
    required this.compound,
    required this.lapsCompleted,
    required this.isOverallFastest,
  });

  String get bestLapFormatted {
    final m = bestLapS ~/ 60;
    final s = bestLapS - m * 60;
    return '$m:${s.toStringAsFixed(3).padLeft(6, '0')}';
  }

  String get gapFormatted =>
      gapS == 0.0 ? 'LEADER' : '+${gapS.toStringAsFixed(3)}s';

  PracticeEntry copyWith({double? gapS, bool? isOverallFastest}) => PracticeEntry(
        code: code,
        team: team,
        color: color,
        bestLapS: bestLapS,
        gapS: gapS ?? this.gapS,
        s1: s1,
        s2: s2,
        s3: s3,
        compound: compound,
        lapsCompleted: lapsCompleted,
        isOverallFastest: isOverallFastest ?? this.isOverallFastest,
      );
}

// ── Screen ─────────────────────────────────────────────────────────────────

class PracticeReplayScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const PracticeReplayScreen({super.key, required this.sessionId});

  @override
  ConsumerState<PracticeReplayScreen> createState() =>
      _PracticeReplayScreenState();
}

class _PracticeReplayScreenState extends ConsumerState<PracticeReplayScreen> {
  List<Map<String, dynamic>> _timeline = [];
  double _sessionDurationS = 3600;
  double _currentSessionTimeS = 0;
  int _currentTimelineIndex = 0;
  bool _isPlaying = false;
  int _speed = 10;
  final Map<String, PracticeEntry> _driverBests = {};
  // Tracks which drivers just improved (for the green pulse)
  final Set<String> _justImproved = {};
  // Tracks the best lap time key per driver (for TweenAnimationBuilder key)
  final Map<String, double> _lastBestLap = {};
  Timer? _playTimer;
  String _sessionName = '';
  bool _initialized = false;

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  void _initFromData(Map<String, dynamic> data) {
    if (_initialized) return;
    _initialized = true;
    final laps = (data['laps'] as Map<String, dynamic>?) ?? {};
    _sessionDurationS =
        (laps['session_duration_s'] as num?)?.toDouble() ?? 3600;
    _timeline = List<Map<String, dynamic>>.from(
        (laps['timeline'] as List?) ?? []);
    _sessionName = data['session_type']?.toString() ?? 'Practice';
    _currentTimelineIndex = 0;
    _currentSessionTimeS = 0;
    _driverBests.clear();
  }

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
    final tickMs = (200 ~/ _speed).clamp(10, 200);
    _playTimer = Timer.periodic(Duration(milliseconds: tickMs), (_) {
      if (!mounted) return;
      final advance = _speed.toDouble() * (tickMs / 1000.0);
      _currentSessionTimeS =
          (_currentSessionTimeS + advance).clamp(0, _sessionDurationS);

      while (_currentTimelineIndex < _timeline.length) {
        final entry = _timeline[_currentTimelineIndex];
        final entryTime =
            (entry['session_time_s'] as num?)?.toDouble() ?? 0;
        if (entryTime > _currentSessionTimeS) break;
        _applyTimelineEntry(entry);
        _currentTimelineIndex++;
      }

      if (_currentSessionTimeS >= _sessionDurationS) {
        _playTimer?.cancel();
        setState(() => _isPlaying = false);
      } else {
        setState(() {});
      }
    });
  }

  void _applyTimelineEntry(Map<String, dynamic> entry) {
    final code = entry['code']?.toString() ?? '';
    if (code.isEmpty) return;
    final lapTimeS = (entry['lap_time_s'] as num?)?.toDouble() ?? 0;
    _driverBests[code] = PracticeEntry(
      code: code,
      team: entry['team']?.toString() ?? '',
      color: entry['color']?.toString() ?? 'FFFFFF',
      bestLapS: lapTimeS,
      gapS: (entry['gap_s'] as num?)?.toDouble() ?? 0,
      s1: (entry['s1'] as num?)?.toDouble(),
      s2: (entry['s2'] as num?)?.toDouble(),
      s3: (entry['s3'] as num?)?.toDouble(),
      compound: entry['compound']?.toString() ?? 'UNKNOWN',
      lapsCompleted: (entry['laps_completed'] as num?)?.toInt() ?? 0,
      isOverallFastest: entry['is_overall_fastest'] == true,
    );
    _justImproved.add(code);
    _lastBestLap[code] = lapTimeS;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _justImproved.remove(code));
    });
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

  List<PracticeEntry> get _sortedEntries {
    final entries = _driverBests.values.toList();
    entries.sort((a, b) => a.bestLapS.compareTo(b.bestLapS));
    if (entries.isNotEmpty) {
      final leader = entries.first.bestLapS;
      return entries.map((e) => e.copyWith(gapS: e.bestLapS - leader)).toList();
    }
    return entries;
  }

  String get _clockDisplay {
    final remaining =
        (_sessionDurationS - _currentSessionTimeS).clamp(0, _sessionDurationS);
    final m = (remaining ~/ 60).toStringAsFixed(0).padLeft(2, '0');
    final s = (remaining % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  void _scrubTo(double v) {
    _playTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentSessionTimeS = v;
      _currentTimelineIndex = 0;
      _driverBests.clear();
      _justImproved.clear();
      _lastBestLap.clear();
      for (int i = 0; i < _timeline.length; i++) {
        final t =
            (_timeline[i]['session_time_s'] as num?)?.toDouble() ?? 0;
        if (t <= v) {
          _applyTimelineEntry(_timeline[i]);
          _currentTimelineIndex = i + 1;
        } else {
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(sessionDataProvider(widget.sessionId));

    return dataAsync.when(
      loading: () => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'PRACTICE REPLAY'),
        body: const SkeletonStandingsList(count: 10),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(subtitle: 'PRACTICE REPLAY'),
        body: ErrorRetryWidget(
          message: 'Could not load session.',
          icon: Icons.timer_outlined,
          onRetry: () => ref.invalidate(sessionDataProvider(widget.sessionId)),
        ),
      ),
      data: (data) {
        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _initFromData(data));
          });
        }

        final sorted = _sortedEntries;

        return Scaffold(
          backgroundColor: DS.bg,
          appBar: DSAppBar(
            subtitle:
                '$_sessionName // ${(data['event'] as String? ?? '').replaceAll('_', ' ')}',
          ),
          body: Column(
            children: [
              // Header: session clock
              Container(
                color: DS.surface0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Icon(Icons.timer_outlined, size: 14, color: DS.teal),
                  const SizedBox(width: 6),
                  Text(_clockDisplay,
                      style: DS.telemetryLg(size: 20, color: DS.teal)),
                  const Spacer(),
                  DSWidgets.statusChip('BEST LAP ORDER',
                      color: DS.textMuted, size: 7),
                ]),
              ),
              // Column headers
              Container(
                color: DS.surface0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  SizedBox(
                      width: 28,
                      child: Text('P',
                          style: DS.labelCaps(size: 7, color: DS.textMuted))),
                  SizedBox(
                      width: 40,
                      child: Text('CODE',
                          style: DS.labelCaps(size: 7, color: DS.textMuted))),
                  Expanded(
                      child: Text('BEST LAP',
                          style: DS.labelCaps(size: 7, color: DS.textMuted))),
                  SizedBox(
                      width: 80,
                      child: Text('GAP',
                          textAlign: TextAlign.right,
                          style: DS.labelCaps(size: 7, color: DS.textMuted))),
                  SizedBox(
                      width: 48,
                      child: Text('LAPS',
                          textAlign: TextAlign.center,
                          style: DS.labelCaps(size: 7, color: DS.textMuted))),
                ]),
              ),
              // Timing table
              Expanded(
                child: sorted.isEmpty
                    ? Center(
                        child: Text('WAITING FOR TIMING DATA',
                            style: DS.labelCaps(
                                size: 10, color: DS.textMuted)))
                    : SingleChildScrollView(
                        child: SizedBox(
                          height: sorted.length * 52.0,
                          child: Stack(
                            children: sorted.asMap().entries.map((e) {
                              final index = e.key;
                              final entry = e.value;
                              final colorVal = int.tryParse(
                                      'FF${entry.color}',
                                      radix: 16) ??
                                  0xFFFFFFFF;
                              final teamColor = Color(colorVal);
                              final isImproving =
                                  _justImproved.contains(entry.code);
                              final lapKey =
                                  _lastBestLap[entry.code] ?? 0.0;

                              return AnimatedPositioned(
                                key: ValueKey(entry.code),
                                duration:
                                    const Duration(milliseconds: 600),
                                curve: Curves.easeOutBack,
                                top: index * 52.0,
                                left: 0,
                                right: 0,
                                height: 52.0,
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                      '${entry.code}_$lapKey'),
                                  tween: isImproving
                                      ? Tween<double>(
                                          begin: 0.35, end: 0.0)
                                      : Tween<double>(
                                          begin: 0.0, end: 0.0),
                                  duration: const Duration(
                                      milliseconds: 1500),
                                  curve: Curves.easeOut,
                                  builder: (ctx, pulse, child) =>
                                      Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 12),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: pulse > 0.01
                                          ? DS.green
                                              .withValues(alpha: pulse)
                                          : DS.surface1,
                                      borderRadius: DS.aeroCornerSm,
                                      border: Border(
                                          left: BorderSide(
                                              color: entry
                                                      .isOverallFastest
                                                  ? DS.purple
                                                  : teamColor,
                                              width: 3)),
                                    ),
                                    child: child,
                                  ),
                                  child: Row(children: [
                                    SizedBox(
                                        width: 28,
                                        child: Text('P${index + 1}',
                                            style: DS.telemetry(
                                                size: 11,
                                                color:
                                                    DS.textPrimary))),
                                    SizedBox(
                                        width: 40,
                                        child: Text(entry.code,
                                            style: DS.driverCode(
                                                size: 12,
                                                color: entry
                                                        .isOverallFastest
                                                    ? DS.purple
                                                    : DS.textPrimary))),
                                    Expanded(
                                        child: Text(
                                            entry.bestLapFormatted,
                                            style: DS.telemetry(
                                                size: 12,
                                                color: entry
                                                        .isOverallFastest
                                                    ? DS.purple
                                                    : DS.textPrimary))),
                                    SizedBox(
                                        width: 80,
                                        child: Text(entry.gapFormatted,
                                            textAlign: TextAlign.right,
                                            style: DS.telemetry(
                                                size: 10,
                                                color: DS.textMuted))),
                                    SizedBox(
                                        width: 48,
                                        child: Text(
                                            '${entry.lapsCompleted}',
                                            textAlign: TextAlign.center,
                                            style: DS.telemetry(
                                                size: 10,
                                                color: DS.textMuted))),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
              // Scrubber + controls
              Container(
                color: DS.surface0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(children: [
                  Row(children: [
                    Text(
                        '${(_currentSessionTimeS / 60).floor()}:'
                        '${(_currentSessionTimeS % 60).toStringAsFixed(0).padLeft(2, '0')}',
                        style: DS.telemetry(size: 10, color: DS.teal)),
                    Expanded(
                      child: Slider(
                        value: _currentSessionTimeS,
                        min: 0,
                        max: _sessionDurationS > 0 ? _sessionDurationS : 1,
                        onChanged: _scrubTo,
                      ),
                    ),
                    Text(_clockDisplay,
                        style:
                            DS.telemetry(size: 10, color: DS.textMuted)),
                  ]),
                  Row(children: [
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: DS.teal, shape: BoxShape.circle),
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
                    Text('PRACTICE REPLAY',
                        style:
                            DS.labelCaps(size: 8, color: DS.textMuted)),
                  ]),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
