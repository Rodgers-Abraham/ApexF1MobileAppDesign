import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

// Declare a provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class SessionResult {
  final int position;
  final String driverName;
  final String team;
  final String timeOrGap;

  SessionResult({
    required this.position,
    required this.driverName,
    required this.team,
    required this.timeOrGap,
  });

  factory SessionResult.fromJson(Map<String, dynamic> json) {
    return SessionResult(
      position: json['position'] as int,
      driverName: json['driver_name'] as String,
      team: json['team'] as String,
      timeOrGap: json['time_or_gap'] as String,
    );
  }
}

class LatestSession {
  final int sessionKey;
  final String meetingName;
  final String sessionName;
  final String sessionType;
  final String status;
  final String dateStart;
  final List<SessionResult> results;

  LatestSession({
    required this.sessionKey,
    required this.meetingName,
    required this.sessionName,
    required this.sessionType,
    required this.status,
    required this.dateStart,
    required this.results,
  });

  factory LatestSession.fromJson(Map<String, dynamic> json) {
    var resultsList = json['results'] as List;
    List<SessionResult> results = resultsList.map((i) => SessionResult.fromJson(i as Map<String, dynamic>)).toList();

    return LatestSession(
      sessionKey: json['session_key'] as int,
      meetingName: json['meeting_name'] as String,
      sessionName: json['session_name'] as String,
      sessionType: json['session_type'] as String,
      status: json['status'] as String,
      dateStart: json['date_start'] ?? '',
      results: results,
    );
  }
}

class DriverProbability {
  final String driverName;
  final double probability;

  DriverProbability({
    required this.driverName,
    required this.probability,
  });

  factory DriverProbability.fromJson(Map<String, dynamic> json) {
    return DriverProbability(
      driverName: json['driver_name'] as String,
      probability: (json['probability'] as num).toDouble(),
    );
  }
}

class SessionPredictions {
  final int sessionKey;
  final List<DriverProbability> predictions;

  SessionPredictions({
    required this.sessionKey,
    required this.predictions,
  });

  factory SessionPredictions.fromJson(Map<String, dynamic> json) {
    var predictionsList = json['predictions'] as List;
    List<DriverProbability> predictions = predictionsList.map((i) => DriverProbability.fromJson(i as Map<String, dynamic>)).toList();

    return SessionPredictions(
      sessionKey: json['session_key'] as int,
      predictions: predictions,
    );
  }
}

// FutureProvider for fetching latest session
final latestSessionProvider = FutureProvider<LatestSession>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/sessions/latest');
  return LatestSession.fromJson(response.data as Map<String, dynamic>);
});

// FutureProvider for fetching session predictions
final latestPredictionProvider = FutureProvider<SessionPredictions>((ref) async {
  final client = ref.watch(apiClientProvider);
  final sessionAsync = ref.watch(latestSessionProvider);
  
  // Wait until latest session is loaded
  final session = sessionAsync.value;
  if (session == null) {
    throw Exception('Latest session not loaded');
  }
  
  final response = await client.get('/api/sessions/predictions', queryParameters: {
    'session_key': session.sessionKey,
  });
  return SessionPredictions.fromJson(response.data as Map<String, dynamic>);
});

// StateNotifier to trigger next session simulation
class SessionNotifier extends StateNotifier<AsyncValue<LatestSession?>> {
  final Ref _ref;

  SessionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> simulateNextSession() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.post('/api/sessions/simulate');
      final newSession = LatestSession.fromJson(response.data as Map<String, dynamic>);
      state = AsyncValue.data(newSession);
      
      // Invalidate providers to force UI refresh
      _ref.invalidate(latestSessionProvider);
      _ref.invalidate(latestPredictionProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final sessionNotifierProvider = StateNotifierProvider<SessionNotifier, AsyncValue<LatestSession?>>((ref) {
  return SessionNotifier(ref);
});

class RaceDetails {
  final String raceName;
  final String round;
  final String circuitName;
  final String location;
  final String countryCode;
  final bool isCompleted;
  final String? winnerName;
  final String? winnerTeam;
  final int? totalLaps;
  final String? fastestLapTime;
  final String? fastestLapDriver;
  final String? fastestPitstopTeam;
  final String? fastestPitstopTime;
  final String? driverOfTheDay;
  final double? circuitLengthKm;
  final int? turns;
  final int? drsZones;

  RaceDetails({
    required this.raceName,
    required this.round,
    required this.circuitName,
    required this.location,
    required this.countryCode,
    required this.isCompleted,
    this.winnerName,
    this.winnerTeam,
    this.totalLaps,
    this.fastestLapTime,
    this.fastestLapDriver,
    this.fastestPitstopTeam,
    this.fastestPitstopTime,
    this.driverOfTheDay,
    this.circuitLengthKm,
    this.turns,
    this.drsZones,
  });

  factory RaceDetails.fromJson(Map<String, dynamic> json) {
    return RaceDetails(
      raceName: json['race_name'] as String? ?? '',
      round: json['round'] as String? ?? '',
      circuitName: json['circuit_name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      isCompleted: json['is_completed'] as bool? ?? false,
      winnerName: json['winner_name'] as String?,
      winnerTeam: json['winner_team'] as String?,
      totalLaps: json['total_laps'] as int?,
      fastestLapTime: json['fastest_lap_time'] as String?,
      fastestLapDriver: json['fastest_lap_driver'] as String?,
      fastestPitstopTeam: json['fastest_pitstop_team'] as String?,
      fastestPitstopTime: json['fastest_pitstop_time'] as String?,
      driverOfTheDay: json['driver_of_the_day'] as String?,
      circuitLengthKm: (json['circuit_length_km'] as num?)?.toDouble(),
      turns: json['turns'] as int?,
      drsZones: json['drs_zones'] as int?,
    );
  }
}

// FutureProvider for fetching official race details and highlights by race name
final raceDetailsProvider = FutureProvider.family<RaceDetails, String>((ref, raceName) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/sessions/race-details/$raceName');
  return RaceDetails.fromJson(response.data as Map<String, dynamic>);
});
