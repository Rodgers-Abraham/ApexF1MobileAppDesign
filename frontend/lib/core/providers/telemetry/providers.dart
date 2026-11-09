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
  final List<ReplayLapEntry> allLaps; // full session loaded at once
  final String? focusedDriverName; // driver being highlighted

  const RaceReplayState({
    this.meetingName = '',
    this.circuitName = '',
    this.sessionType = 'race',
    this.currentLap = 1,
    this.totalLaps = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.loadError,
    this.telemetry = const [],
    this.flagStatus = RaceFlagStatus.defaultStatus,
    this.allLaps = const [],
    this.focusedDriverName,
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
    String? focusedDriverName,
    bool clearFocusedDriver = false,
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
      focusedDriverName: clearFocusedDriver ? null : (focusedDriverName ?? this.focusedDriverName),
    );
  }

  String get lapLabel {
    if (allLaps.isEmpty) return 'LAP $currentLap';
    final entry = allLaps.firstWhere((l) => l.lap == currentLap, orElse: () => allLaps.first);
    return entry.phase.isNotEmpty ? entry.phase : 'LAP $currentLap';
  }

  bool get isAtEnd => totalLaps > 0 && currentLap >= totalLaps;

  /// Compute a summary for the focused driver at the current lap.
  DriverReplaySummary? get focusedDriverSummary {
    if (focusedDriverName == null || allLaps.isEmpty) return null;
    final hint = focusedDriverName!.toLowerCase();

    // Find driver in current (or last) lap
    final currentEntry = allLaps.firstWhere(
      (l) => l.lap == currentLap,
      orElse: () => allLaps.last,
    );

    // Find fastest lap across all laps
    String fastest = '';
    int fastestLapNum = 0;
    double fastestSecs = double.infinity;
    for (final lap in allLaps) {
      if (lap.lap == 0) continue; // skip grid
      final driver = lap.positions.where((d) =>
          d.name.toLowerCase().contains(hint) || hint.contains(d.name.toLowerCase())).firstOrNull;
      if (driver == null) continue;
      final t = driver.lastLap;
      if (t.isNotEmpty && t.contains(':')) {
        try {
          final parts = t.split(':');
          final secs = double.parse(parts[0]) * 60 + double.parse(parts[1]);
          if (secs < fastestSecs) {
            fastestSecs = secs;
            fastest = t;
            fastestLapNum = lap.lap;
          }
        } catch (_) {}
      }
    }

    final driverData = currentEntry.positions.firstWhere(
      (d) => d.name.toLowerCase().contains(hint) || hint.contains(d.name.toLowerCase()),
      orElse: () => currentEntry.positions.isEmpty ? currentEntry.positions.first : currentEntry.positions.last,
    );

    return DriverReplaySummary(
      driverName: driverData.name,
      driverCode: driverData.team.isNotEmpty ? driverData.team.substring(0, 2) : '??',
      team: driverData.team,
      finalPosition: int.tryParse(driverData.pos) ?? 0,
      fastestLap: fastest,
      fastestLapNum: fastestLapNum,
    );
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
      telemetry: [],
    );

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

      if (mounted) {
        state = state.copyWith(
          meetingName: data['race_name']?.toString() ?? meetingName,
          circuitName: data['circuit']?.toString() ?? '',
          sessionType: data['session_type']?.toString() ?? sessionType,
          totalLaps: totalLaps,
          currentLap: 1,
          allLaps: entries,
          isLoading: false,
          telemetry: entries.isNotEmpty ? entries.first.positions : [],
        );
      }
    } catch (e) {
      debugPrint('Session replay error: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          loadError: 'Timing data not yet available for this session. Try again later.',
        );
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
      status: 'ON TRACK',
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
    final clamped = lap.clamp(1, state.totalLaps > 0 ? state.totalLaps : 1);
    final entry = state.allLaps.firstWhere(
      (l) => l.lap == clamped,
      orElse: () => state.allLaps.isNotEmpty ? state.allLaps.first : ReplayLapEntry(lap: 1, phase: '', positions: []),
    );
    state = state.copyWith(currentLap: clamped, telemetry: entry.positions);
  }

  void nextLap() {
    if (state.currentLap < state.totalLaps) {
      setLap(state.currentLap + 1);
    } else {
      pause();
    }
  }

  void prevLap() {
    if (state.currentLap > 1) setLap(state.currentLap - 1);
  }

  void togglePlay() => state.isPlaying ? pause() : play();

  void play() {
    _playTimer?.cancel();
    state = state.copyWith(isPlaying: true);
    _playTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
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
