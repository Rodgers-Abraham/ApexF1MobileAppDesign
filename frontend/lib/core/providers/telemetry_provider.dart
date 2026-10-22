import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_provider.dart'; // For apiClientProvider


class DriverStandingJolpica {
  final String pos;
  final String name;
  final String team;
  final String pts;
  final String wins;

  DriverStandingJolpica({
    required this.pos,
    required this.name,
    required this.team,
    required this.pts,
    required this.wins,
  });

  factory DriverStandingJolpica.fromJson(Map<String, dynamic> json) {
    return DriverStandingJolpica(
      pos: json['pos']?.toString() ?? '0',
      name: json['name']?.toString() ?? '',
      team: json['team']?.toString() ?? '',
      pts: json['pts']?.toString() ?? '0',
      wins: json['wins']?.toString() ?? '0',
    );
  }
}

class ConstructorStandingJolpica {
  final String pos;
  final String name;
  final String pts;
  final String wins;

  ConstructorStandingJolpica({
    required this.pos,
    required this.name,
    required this.pts,
    required this.wins,
  });

  factory ConstructorStandingJolpica.fromJson(Map<String, dynamic> json) {
    return ConstructorStandingJolpica(
      pos: json['pos']?.toString() ?? '0',
      name: json['name']?.toString() ?? '',
      pts: json['pts']?.toString() ?? '0',
      wins: json['wins']?.toString() ?? '0',
    );
  }
}

class LiveTelemetry {
  final String pos;
  final String name;
  final int driverNumber;
  final String team;
  final String gap;
  final String interval;
  final int positionsGained;
  final String status;
  final String dnfReason;
  final String tyre;
  final String tyreLife;
  final String lastLap;
  final String bestLap;
  final bool isFastestLap;
  final int pitStops;
  final bool drs;
  final String speed;
  final String gear;
  final String color;
  final double x;
  final double y;

  LiveTelemetry({
    required this.pos,
    required this.name,
    this.driverNumber = 0,
    this.team = 'F1 Team',
    required this.gap,
    this.interval = '-',
    this.positionsGained = 0,
    this.status = 'ON TRACK',
    this.dnfReason = '',
    required this.tyre,
    required this.tyreLife,
    this.lastLap = '',
    this.bestLap = '',
    this.isFastestLap = false,
    this.pitStops = 0,
    this.drs = false,
    required this.speed,
    required this.gear,
    required this.color,
    required this.x,
    required this.y,
  });

