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

class LiveNewsArticle {
  final String title;
  final String summary;
  final String url;
  final String source;
  final String publishedAt;
  final String imageUrl;
  final String timeAgo;
  final String category;

  LiveNewsArticle({
    required this.title,
    required this.summary,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.imageUrl,
    this.timeAgo = '',
    this.category = 'F1',
  });

  factory LiveNewsArticle.fromJson(Map<String, dynamic> json) {
    return LiveNewsArticle(
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'F1 News',
      publishedAt: json['published_at']?.toString() ?? 'Just now',
      imageUrl: json['image_url']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString() ?? '',
      category: json['category']?.toString() ?? 'F1',
    );
  }
}

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
      trackTemperature: json['track_temperature']?.toString() ?? '',
      airTemperature: json['air_temperature']?.toString() ?? '',
      humidity: json['humidity']?.toString() ?? '',
      windSpeed: json['wind_speed']?.toString() ?? '',
      windDirection: json['wind_direction']?.toString() ?? '',
      rainfall: json['rainfall'] as bool? ?? false,
      pressure: json['pressure']?.toString() ?? '',
      trackStatus: json['track_status']?.toString() ?? '',
      sessionName: json['session_name']?.toString() ?? '',
      circuitName: json['circuit_name']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
    );
  }
}

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
