import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session_provider.dart';
import 'models.dart';

final liveDriverStandingsProvider = FutureProvider.autoDispose<List<DriverStandingJolpica>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/live-standings/drivers');
  final list = response.data as List;
  return list.map((i) => DriverStandingJolpica.fromJson(i as Map<String, dynamic>)).toList();
});

final liveConstructorStandingsProvider = FutureProvider.autoDispose<List<ConstructorStandingJolpica>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/live-standings/constructors');
  final list = response.data as List;
  return list.map((i) => ConstructorStandingJolpica.fromJson(i as Map<String, dynamic>)).toList();
});

class TelemetryNotifier extends StateNotifier<AsyncValue<List<LiveTelemetry>>> {
  final Ref _ref;
  Timer? _timer;
  int _retryCount = 0;
  static const int _maxRetry = 5;
  static const Duration _baseRefresh = Duration(seconds: 2);

  TelemetryNotifier(this._ref) : super(const AsyncValue.loading()) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/telemetry/live');
      final list = response.data as List;
      final data = list.map((i) => LiveTelemetry.fromJson(i as Map<String, dynamic>)).toList();
      if (mounted) {
        state = AsyncValue.data(data);
        _retryCount = 0;
      }
      _scheduleNext(_baseRefresh);
    } catch (e, stack) {
      debugPrint('Telemetry fetch notice: $e');
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
      _retryCount++;
      if (_retryCount <= _maxRetry) {
        final backoff = Duration(seconds: 2 * _retryCount);
        _scheduleNext(backoff);
      } else {
        _scheduleNext(const Duration(seconds: 10));
      }
    }
  }

  void _scheduleNext(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _fetch);
  }

  void refresh() {
    _retryCount = 0;
    _timer?.cancel();
    _fetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final liveTelemetryFeedProvider = StateNotifierProvider.autoDispose<TelemetryNotifier, AsyncValue<List<LiveTelemetry>>>((ref) {
  return TelemetryNotifier(ref);
});

class RaceFlagStatusNotifier extends StateNotifier<AsyncValue<RaceFlagStatus>> {
  final Ref _ref;
  Timer? _timer;

  RaceFlagStatusNotifier(this._ref) : super(const AsyncValue.loading()) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/race-control/status');
      final data = RaceFlagStatus.fromJson(response.data as Map<String, dynamic>);
      if (mounted) {
        state = AsyncValue.data(data);
      }
    } catch (e, stack) {
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    } finally {
      if (mounted) {
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 3), _fetch);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final raceFlagStatusProvider = StateNotifierProvider.autoDispose<RaceFlagStatusNotifier, AsyncValue<RaceFlagStatus>>((ref) {
  return RaceFlagStatusNotifier(ref);
});

class ReplayLapEntry {
  final int lap;
  final String phase; // e.g. "Q1", "Q2", "Q3", or "" for race laps
  final List<LiveTelemetry> positions;

  const ReplayLapEntry({required this.lap, required this.phase, required this.positions});
}

class DriverReplaySummary {
  final String driverName;
  final String driverCode;
  final String team;
  final int finalPosition;
  final String fastestLap;
  final int fastestLapNum;

  const DriverReplaySummary({
    required this.driverName,
    required this.driverCode,
    required this.team,
    required this.finalPosition,
    required this.fastestLap,
    required this.fastestLapNum,
  });
}

class RaceReplayState {
  final String meetingName;
  final String circuitName;
  final String sessionType; // 'race' | 'qualifying' | 'sprint'
  final int currentLap;
  final int totalLaps;
  final bool isPlaying;
  final bool isLoading;
  final String? loadError;
  final List<LiveTelemetry> telemetry;
  final RaceFlagStatus flagStatus;
  final List<ReplayLapEntry> allLaps;
  final List<LiveTelemetry> finalClassification;
  final String? focusedDriverName;
  final int speedMultiplier; // 1 | 2 | 4
  final List<int> incidentLaps; // laps with 3+ position changes
  final bool showingGrid; // show starting grid before playback
  final List<RaceControlEvent> raceControlEvents;
  final Map<int, List<RaceControlEvent>> lapEventMap;
  final RaceSummary? raceSummary;

  const RaceReplayState({
    this.meetingName = '',
    this.circuitName = '',
    this.sessionType = 'race',
    this.currentLap = 0,
    this.totalLaps = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.loadError,
    this.telemetry = const [],
    this.flagStatus = RaceFlagStatus.defaultStatus,
    this.allLaps = const [],
    this.finalClassification = const [],
    this.focusedDriverName,
    this.speedMultiplier = 1,
    this.incidentLaps = const [],
    this.showingGrid = false,
    this.raceControlEvents = const [],
    this.lapEventMap = const {},
    this.raceSummary,
  });

  RaceReplayState copyWith({
    String? meetingName,
    String? circuitName,
    String? sessionType,
    int? currentLap,
    int? totalLaps,
    bool? isPlaying,
    bool? isLoading,
    String? loadError,
    List<LiveTelemetry>? telemetry,
    RaceFlagStatus? flagStatus,
    List<ReplayLapEntry>? allLaps,
    List<LiveTelemetry>? finalClassification,
    String? focusedDriverName,
    bool clearFocusedDriver = false,
    int? speedMultiplier,
    List<int>? incidentLaps,
    bool? showingGrid,
    List<RaceControlEvent>? raceControlEvents,
    Map<int, List<RaceControlEvent>>? lapEventMap,
    RaceSummary? raceSummary,
    bool clearRaceSummary = false,
  }) {
    return RaceReplayState(
      meetingName: meetingName ?? this.meetingName,
      circuitName: circuitName ?? this.circuitName,
      sessionType: sessionType ?? this.sessionType,
      currentLap: currentLap ?? this.currentLap,
      totalLaps: totalLaps ?? this.totalLaps,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      loadError: loadError,
      telemetry: telemetry ?? this.telemetry,
      flagStatus: flagStatus ?? this.flagStatus,
      allLaps: allLaps ?? this.allLaps,
      finalClassification: finalClassification ?? this.finalClassification,
      focusedDriverName: clearFocusedDriver ? null : (focusedDriverName ?? this.focusedDriverName),
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      incidentLaps: incidentLaps ?? this.incidentLaps,
      showingGrid: showingGrid ?? this.showingGrid,
      raceControlEvents: raceControlEvents ?? this.raceControlEvents,
      lapEventMap: lapEventMap ?? this.lapEventMap,
      raceSummary: clearRaceSummary ? null : (raceSummary ?? this.raceSummary));
  }

  String get lapLabel {
    if (allLaps.isEmpty) return 'LAP $currentLap';
    final entry = allLaps.firstWhere((l) => l.lap == currentLap, orElse: () => allLaps.first);
    return entry.phase.isNotEmpty ? entry.phase : 'LAP $currentLap';
  }

  bool get isAtEnd => totalLaps > 0 && currentLap >= totalLaps;

  /// Events for the current lap from OpenF1 (empty for pre-2023 races)
  List<RaceControlEvent> get currentLapEvents =>
      lapEventMap[currentLap] ?? const [];

  /// Whether the current lap has a notable flag event
  bool get currentLapHasFlag => currentLapEvents.any((e) => e.isNotable);

  /// All laps that have notable events (SC/VSC/red flag) for scrubber markers
  List<int> get flagEventLaps => lapEventMap.keys
      .where((lap) => lapEventMap[lap]!.any((e) => e.isNotable))
      .toList();

  /// Compute a summary for the focused driver. Uses final_classification for
  /// correct finish position regardless of how many laps were loaded.
  DriverReplaySummary? get focusedDriverSummary {
    if (focusedDriverName == null || allLaps.isEmpty) return null;
    final hint = focusedDriverName!.toLowerCase();

    bool _matches(String name) =>
        name.toLowerCase().contains(hint) || hint.contains(name.toLowerCase());

    // Final position: prefer final_classification (from race results)
    LiveTelemetry? finalEntry = finalClassification.where((d) => _matches(d.name)).firstOrNull;

    // Fallback: use last available lap timing
    if (finalEntry == null) {
      final lastEntry = allLaps.lastWhere((l) => l.lap > 0 && l.positions.isNotEmpty, orElse: () => allLaps.last);
      finalEntry = lastEntry.positions.where((d) => _matches(d.name)).firstOrNull;
    }
    if (finalEntry == null) return null;

    // Fastest lap: scan all timing laps
    String fastest = finalEntry.lastLap; // Jolpica puts FL in lap_time for the results entry
    int fastestLapNum = 0;
    double fastestSecs = double.infinity;
    for (final lap in allLaps) {
      if (lap.lap == 0) continue;
      final driver = lap.positions.where((d) => _matches(d.name)).firstOrNull;
      if (driver == null) continue;
      final t = driver.lastLap;
      if (t.isNotEmpty && t.contains(':')) {
        try {
          final parts = t.split(':');
          final secs = double.parse(parts[0]) * 60 + double.parse(parts[1]);
          if (secs > 10 && secs < fastestSecs) {
            fastestSecs = secs;
            fastest = t;
            fastestLapNum = lap.lap;
          }
        } catch (_) {}
      }
    }

    return DriverReplaySummary(
      driverName: finalEntry.name,
      driverCode: finalEntry.name.length >= 3
          ? finalEntry.name.substring(finalEntry.name.length - 3).toUpperCase()
          : finalEntry.name.toUpperCase(),
      team: finalEntry.team,
      finalPosition: int.tryParse(finalEntry.pos) ?? 0,
      fastestLap: fastest,
      fastestLapNum: fastestLapNum);
  }
}

class RaceReplayNotifier extends StateNotifier<RaceReplayState> {
  final Ref _ref;
  Timer? _playTimer;

  RaceReplayNotifier(this._ref) : super(const RaceReplayState());

  Future<void> selectSession({
    required int year,
    required int round,
    required String meetingName,
    required String sessionType,
  }) async {
    _playTimer?.cancel();
    state = state.copyWith(
      meetingName: meetingName,
      sessionType: sessionType,
      currentLap: 1,
      isPlaying: false,
      isLoading: true,
      loadError: null,
      allLaps: [],
      telemetry: []);

    try {
      final client = _ref.read(apiClientProvider);
      final encodedName = Uri.encodeComponent(meetingName);
      final resp = await client.get('/api/f1/replay/$year/$round/$sessionType?race_name=$encodedName');
      final data = resp.data as Map<String, dynamic>;
      final rawLaps = (data['laps'] as List?) ?? [];
      final totalLaps = (data['total_laps'] as num?)?.toInt() ?? rawLaps.length;

      final entries = rawLaps.map((lapRaw) {
        final lap = lapRaw as Map<String, dynamic>;
        final lapNum = (lap['lap'] as num?)?.toInt() ?? 0;
        final phase = lap['phase']?.toString() ?? '';
        final rawPositions = (lap['positions'] as List?) ?? [];
        final positions = rawPositions.map((p) {
          final pos = p as Map<String, dynamic>;
          return _posToTelemetry(pos);
        }).toList();
        return ReplayLapEntry(lap: lapNum, phase: phase, positions: positions);
      }).toList();

      // Parse final classification (race results — always correct)
      final rawFinal = (data['final_classification'] as List?) ?? [];
      final finalClassif = rawFinal.map((p) => _posToTelemetry(p as Map<String, dynamic>)).toList();

      // Parse race control events from OpenF1 (empty for pre-2023/non-race)
      final rawEvents = (data['race_control_events'] as List?) ?? [];
      final rcEvents = rawEvents
          .map((e) => RaceControlEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      final lapEvtMap = <int, List<RaceControlEvent>>{};
      for (final e in rcEvents) {
        lapEvtMap.putIfAbsent(e.lap, () => []).add(e);
      }
      final flagLaps = lapEvtMap.keys
          .where((l) => lapEvtMap[l]!.any((e) => e.isNotable))
          .toSet();

      // Parse race summary
      RaceSummary? raceSummary;
      final rawSummary = data['race_summary'] as Map<String, dynamic>?;
      if (rawSummary != null) {
        raceSummary = RaceSummary.fromJson(rawSummary);
      }

      if (mounted) {
        // Show grid (lap 0) first; compute incident laps for ⚡ skip button
        final gridEntry = entries.firstWhere((e) => e.lap == 0, orElse: () => entries.first);
        final incidents = _computeIncidentLaps(entries);
        state = state.copyWith(
          meetingName: data['race_name']?.toString() ?? meetingName,
          circuitName: data['circuit']?.toString() ?? '',
          sessionType: data['session_type']?.toString() ?? sessionType,
          totalLaps: totalLaps,
          currentLap: 0,
          allLaps: entries,
          finalClassification: finalClassif,
          isLoading: false,
          showingGrid: true,
          incidentLaps: ({...incidents, ...flagLaps}.toList()..sort()),
          raceControlEvents: rcEvents,
          lapEventMap: lapEvtMap,
          raceSummary: raceSummary,
          telemetry: gridEntry.positions);
      }
    } catch (e) {
      debugPrint('Session replay error: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          loadError: 'Timing data not yet available for this session. Try again later.');
      }
    }
  }

  LiveTelemetry _posToTelemetry(Map<String, dynamic> p) {
    final teamName = p['team']?.toString() ?? '';
    final driverData = _colorForTeam(teamName);
    return LiveTelemetry(
      pos: p['pos']?.toString() ?? '',
      name: p['name']?.toString() ?? '',
      driverNumber: 0,
      team: teamName,
      gap: p['gap']?.toString() ?? '',
      interval: p['interval']?.toString() ?? '',
      positionsGained: 0,
      status: p['status']?.toString() ?? 'RACING',
      dnfReason: '',
      tyre: '',
      tyreLife: '',
      lastLap: p['lap_time']?.toString() ?? '',
      bestLap: '',
      isFastestLap: false,
      pitStops: 0,
      drs: false,
      speed: '',
      gear: '',
      color: driverData,
      x: 0.0,
      y: 0.0);
  }

  /// Load a session from the new TracingInsights-sourced /api/timing/sessions endpoint.
  Future<void> selectSessionById(String sessionId) async {
    _playTimer?.cancel();
    state = state.copyWith(
      meetingName: '',
      isLoading: true,
      isPlaying: false,
      loadError: null,
      allLaps: [],
      telemetry: [],
      showingGrid: false,
    );
    try {
      final client = _ref.read(apiClientProvider);
      final resp = await client.get('/api/timing/sessions/$sessionId/data');
      final data = resp.data as Map<String, dynamic>;

      final rawLapsList = (data['laps'] as Map<String, dynamic>?)?['laps'] as List? ?? [];
      final totalLaps =
          ((data['laps'] as Map?)?['total_laps'] as num?)?.toInt() ?? rawLapsList.length;
      final rawGrid = (data['laps'] as Map<String, dynamic>?)?['grid'] as List? ?? [];

      final entries = rawLapsList.map((lapRaw) {
        final lap = lapRaw as Map<String, dynamic>;
        final lapNum = (lap['lap'] as num?)?.toInt() ?? 0;
        final rawPositions = (lap['positions'] as List?) ?? [];
        final positions =
            rawPositions.map((p) => _posFromTracingInsights(p as Map<String, dynamic>)).toList();
        return ReplayLapEntry(lap: lapNum, phase: '', positions: positions);
      }).toList();

      // Build grid as lap 0
      final gridPositions = rawGrid
          .map((g) => _posFromTracingInsights({
                ...(g as Map<String, dynamic>),
                'lap_time': 'Grid',
                'gap': '',
                'interval': '',
                'status': 'RACING',
              }))
          .toList();
      if (gridPositions.isNotEmpty) {
        entries.insert(0, ReplayLapEntry(lap: 0, phase: 'GRID', positions: gridPositions));
      }

      // Reconstruct race control events from per-lap flags
      final rcEvents = <RaceControlEvent>[];
      for (final lapRaw in rawLapsList) {
        final lap = lapRaw as Map<String, dynamic>;
        final lapNum = (lap['lap'] as num?)?.toInt() ?? 0;
        if (lap['sc_active'] == true) {
          rcEvents.add(RaceControlEvent(
              lap: lapNum,
              category: 'SafetyCar',
              message: 'SAFETY CAR DEPLOYED',
              scope: 'Track'));
        }
        if (lap['vsc_active'] == true) {
          rcEvents.add(RaceControlEvent(
              lap: lapNum,
              category: 'SafetyCar',
              message: 'VIRTUAL SAFETY CAR DEPLOYED',
              scope: 'Track'));
        }
        if (lap['red_flag'] == true) {
          rcEvents.add(RaceControlEvent(
              lap: lapNum,
              category: 'Flag',
              flag: 'RED',
              message: 'RED FLAG',
              scope: 'Track'));
        }
      }

      final lapEvtMap = <int, List<RaceControlEvent>>{};
      for (final e in rcEvents) {
        lapEvtMap.putIfAbsent(e.lap, () => []).add(e);
      }
      final flagLaps =
          lapEvtMap.keys.where((l) => lapEvtMap[l]!.any((e) => e.isNotable)).toSet();

      final incidents = _computeIncidentLaps(entries);

      // Parse final classification from results JSONB
      final rawResults = (data['results'] as List?) ?? [];
      final finalClass = rawResults.map((r) {
        final res = r as Map<String, dynamic>;
        return LiveTelemetry(
          pos: res['pos']?.toString() ?? '',
          name: res['code']?.toString() ?? '',
          driverNumber: 0,
          team: '',
          gap: res['gap']?.toString() ?? '',
          interval: '',
          positionsGained: 0,
          status: res['status']?.toString() ?? 'Finished',
          dnfReason: '',
          tyre: '',
          tyreLife: '',
          lastLap: res['lap_time']?.toString() ?? '',
          bestLap: '',
          isFastestLap: res['fastest_lap'] == true,
          pitStops: 0,
          drs: false,
          speed: '',
          gear: '',
          color: '#FFFFFF',
          x: 0.0,
          y: 0.0,
        );
      }).toList();

      final gridEntry =
          entries.firstWhere((e) => e.lap == 0, orElse: () => entries.first);

      if (mounted) {
        state = state.copyWith(
          meetingName:
              (data['event']?.toString() ?? '').replaceAll('_', ' '),
          circuitName:
              (data['meta'] as Map?)?['circuit']?.toString() ?? '',
          sessionType:
              (data['session_type']?.toString() ?? 'race').toLowerCase(),
          totalLaps: totalLaps,
          currentLap: 0,
          allLaps: entries,
          finalClassification: finalClass,
          raceControlEvents: rcEvents,
          lapEventMap: lapEvtMap,
          incidentLaps: ({...incidents, ...flagLaps}.toList()..sort()),
          isLoading: false,
          showingGrid: true,
          telemetry: gridEntry.positions,
        );
      }
    } catch (e) {
      debugPrint('selectSessionById error: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          loadError: 'Could not load session. Try again.');
      }
    }
  }

  LiveTelemetry _posFromTracingInsights(Map<String, dynamic> p) {
    final posStr = p['pos']?.toString() ?? '';
    // lap_time: float seconds → "M:SS.mmm" string
    final ltRaw = p['lap_time'];
    String lapTimeStr = '';
    if (ltRaw is num && ltRaw > 0) {
      final secs = ltRaw.toDouble();
      final mins = (secs ~/ 60);
      final remaining = secs - mins * 60;
      lapTimeStr = '$mins:${remaining.toStringAsFixed(3).padLeft(6, '0')}';
    } else if (ltRaw is String) {
      lapTimeStr = ltRaw;
    }
    // color: hex without # → store without # (existing tower uses _hexToColor)
    final rawColor = p['color']?.toString() ?? 'FFFFFF';
    final colorNoHash = rawColor.startsWith('#') ? rawColor.substring(1) : rawColor;

    return LiveTelemetry(
      pos: posStr,
      name: p['code']?.toString() ?? '',
      driverNumber: (p['number'] as num?)?.toInt() ?? 0,
      team: p['team']?.toString() ?? '',
      gap: p['gap']?.toString() ?? '',
      interval: p['interval']?.toString() ?? '',
      positionsGained: 0,
      status: p['status']?.toString() ?? 'RACING',
      dnfReason: '',
      tyre: p['compound']?.toString() ?? '',
      tyreLife: p['life']?.toString() ?? '',
      lastLap: lapTimeStr,
      bestLap: '',
      isFastestLap: p['is_fastest_lap_of_race'] == true,
      pitStops: (p['stint'] as num?)?.toInt() ?? 1,
      drs: false,
      speed: '',
      gear: '',
      color: colorNoHash,
      x: 0.0,
      y: 0.0,
    );
  }

  String _colorForTeam(String team) {
    const colors = {
      'Red Bull Racing': '#3671C6',
      'Ferrari': '#E8002D',
      'McLaren': '#FF8000',
      'Mercedes': '#27F4D2',
      'Aston Martin': '#229971',
      'Alpine': '#00A1E8',
      'Williams': '#64C4FF',
      'Racing Bulls': '#6692FF',
      'Haas': '#B6BABD',
      'Audi': '#2B4562',
      'Cadillac': '#FFFFFF',
    };
    return colors[team] ?? '#FFFFFF';
  }

  void setLap(int lap) {
    final clamped = lap.clamp(0, state.totalLaps > 0 ? state.totalLaps : 0);
    if (state.allLaps.isEmpty) return;
    final entry = state.allLaps.firstWhere(
      (l) => l.lap == clamped,
      orElse: () => state.allLaps.reduce((a, b) =>
          (a.lap - clamped).abs() < (b.lap - clamped).abs() ? a : b));
    state = state.copyWith(
      currentLap: clamped,
      telemetry: entry.positions,
      showingGrid: clamped == 0);
  }

  void nextLap() {
    if (state.currentLap < state.totalLaps) {
      setLap(state.currentLap + 1);
    } else {
      pause();
    }
  }

  void prevLap() {
    if (state.currentLap > 0) setLap(state.currentLap - 1);
  }

  void togglePlay() => state.isPlaying ? pause() : play();

  /// Start playback from lap 1, leaving the grid view
  void startReplay() {
    state = state.copyWith(showingGrid: false);
    setLap(1);
    play();
  }

  void play() {
    _playTimer?.cancel();
    state = state.copyWith(isPlaying: true, showingGrid: false);
    final interval = Duration(milliseconds: 2000 ~/ state.speedMultiplier);
    _playTimer = Timer.periodic(interval, (_) {
      if (state.currentLap < state.totalLaps) {
        nextLap();
      } else {
        pause();
      }
    });
  }

  void pause() {
    _playTimer?.cancel();
    state = state.copyWith(isPlaying: false);
  }

  /// Cycle speed: 1x → 2x → 4x → 1x. Restarts timer if playing.
  void cycleSpeed() {
    final next = state.speedMultiplier == 1 ? 2 : state.speedMultiplier == 2 ? 4 : 1;
    state = state.copyWith(speedMultiplier: next);
    if (state.isPlaying) {
      _playTimer?.cancel();
      final interval = Duration(milliseconds: 2000 ~/ next);
      _playTimer = Timer.periodic(interval, (_) {
        if (state.currentLap < state.totalLaps) {
          nextLap();
        } else {
          pause();
        }
      });
    }
  }

  /// Jump to the next incident lap (3+ position change) after current lap.
  void nextIncident() {
    if (state.incidentLaps.isEmpty) return;
    final next = state.incidentLaps.firstWhere(
      (l) => l > state.currentLap,
      orElse: () => state.incidentLaps.first);
    pause();
    setLap(next);
  }

  /// Detect laps where any driver gained/lost 3+ positions at once.
  List<int> _computeIncidentLaps(List<ReplayLapEntry> laps) {
    final incidents = <int>[];
    final prevPos = <String, int>{};
    for (final lap in laps) {
      if (lap.lap == 0) {
        for (final p in lap.positions) {
          final posInt = int.tryParse(p.pos) ?? 0;
          if (posInt > 0) prevPos[p.name] = posInt;
        }
        continue;
      }
      var isIncident = false;
      for (final p in lap.positions) {
        final prev = prevPos[p.name];
        final curr = int.tryParse(p.pos) ?? 0;
        if (prev != null && curr > 0 && (curr - prev).abs() >= 3) {
          isIncident = true;
        }
        if (curr > 0) prevPos[p.name] = curr;
      }
      if (isIncident) incidents.add(lap.lap);
    }
    return incidents;
  }

  void setFocusedDriver(String? driverName) {
    if (driverName == null) {
      state = state.copyWith(clearFocusedDriver: true);
    } else {
      state = state.copyWith(focusedDriverName: driverName);
    }
  }

  // Legacy — kept so old code compiles, redirects are ignored
  Future<void> loadLap(String meetingName, int lap) async {}
  Future<void> selectMeeting(String meetingName) async {}

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }
}

final raceReplayProvider =
    StateNotifierProvider<RaceReplayNotifier, RaceReplayState>((ref) {
  return RaceReplayNotifier(ref);
});

class TeamRadioNotifier extends StateNotifier<AsyncValue<List<TeamRadioItem>>> {
  final Ref _ref;
  Timer? _timer;

  TeamRadioNotifier(this._ref) : super(const AsyncValue.loading()) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/team-radio');
      final list = response.data as List;
      final data = list.map((i) => TeamRadioItem.fromJson(i as Map<String, dynamic>)).toList();
      if (mounted) {
        state = AsyncValue.data(data);
      }
    } catch (e, stack) {
      debugPrint('Team Radio fetch notice: $e');
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    } finally {
      if (mounted) {
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 10), _fetch);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final teamRadioFeedProvider = StateNotifierProvider.autoDispose<TeamRadioNotifier, AsyncValue<List<TeamRadioItem>>>((ref) {
  return TeamRadioNotifier(ref);
});

class RaceEventsNotifier extends StateNotifier<AsyncValue<List<RaceEventItem>>> {
  final Ref _ref;
  Timer? _timer;

  RaceEventsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/race-events');
      final list = response.data as List;
      final data = list.map((i) => RaceEventItem.fromJson(i as Map<String, dynamic>)).toList();
      if (mounted) {
        state = AsyncValue.data(data);
      }
    } catch (e, stack) {
      debugPrint('Race events fetch notice: $e');
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    } finally {
      if (mounted) {
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 8), _fetch);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final raceEventsFeedProvider = StateNotifierProvider.autoDispose<RaceEventsNotifier, AsyncValue<List<RaceEventItem>>>((ref) {
  return RaceEventsNotifier(ref);
});

class LiveNewsNotifier extends StateNotifier<AsyncValue<List<LiveNewsArticle>>> {
  final Ref _ref;
  Timer? _timer;

  LiveNewsNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchNews();
  }

  Future<void> fetchNews() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/news/live');
      final list = response.data as List;
      final data = list.map((i) => LiveNewsArticle.fromJson(i as Map<String, dynamic>)).toList();
      if (mounted && data.isNotEmpty) {
        state = AsyncValue.data(data);
      }
    } catch (e, stack) {
      debugPrint('Live News fetch notice: $e');
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    } finally {
      if (mounted) {
        _timer?.cancel();
        _timer = Timer(const Duration(minutes: 5), fetchNews);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final liveNewsFeedProvider = StateNotifierProvider.autoDispose<LiveNewsNotifier, AsyncValue<List<LiveNewsArticle>>>((ref) {
  return LiveNewsNotifier(ref);
});

class SessionLiveStatusNotifier extends StateNotifier<AsyncValue<SessionLiveStatus>> {
  final Ref _ref;
  Timer? _timer;

  SessionLiveStatusNotifier(this._ref) : super(const AsyncValue.loading()) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/session-status');
      final data = SessionLiveStatus.fromJson(response.data as Map<String, dynamic>);
      if (mounted) {
        state = AsyncValue.data(data);
      }
      _scheduleNext(const Duration(seconds: 30));
    } catch (e, stack) {
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
      _scheduleNext(const Duration(seconds: 45));
    }
  }

  void _scheduleNext(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _fetch);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sessionLiveStatusProvider = StateNotifierProvider.autoDispose<SessionLiveStatusNotifier, AsyncValue<SessionLiveStatus>>((ref) {
  return SessionLiveStatusNotifier(ref);
});

/// True when the backend responded successfully at least once recently.
/// Derived from sessionLiveStatusProvider — if it errors, the backend is unreachable.
final backendReachableProvider = Provider.autoDispose<bool>((ref) {
  final status = ref.watch(sessionLiveStatusProvider);
  // Data = reachable; loading = unknown (assume reachable until proven otherwise)
  // error = unreachable
  return !status.hasError;
});

final trackConditionsProvider = FutureProvider.autoDispose<TrackConditions>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/telemetry/track-conditions');
  return TrackConditions.fromJson(response.data as Map<String, dynamic>);
});

final tireStrategyProvider = FutureProvider.autoDispose<TireStrategyData>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/telemetry/tire-strategy');
  return TireStrategyData.fromJson(response.data as Map<String, dynamic>);
});