  factory LiveTelemetry.fromJson(Map<String, dynamic> json) {
    return LiveTelemetry(
      pos: json['pos']?.toString() ?? '1',
      name: json['name']?.toString() ?? 'Driver',
      driverNumber: (json['driver_number'] as num?)?.toInt() ?? 0,
      team: json['team']?.toString() ?? 'F1 Team',
      gap: json['gap']?.toString() ?? 'LEADER',
      interval: json['interval']?.toString() ?? '-',
      positionsGained: (json['positions_gained'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'ON TRACK',
      dnfReason: json['dnf_reason']?.toString() ?? '',
      tyre: json['tyre']?.toString() ?? 'M',
      tyreLife: json['tyreLife']?.toString() ?? '1 lap',
      lastLap: json['last_lap']?.toString() ?? '',
      bestLap: json['best_lap']?.toString() ?? '',
      isFastestLap: json['is_fastest_lap'] as bool? ?? false,
      pitStops: (json['pit_stops'] as num?)?.toInt() ?? 0,
      drs: json['drs'] as bool? ?? false,
      speed: json['speed']?.toString() ?? '300 km/h',
      gear: json['gear']?.toString() ?? 'G7',
      color: json['color']?.toString() ?? '#3671C6',
      x: (json['x'] as num?)?.toDouble() ?? 90.0,
      y: (json['y'] as num?)?.toDouble() ?? 90.0,
    );
  }
}

class RaceFlagStatus {
  final String flag;
  final String title;
  final String message;
  final bool safetyCarActive;
  final bool vscActive;
  final bool redFlagActive;
  final bool yellowFlagActive;
  final int activeSector;

  const RaceFlagStatus({
    this.flag = 'GREEN',
    this.title = 'TRACK CLEAR',
    this.message = 'All sectors clear for racing',
    this.safetyCarActive = false,
    this.vscActive = false,
    this.redFlagActive = false,
    this.yellowFlagActive = false,
    this.activeSector = 0,
  });

  static const defaultStatus = RaceFlagStatus();

  factory RaceFlagStatus.fromJson(Map<String, dynamic> json) {
    return RaceFlagStatus(
      flag: json['flag']?.toString() ?? 'GREEN',
      title: json['title']?.toString() ?? 'TRACK CLEAR',
      message: json['message']?.toString() ?? 'All sectors clear for racing',
      safetyCarActive: json['safety_car_active'] as bool? ?? false,
      vscActive: json['vsc_active'] as bool? ?? false,
      redFlagActive: json['red_flag_active'] as bool? ?? false,
      yellowFlagActive: json['yellow_flag_active'] as bool? ?? false,
      activeSector: (json['active_sector'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isSafetyCar => safetyCarActive;
  bool get isVsc => vscActive;
  bool get isRedFlag => redFlagActive;
  bool get isYellowFlag => yellowFlagActive;
  bool get isChequeredFlag => flag == 'CHEQUERED';
}

class RaceFlagStatusNotifier extends StateNotifier<AsyncValue<RaceFlagStatus>> {
  final Ref _ref;
  Timer? _timer;

  RaceFlagStatusNotifier(this._ref) : super(const AsyncValue.data(RaceFlagStatus.defaultStatus)) {
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
      if (mounted && state.value == null) {
        state = const AsyncValue.data(RaceFlagStatus.defaultStatus);
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

class TeamRadioItem {
  final String id;
  final int driverNumber;
  final String driverName;
  final String team;
  final String color;
  final String timestamp;
  final String audioUrl;
  final String transcript;

  TeamRadioItem({
    required this.id,
    required this.driverNumber,
    required this.driverName,
    required this.team,
    required this.color,
    required this.timestamp,
    required this.audioUrl,
    required this.transcript,
  });

  factory TeamRadioItem.fromJson(Map<String, dynamic> json) {
    return TeamRadioItem(
      id: json['id']?.toString() ?? '',
      driverNumber: (json['driver_number'] as num?)?.toInt() ?? 0,
      driverName: json['driver_name']?.toString() ?? 'Driver',
      team: json['team']?.toString() ?? 'F1 Team',
      color: json['color']?.toString() ?? '#00D2BE',
      timestamp: json['timestamp']?.toString() ?? 'LIVE',
      audioUrl: json['audio_url']?.toString() ?? '',
      transcript: json['transcript']?.toString() ?? 'Radio message received.',
    );
  }
}

class RaceEventItem {
  final String id;
  final String eventType;
  final String category;
  final String message;
  final String driverName;
  final String team;
  final String timestamp;
  final int lapNumber;
  final String lapTime;

  RaceEventItem({
    required this.id,
    required this.eventType,
    required this.category,
    required this.message,
    required this.driverName,
    required this.team,
    required this.timestamp,
    required this.lapNumber,
    required this.lapTime,
  });

  factory RaceEventItem.fromJson(Map<String, dynamic> json) {
    return RaceEventItem(
      id: json['id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'GENERAL',
      category: json['category']?.toString() ?? 'Race Control',
      message: json['message']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? 'Race Control',
      team: json['team']?.toString() ?? 'FIA',
      timestamp: json['timestamp']?.toString() ?? 'LIVE',
      lapNumber: (json['lap_number'] as num?)?.toInt() ?? 0,
      lapTime: json['lap_time']?.toString() ?? '',
    );
  }
}

// Fetch live driver standings (Jolpica API Gateway with 2026 offline fallback)
final liveDriverStandingsProvider = FutureProvider.autoDispose<List<DriverStandingJolpica>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final response = await client.get('/api/f1/live-standings/drivers');
    final list = response.data as List;
    final parsed = list.map((i) => DriverStandingJolpica.fromJson(i as Map<String, dynamic>)).toList();
    if (parsed.isNotEmpty) return parsed;
  } catch (e) {
    debugPrint('Using offline driver standings fallback: $e');
  }
  return _defaultDriverStandings;
});

// Fetch live constructor standings (Jolpica API Gateway with 2026 offline fallback)
final liveConstructorStandingsProvider = FutureProvider.autoDispose<List<ConstructorStandingJolpica>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final response = await client.get('/api/f1/live-standings/constructors');
    final list = response.data as List;
    final parsed = list.map((i) => ConstructorStandingJolpica.fromJson(i as Map<String, dynamic>)).toList();
    if (parsed.isNotEmpty) return parsed;
  } catch (e) {
    debugPrint('Using offline constructor standings fallback: $e');
  }
  return _defaultConstructorStandings;
});

/// Telemetry fetcher with exponential backoff retry logic.
/// Automatically refreshes every 5 seconds on success, or retries with backoff on failure.
class TelemetryNotifier extends StateNotifier<AsyncValue<List<LiveTelemetry>>> {
  final Ref _ref;
  Timer? _timer;
  int _retryCount = 0;
  static const int _maxRetry = 5;
  static const Duration _baseRefresh = Duration(seconds: 2);

  TelemetryNotifier(this._ref) : super(AsyncValue.data(_defaultTelemetryData)) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/telemetry/live');
      final list = response.data as List;
      final data = list.map((i) => LiveTelemetry.fromJson(i as Map<String, dynamic>)).toList();
      if (mounted) {
        state = AsyncValue.data(data.isNotEmpty ? data : _defaultTelemetryData);
        _retryCount = 0;
      }
      _scheduleNext(_baseRefresh);
    } catch (e, _) {
      debugPrint('Telemetry fetch notice: $e');
      if (mounted) {
        if (state.value == null || state.value!.isEmpty) {
          state = AsyncValue.data(_defaultTelemetryData);
        }
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
      : super(RaceReplayState(
          meetingName: 'Singapore Grand Prix',
          circuitName: 'Marina Bay Street Circuit',
          currentLap: 1,
          totalLaps: 62,
          telemetry: _defaultTelemetryData,
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

  TeamRadioNotifier(this._ref) : super(AsyncValue.data(_defaultTeamRadios)) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/team-radio');
      final list = response.data as List;
      final data = list.map((i) => TeamRadioItem.fromJson(i as Map<String, dynamic>)).toList();
      if (mounted) {
        state = AsyncValue.data(data.isNotEmpty ? data : _defaultTeamRadios);
      }
    } catch (e, _) {
      debugPrint('Team Radio fetch notice: $e');
      if (mounted && (state.value == null || state.value!.isEmpty)) {
        state = AsyncValue.data(_defaultTeamRadios);
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

  RaceEventsNotifier(this._ref) : super(AsyncValue.data(_defaultRaceEvents)) {
    _fetch();
  }

  void _fetch() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/f1/race-events');
      final list = response.data as List;
      final data = list.map((i) => RaceEventItem.fromJson(i as Map<String, dynamic>)).toList();
      if (mounted) {
        state = AsyncValue.data(data.isNotEmpty ? data : _defaultRaceEvents);
      }
    } catch (e, _) {
      debugPrint('Race events fetch notice: $e');
      if (mounted && (state.value == null || state.value!.isEmpty)) {
        state = AsyncValue.data(_defaultRaceEvents);
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

class LiveNewsArticle {
  final String title;
  final String summary;
  final String url;
  final String source;
  final String publishedAt;
  final String imageUrl;

  LiveNewsArticle({
    required this.title,
    required this.summary,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.imageUrl,
  });

  String get category => 'OFFICIAL';
  String get timeAgo => publishedAt;

  factory LiveNewsArticle.fromJson(Map<String, dynamic> json) {
    return LiveNewsArticle(
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'F1 News',
      publishedAt: json['published_at']?.toString() ?? 'Just now',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}

class LiveNewsNotifier extends StateNotifier<AsyncValue<List<LiveNewsArticle>>> {
  final Ref _ref;
  Timer? _timer;

  LiveNewsNotifier(this._ref) : super(AsyncValue.data(_defaultNewsArticles)) {
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
    } catch (e, _) {
      debugPrint('Live News fetch notice: $e');
      if (mounted && (state.value == null || state.value!.isEmpty)) {
        state = AsyncValue.data(_defaultNewsArticles);
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

class SessionLiveStatus {
  final bool isLive;
  final bool isRaceWeekend;
  final String sessionName;
  final String meetingName;
  final String circuitName;
  final String location;
  final String statusMessage;
  final String dateStart;
  final String dateEnd;
  final String nextSessionName;
  final String nextSessionMeeting;
  final String nextSessionDate;
  final String nextSessionCircuit;
  final int secondsUntilNext;

  SessionLiveStatus({
    required this.isLive,
    required this.isRaceWeekend,
    required this.sessionName,
    required this.meetingName,
    required this.circuitName,
    required this.location,
    required this.statusMessage,
    required this.dateStart,
    required this.dateEnd,
    required this.nextSessionName,
    required this.nextSessionMeeting,
    required this.nextSessionDate,
    required this.nextSessionCircuit,
    required this.secondsUntilNext,
  });

  static final offlineFallback = SessionLiveStatus(
    isLive: false,
    isRaceWeekend: false,
    sessionName: 'Pre-Season Standby',
    meetingName: 'Australian Grand Prix',
    circuitName: 'Albert Park Grand Prix Circuit',
    location: 'Melbourne',
    statusMessage: 'TRACK STANDBY — ROUND 01 MELBOURNE',
    dateStart: '2026-03-20T01:30:00+00:00',
    dateEnd: '2026-03-22T06:00:00+00:00',
    nextSessionName: 'Practice 1',
    nextSessionMeeting: 'Australian Grand Prix',
    nextSessionDate: '2026-03-20T01:30:00+00:00',
    nextSessionCircuit: 'Albert Park',
    secondsUntilNext: 0,
  );

  factory SessionLiveStatus.fromJson(Map<String, dynamic> json) {
    return SessionLiveStatus(
      isLive: json['is_live'] as bool? ?? false,
      isRaceWeekend: json['is_race_weekend'] as bool? ?? false,
      sessionName: json['session_name'] as String? ?? 'No Active Session',
      meetingName: json['meeting_name'] as String? ?? 'Formula 1',
      circuitName: json['circuit_name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      statusMessage: json['status_message'] as String? ?? 'TRACK CLOSED',
      dateStart: json['date_start'] as String? ?? '',
      dateEnd: json['date_end'] as String? ?? '',
      nextSessionName: json['next_session_name'] as String? ?? 'Practice 1',
      nextSessionMeeting: json['next_session_meeting'] as String? ?? 'Upcoming GP',
      nextSessionDate: json['next_session_date'] as String? ?? '',
      nextSessionCircuit: json['next_session_circuit'] as String? ?? '',
      secondsUntilNext: json['seconds_until_next'] as int? ?? 0,
    );
  }
}

class SessionLiveStatusNotifier extends StateNotifier<AsyncValue<SessionLiveStatus>> {
  final Ref _ref;
  Timer? _timer;

  SessionLiveStatusNotifier(this._ref) : super(AsyncValue.data(SessionLiveStatus.offlineFallback)) {
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
    } catch (e, _) {
      if (mounted && (state.value == null)) {
        state = AsyncValue.data(SessionLiveStatus.offlineFallback);
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

class TrackConditions {
  final String trackTemperature;
  final String airTemperature;
  final String humidity;
  final String windSpeed;
  final String windDirection;
  final bool rainfall;
  final String pressure;
  final String trackStatus;
  final String sessionName;
  final String circuitName;
  final String summary;

  TrackConditions({
    required this.trackTemperature,
    required this.airTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.rainfall,
    required this.pressure,
    required this.trackStatus,
    required this.sessionName,
    required this.circuitName,
    required this.summary,
  });

  factory TrackConditions.fromJson(Map<String, dynamic> json) {
    return TrackConditions(
      trackTemperature: json['track_temperature']?.toString() ?? '38.4°C',
      airTemperature: json['air_temperature']?.toString() ?? '24.1°C',
      humidity: json['humidity']?.toString() ?? '62%',
      windSpeed: json['wind_speed']?.toString() ?? '4.2 km/h',
      windDirection: json['wind_direction']?.toString() ?? '0°',
      rainfall: json['rainfall'] as bool? ?? false,
      pressure: json['pressure']?.toString() ?? '1013 mbar',
      trackStatus: json['track_status']?.toString() ?? 'DRY',
      sessionName: json['session_name']?.toString() ?? 'Race',
      circuitName: json['circuit_name']?.toString() ?? 'Circuit',
      summary: json['summary']?.toString() ?? 'Track is DRY',
    );
  }
}

final trackConditionsProvider = FutureProvider.autoDispose<TrackConditions>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final response = await client.get('/api/f1/telemetry/track-conditions');
    return TrackConditions.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    debugPrint('Track conditions fallback: $e');
    return TrackConditions(
      trackTemperature: '28.4°C',
      airTemperature: '22.1°C',
      humidity: '58%',
      windSpeed: '12.4 km/h',
      windDirection: '240° SW',
      rainfall: false,
      pressure: '1014 hPa',
      trackStatus: 'DRY',
      sessionName: 'Pre-Season Testing',
      circuitName: 'Albert Park Grand Prix Circuit',
      summary: 'Track is DRY · Optimal grip levels',
    );
  }
});

class CompoundStrategyItem {
  final String compound;
  final int laps;
  final int avgLaps;
  final int stintsCount;
  final String color;

  CompoundStrategyItem({
    required this.compound,
    required this.laps,
    required this.avgLaps,
    required this.stintsCount,
    required this.color,
  });

  factory CompoundStrategyItem.fromJson(Map<String, dynamic> json) {
    return CompoundStrategyItem(
      compound: json['compound']?.toString() ?? 'UNKNOWN',
      laps: (json['laps'] as num?)?.toInt() ?? 0,
      avgLaps: (json['avg_laps'] as num?)?.toInt() ?? 0,
      stintsCount: (json['stints_count'] as num?)?.toInt() ?? 0,
      color: json['color']?.toString() ?? '#CCCCCC',
    );
  }
}

class TireStrategyData {
  final int sessionKey;
  final int totalStints;
  final List<CompoundStrategyItem> strategies;

  TireStrategyData({
    required this.sessionKey,
    required this.totalStints,
    required this.strategies,
  });

  factory TireStrategyData.fromJson(Map<String, dynamic> json) {
    final list = json['strategies'] as List? ?? [];
    return TireStrategyData(
      sessionKey: (json['session_key'] as num?)?.toInt() ?? 0,
      totalStints: (json['total_stints'] as num?)?.toInt() ?? 0,
      strategies: list.map((i) => CompoundStrategyItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}

final tireStrategyProvider = FutureProvider.autoDispose<TireStrategyData>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final response = await client.get('/api/f1/telemetry/tire-strategy');
    return TireStrategyData.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    debugPrint('Tire strategy fallback: $e');
    return TireStrategyData(
      sessionKey: 9600,
      totalStints: 44,
      strategies: [
        CompoundStrategyItem(compound: 'SOFT', laps: 18, avgLaps: 16, stintsCount: 14, color: '#FF1801'),
        CompoundStrategyItem(compound: 'MEDIUM', laps: 28, avgLaps: 26, stintsCount: 20, color: '#FFD700'),
        CompoundStrategyItem(compound: 'HARD', laps: 36, avgLaps: 34, stintsCount: 10, color: '#FFFFFF'),
      ],
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 2026 OFFICIAL DEFAULTS & OFFLINE CACHE
// ─────────────────────────────────────────────────────────────────────────────
final List<DriverStandingJolpica> _defaultDriverStandings = [
  DriverStandingJolpica(pos: '1', name: 'Andrea Kimi Antonelli', team: 'Mercedes', pts: '340', wins: '8'),
  DriverStandingJolpica(pos: '2', name: 'George Russell', team: 'Mercedes', pts: '238', wins: '3'),
  DriverStandingJolpica(pos: '3', name: 'Lewis Hamilton', team: 'Ferrari', pts: '229', wins: '1'),
  DriverStandingJolpica(pos: '4', name: 'Max Verstappen', team: 'Red Bull Racing', pts: '221', wins: '2'),
  DriverStandingJolpica(pos: '5', name: 'Charles Leclerc', team: 'Ferrari', pts: '215', wins: '1'),
  DriverStandingJolpica(pos: '6', name: 'Lando Norris', team: 'McLaren', pts: '201', wins: '2'),
  DriverStandingJolpica(pos: '7', name: 'Oscar Piastri', team: 'McLaren', pts: '138', wins: '0'),
  DriverStandingJolpica(pos: '8', name: 'Isack Hadjar', team: 'Red Bull Racing', pts: '97', wins: '0'),
  DriverStandingJolpica(pos: '9', name: 'Liam Lawson', team: 'Racing Bulls', pts: '75', wins: '0'),
  DriverStandingJolpica(pos: '10', name: 'Pierre Gasly', team: 'Alpine', pts: '41', wins: '0'),
  DriverStandingJolpica(pos: '11', name: 'Arvid Lindblad', team: 'Racing Bulls', pts: '38', wins: '0'),
  DriverStandingJolpica(pos: '12', name: 'Franco Colapinto', team: 'Alpine', pts: '27', wins: '0'),
  DriverStandingJolpica(pos: '13', name: 'Oliver Bearman', team: 'Haas', pts: '23', wins: '0'),
  DriverStandingJolpica(pos: '14', name: 'Nico Hülkenberg', team: 'Audi', pts: '13', wins: '0'),
  DriverStandingJolpica(pos: '15', name: 'Gabriel Bortoleto', team: 'Audi', pts: '10', wins: '0'),
  DriverStandingJolpica(pos: '16', name: 'Esteban Ocon', team: 'Haas', pts: '7', wins: '0'),
  DriverStandingJolpica(pos: '17', name: 'Fernando Alonso', team: 'Aston Martin', pts: '7', wins: '0'),
  DriverStandingJolpica(pos: '18', name: 'Carlos Sainz', team: 'Williams', pts: '7', wins: '0'),
  DriverStandingJolpica(pos: '19', name: 'Alexander Albon', team: 'Williams', pts: '5', wins: '0'),
  DriverStandingJolpica(pos: '20', name: 'Yuki Tsunoda', team: 'Racing Bulls', pts: '1', wins: '0'),
  DriverStandingJolpica(pos: '21', name: 'Lance Stroll', team: 'Aston Martin', pts: '0', wins: '0'),
  DriverStandingJolpica(pos: '22', name: 'Valtteri Bottas', team: 'Cadillac', pts: '0', wins: '0'),
  DriverStandingJolpica(pos: '23', name: 'Sergio Perez', team: 'Cadillac', pts: '0', wins: '0'),
];

final List<ConstructorStandingJolpica> _defaultConstructorStandings = [
  ConstructorStandingJolpica(pos: '1', name: 'Mercedes', pts: '578', wins: '11'),
  ConstructorStandingJolpica(pos: '2', name: 'Ferrari', pts: '444', wins: '2'),
  ConstructorStandingJolpica(pos: '3', name: 'McLaren', pts: '339', wins: '2'),
  ConstructorStandingJolpica(pos: '4', name: 'Red Bull Racing', pts: '318', wins: '2'),
  ConstructorStandingJolpica(pos: '5', name: 'Racing Bulls', pts: '114', wins: '0'),
  ConstructorStandingJolpica(pos: '6', name: 'Alpine', pts: '68', wins: '0'),
  ConstructorStandingJolpica(pos: '7', name: 'Haas', pts: '30', wins: '0'),
  ConstructorStandingJolpica(pos: '8', name: 'Audi', pts: '23', wins: '0'),
  ConstructorStandingJolpica(pos: '9', name: 'Williams', pts: '12', wins: '0'),
  ConstructorStandingJolpica(pos: '10', name: 'Aston Martin', pts: '7', wins: '0'),
  ConstructorStandingJolpica(pos: '11', name: 'Cadillac', pts: '0', wins: '0'),
];

final List<LiveTelemetry> _defaultTelemetryData = [
  LiveTelemetry(pos: '1', name: 'Kimi Antonelli', driverNumber: 12, team: 'Mercedes', gap: 'LEADER', interval: 'LEADER', positionsGained: 1, status: 'ON TRACK', dnfReason: '', tyre: 'SOFT', tyreLife: '14 Laps', lastLap: '1:19.421', bestLap: '1:19.102', pitStops: 1, drs: false, speed: '324 km/h', gear: '8', color: '#00D2BE', x: 84.0, y: 112.0),
  LiveTelemetry(pos: '2', name: 'Lewis Hamilton', driverNumber: 44, team: 'Ferrari', gap: '+1.412', interval: '+1.412', positionsGained: 2, status: 'ON TRACK', dnfReason: '', tyre: 'MEDIUM', tyreLife: '18 Laps', lastLap: '1:19.554', bestLap: '1:19.240', pitStops: 1, drs: true, speed: '328 km/h', gear: '8', color: '#E80020', x: 92.0, y: 124.0),
  LiveTelemetry(pos: '3', name: 'George Russell', driverNumber: 63, team: 'Mercedes', gap: '+3.108', interval: '+1.696', positionsGained: 0, status: 'ON TRACK', dnfReason: '', tyre: 'MEDIUM', tyreLife: '17 Laps', lastLap: '1:19.780', bestLap: '1:19.310', pitStops: 1, drs: false, speed: '320 km/h', gear: '7', color: '#00D2BE', x: 104.0, y: 138.0),
  LiveTelemetry(pos: '4', name: 'Max Verstappen', driverNumber: 1, team: 'Red Bull Racing', gap: '+4.882', interval: '+1.774', positionsGained: -3, status: 'ON TRACK', dnfReason: '', tyre: 'HARD', tyreLife: '22 Laps', lastLap: '1:19.640', bestLap: '1:19.088', pitStops: 1, drs: true, speed: '331 km/h', gear: '8', color: '#3671C6', x: 115.0, y: 150.0),
  LiveTelemetry(pos: '5', name: 'Lando Norris', driverNumber: 4, team: 'McLaren', gap: '+6.240', interval: '+1.358', positionsGained: 1, status: 'ON TRACK', dnfReason: '', tyre: 'MEDIUM', tyreLife: '16 Laps', lastLap: '1:19.890', bestLap: '1:19.412', pitStops: 1, drs: false, speed: '322 km/h', gear: '7', color: '#FF8000', x: 128.0, y: 165.0),
  LiveTelemetry(pos: '6', name: 'Charles Leclerc', driverNumber: 16, team: 'Ferrari', gap: '+8.115', interval: '+1.875', positionsGained: 0, status: 'ON TRACK', dnfReason: '', tyre: 'HARD', tyreLife: '21 Laps', lastLap: '1:20.010', bestLap: '1:19.530', pitStops: 1, drs: true, speed: '326 km/h', gear: '8', color: '#E80020', x: 140.0, y: 180.0),
  LiveTelemetry(pos: '7', name: 'Oscar Piastri', driverNumber: 81, team: 'McLaren', gap: '+11.450', interval: '+3.335', positionsGained: 1, status: 'ON TRACK', dnfReason: '', tyre: 'MEDIUM', tyreLife: '15 Laps', lastLap: '1:20.120', bestLap: '1:19.620', pitStops: 1, drs: false, speed: '321 km/h', gear: '7', color: '#FF8000', x: 152.0, y: 195.0),
  LiveTelemetry(pos: '8', name: 'Pierre Gasly', driverNumber: 10, team: 'Alpine', gap: '+16.780', interval: '+5.330', positionsGained: 2, status: 'ON TRACK', dnfReason: '', tyre: 'MEDIUM', tyreLife: '19 Laps', lastLap: '1:20.450', bestLap: '1:20.010', pitStops: 1, drs: false, speed: '318 km/h', gear: '7', color: '#00A1E8', x: 165.0, y: 210.0),
  LiveTelemetry(pos: '9', name: 'Liam Lawson', driverNumber: 30, team: 'Racing Bulls', gap: '+19.220', interval: '+2.440', positionsGained: 1, status: 'ON TRACK', dnfReason: '', tyre: 'HARD', tyreLife: '25 Laps', lastLap: '1:20.660', bestLap: '1:20.150', pitStops: 1, drs: true, speed: '320 km/h', gear: '7', color: '#6692FF', x: 178.0, y: 225.0),
  LiveTelemetry(pos: '10', name: 'Carlos Sainz', driverNumber: 55, team: 'Williams', gap: '+22.500', interval: '+3.280', positionsGained: 3, status: 'ON TRACK', dnfReason: '', tyre: 'MEDIUM', tyreLife: '14 Laps', lastLap: '1:20.710', bestLap: '1:20.220', pitStops: 1, drs: false, speed: '322 km/h', gear: '8', color: '#00A0DE', x: 190.0, y: 240.0),
];

final List<TeamRadioItem> _defaultTeamRadios = [
  TeamRadioItem(
    id: 'rad-1',
    driverNumber: 1,
    driverName: 'Max Verstappen',
    team: 'Red Bull Racing',
    color: '#3671C6',
    timestamp: 'LAP 39',
    audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/MAXVER01_1_20230915_103928.mp3',
    transcript: 'Balance is spot on, building gap to P2.',
  ),
  TeamRadioItem(
    id: 'rad-2',
    driverNumber: 55,
    driverName: 'Carlos Sainz',
    team: 'Williams',
    color: '#00A0DE',
    timestamp: 'LAP 42',
    audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/CARSAI01_55_20230915_103326.mp3',
    transcript: 'Tires feel great, let\'s keep this rhythm.',
  ),
  TeamRadioItem(
    id: 'rad-3',
    driverNumber: 63,
    driverName: 'George Russell',
    team: 'Mercedes',
    color: '#00D2BE',
    timestamp: 'LAP 41',
    audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/GEORUS01_63_20230915_103406.mp3',
    transcript: 'Track status clear, DRS active.',
  ),
  TeamRadioItem(
    id: 'rad-4',
    driverNumber: 81,
    driverName: 'Oscar Piastri',
    team: 'McLaren',
    color: '#FF8000',
    timestamp: 'LAP 38',
    audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/OSCPIA01_81_20230915_104409.mp3',
    transcript: 'Box box, changing to hard compound.',
  ),
];

final List<RaceEventItem> _defaultRaceEvents = [
  RaceEventItem(id: 'ev-1', eventType: 'OVERTAKE', category: 'Overtake', message: 'K. Antonelli overtook L. Hamilton for P1 into Turn 1', driverName: 'Kimi Antonelli', team: 'Mercedes', timestamp: 'LAP 34', lapNumber: 34, lapTime: '1:19.421'),
  RaceEventItem(id: 'ev-2', eventType: 'PIT STOP', category: 'Pit Stop', message: 'L. Hamilton pit stop (2.1s) - Medium tyres fitted', driverName: 'Lewis Hamilton', team: 'Ferrari', timestamp: 'LAP 32', lapNumber: 32, lapTime: '1:41.200'),
  RaceEventItem(id: 'ev-3', eventType: 'FASTEST LAP', category: 'Lap Record', message: 'M. Verstappen sets fastest lap: 1:19.088', driverName: 'Max Verstappen', team: 'Red Bull Racing', timestamp: 'LAP 28', lapNumber: 28, lapTime: '1:19.088'),
  RaceEventItem(id: 'ev-4', eventType: 'SAFETY CAR', category: 'Race Control', message: 'Virtual Safety Car deployed — Debris at Turn 4', driverName: 'Race Control', team: 'FIA', timestamp: 'LAP 15', lapNumber: 15, lapTime: ''),
];

final List<LiveNewsArticle> _defaultNewsArticles = [
  LiveNewsArticle(
    title: 'Camara on the ‘crazy’ achievement of joining Haas in 2027',
    summary: 'New Haas recruit Rafael Camara tells Lawrence Barretto about finding out he would join Haas in 2027 and the shoot-out test that he participated in.',
    url: 'https://www.formula1.com/en/latest/article/exclusive-its-really-crazy-to-achieve-this-camara-on-joining-haas-in-2027-and-the-intense-shoot-out-test-he-faced.Sx8HzUOO7WsUm0afvDcP4',
    source: 'Formula 1',
    publishedAt: 'Today',
    imageUrl: 'https://media.formula1.com/image/upload/c_lfill,w_2048/q_auto/v1740000001/fom-website/2026/Haas/EXCLUSIVE_INTERVIEW_ADHOC%20FEATURE%20V4.webp',
  ),
  LiveNewsArticle(
    title: 'Williams outline plans for 50th anniversary year in 2027',
    summary: 'Williams have outlined plans for their 50th anniversary year in 2027, with a milestone chassis designation and an immersive London experience.',
    url: 'https://www.formula1.com/en/latest/article/williams-outline-plans-for-50th-anniversary-year-with-calendar-of-special-events.wxPd7X2kbw2bUHstwFeZB',
    source: 'Formula 1',
    publishedAt: 'Today',
    imageUrl: 'https://media.formula1.com/image/upload/c_lfill,w_2048/q_auto/v1740000001/fom-website/2026/Miscellaneous/W50%20Logo%20-%201920X1080.webp',
  ),
  LiveNewsArticle(
    title: 'The next Ferrari protege Haas couldn’t turn down',
    summary: 'F1.com looks at the qualities Rafael Camara has displayed so far that appear to make him the ideal candidate for Haas.',
    url: 'https://www.formula1.com/en/latest/article/rafael-camara-the-next-ferrari-protege-haas-couldnt-turn-down.24Vz3MR6I5GVOywy1z8C39',
    source: 'Formula 1',
    publishedAt: 'Today',
    imageUrl: 'https://media.formula1.com/image/upload/t_16by9North/c_lfill,w_2048/q_auto/v1740000001/fom-website/2026/Formula%202/Camara%20Baku.webp',
  ),
  LiveNewsArticle(
    title: 'Mekies signs long-term contract extension with Red Bull',
    summary: 'Red Bull have confirmed that Laurent Mekies will continue his role as Team Principal through 2031.',
    url: 'https://www.formula1.com/en/latest/article/mekies-commits-to-long-term-contract-extension-as-red-bull-team-principal.1NfCP1Zas2IAzVa3sNa3yf',
    source: 'Formula 1',
    publishedAt: 'Yesterday',
    imageUrl: 'https://media.formula1.com/image/upload/c_lfill,w_2048/q_auto/v1740000001/fom-website/2026/Red%20Bull/16x9%20single%20image%20-%202026-10-14T172838.451.webp',
  ),
];




