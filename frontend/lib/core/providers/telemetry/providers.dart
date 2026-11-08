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

class RaceReplayState {
  final String meetingName;
  final String circuitName;
  final int currentLap;
  final int totalLaps;
  final bool isPlaying;
  final bool isLoading;
  final List<LiveTelemetry> telemetry;
  final RaceFlagStatus flagStatus;

  const RaceReplayState({
    required this.meetingName,
    required this.circuitName,
    required this.currentLap,
    required this.totalLaps,
    this.isPlaying = false,
    this.isLoading = false,
    required this.telemetry,
    this.flagStatus = RaceFlagStatus.defaultStatus,
  });

  RaceReplayState copyWith({
    String? meetingName,
    String? circuitName,
    int? currentLap,
    int? totalLaps,
    bool? isPlaying,
    bool? isLoading,
    List<LiveTelemetry>? telemetry,
    RaceFlagStatus? flagStatus,
  }) {
    return RaceReplayState(
      meetingName: meetingName ?? this.meetingName,
      circuitName: circuitName ?? this.circuitName,
      currentLap: currentLap ?? this.currentLap,
      totalLaps: totalLaps ?? this.totalLaps,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      telemetry: telemetry ?? this.telemetry,
      flagStatus: flagStatus ?? this.flagStatus,
    );
  }
}

class RaceReplayNotifier extends StateNotifier<RaceReplayState> {
  final Ref _ref;
  Timer? _playTimer;

  RaceReplayNotifier(this._ref)
      : super(const RaceReplayState(
          meetingName: 'Singapore Grand Prix',
          circuitName: 'Marina Bay Street Circuit',
          currentLap: 1,
          totalLaps: 62,
          telemetry: [],
        )) {
    loadLap('Singapore Grand Prix', 1);
  }

  Future<void> selectMeeting(String meetingName) async {
    _playTimer?.cancel();
    state = state.copyWith(
      meetingName: meetingName,
      currentLap: 1,
      isPlaying: false,
      isLoading: true,
    );
    await loadLap(meetingName, 1);
  }

  Future<void> setLap(int lap) async {
    final clamped = lap.clamp(1, state.totalLaps);
    if (clamped == state.currentLap && state.telemetry.isNotEmpty && !state.isLoading) return;
    await loadLap(state.meetingName, clamped);
  }

  Future<void> nextLap() async {
    if (state.currentLap < state.totalLaps) {
      await loadLap(state.meetingName, state.currentLap + 1);
    } else {
      pause();
    }
  }

  Future<void> prevLap() async {
    if (state.currentLap > 1) {
      await loadLap(state.meetingName, state.currentLap - 1);
    }
  }

  void togglePlay() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    _playTimer?.cancel();
    state = state.copyWith(isPlaying: true);
    _playTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
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

  Future<void> loadLap(String meetingName, int lap) async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get(
        '/api/f1/telemetry/replay',
        queryParameters: {'meeting': meetingName, 'lap': lap},
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['telemetry'] as List?) ?? [];
      final telemetryItems = list
          .map((i) => LiveTelemetry.fromJson(i as Map<String, dynamic>))
          .toList();
      final total = (data['total_laps'] as num?)?.toInt() ?? 60;
      final circuit = data['circuit_name']?.toString() ?? '';
      final flagData = data['flag_status'] as Map<String, dynamic>?;

      if (mounted) {
        state = state.copyWith(
          meetingName: data['meeting_name']?.toString() ?? meetingName,
          circuitName: circuit,
          currentLap: lap,
          totalLaps: total,
          isLoading: false,
          telemetry: telemetryItems.isNotEmpty ? telemetryItems : state.telemetry,
          flagStatus: flagData != null ? RaceFlagStatus.fromJson(flagData) : state.flagStatus,
        );
      }
    } catch (e) {
      debugPrint('Replay load lap notice: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

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
