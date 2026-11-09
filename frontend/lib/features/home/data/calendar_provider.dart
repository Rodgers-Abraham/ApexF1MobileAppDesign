import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';

class RaceSession {
  final String name; // FP1, FP2, FP3, Qualifying, Race
  final DateTime dateTime;

  const RaceSession({required this.name, required this.dateTime});

  factory RaceSession.fromJson(Map<String, dynamic> json) {
    return RaceSession(
      name: json['name']?.toString() ?? '',
      dateTime: DateTime.tryParse(json['datetime']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get isQuali => name == 'Qualifying';
  bool get isRace => name == 'Race';
}

class RaceEvent {
  final String name;
  final String circuit;
  final String countryCode;
  final DateTime date;
  final String round;
  final double lengthKm;
  final int turns;
  final int drsZones;
  final List<RaceSession> sessions;

  const RaceEvent({
    required this.name,
    required this.circuit,
    required this.countryCode,
    required this.date,
    required this.round,
    this.lengthKm = 5.3,
    this.turns = 16,
    this.drsZones = 2,
    this.sessions = const [],
  });

  /// Approximate qualifying datetime (session data or fallback: race day - 1 at 14:00)
  DateTime get qualiDateTime {
    for (final s in sessions) {
      if (s.isQuali) return s.dateTime;
    }
    return DateTime(date.year, date.month, date.day - 1, 14, 0);
  }

  /// Predictions lock 30 minutes before qualifying
  DateTime get predictionsLockTime => qualiDateTime.subtract(const Duration(minutes: 30));

  bool get predictionsLocked => DateTime.now().isAfter(predictionsLockTime);

  /// Next upcoming session within this race weekend
  RaceSession? nextSession(DateTime now) {
    for (final s in sessions) {
      if (s.dateTime.isAfter(now)) return s;
    }
    return null;
  }

  factory RaceEvent.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'] as List? ?? [];
    return RaceEvent(
      name: json['name']?.toString() ?? '',
      circuit: json['circuit']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      round: json['round']?.toString() ?? '',
      lengthKm: (json['length_km'] as num?)?.toDouble() ?? 5.3,
      turns: (json['turns'] as num?)?.toInt() ?? 16,
      drsZones: (json['drs_zones'] as num?)?.toInt() ?? 2,
      sessions: rawSessions
          .map((s) => RaceSession.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

final calendarProvider = FutureProvider.autoDispose<List<RaceEvent>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/calendar');
  final list = response.data as List;
  return list.map((i) => RaceEvent.fromJson(i as Map<String, dynamic>)).toList();
});

final nextRaceProvider = Provider.autoDispose<RaceEvent?>((ref) {
  final calendarAsync = ref.watch(calendarProvider);
  return calendarAsync.whenData((calendar) {
    final now = DateTime.now();
    for (final r in calendar) {
      if (r.date.isAfter(now)) return r;
    }
    return calendar.isNotEmpty ? calendar.last : null;
  }).value;
});

/// Returns the very next session across all races — could be FP1, Qualifying, Race, etc.
final nextSessionProvider = Provider.autoDispose<({RaceEvent race, RaceSession session})?>((ref) {
  final calendarAsync = ref.watch(calendarProvider);
  return calendarAsync.whenData((calendar) {
    final now = DateTime.now();
    for (final race in calendar) {
      for (final s in race.sessions) {
        if (s.dateTime.isAfter(now)) {
          return (race: race, session: s);
        }
      }
    }
    return null;
  }).value;
});

final circuitHistoryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, raceName) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/history/circuit/$raceName');
  return response.data as Map<String, dynamic>;
});

String monthAbbrev(int month) {
  const names = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return names[month];
}

String getCountryFlag(String code) {
  switch (code.toUpperCase()) {
    case 'AUS': return '🇦🇺';
    case 'CHN': return '🇨🇳';
    case 'JPN': return '🇯🇵';
    case 'USA': return '🇺🇸';
    case 'CAN': return '🇨🇦';
    case 'MCO': return '🇲🇨';
    case 'ESP': return '🇪🇸';
    case 'AUT': return '🇦🇹';
    case 'GBR': return '🇬🇧';
    case 'BEL': return '🇧🇪';
    case 'HUN': return '🇭🇺';
    case 'NLD': return '🇳🇱';
    case 'ITA': return '🇮🇹';
    case 'AZE': return '🇦🇿';
    case 'BHR': return '🇧🇭';
    case 'SGP': return '🇸🇬';
    case 'MEX': return '🇲🇽';
    case 'BRA': return '🇧🇷';
    case 'QAT': return '🇶🇦';
    case 'UAE': return '🇦🇪';
    default: return '🏁';
  }
}

String getCircuitAssetPath(String raceName) {
  final nameLower = raceName.toLowerCase();
  if (nameLower.contains('australian') || nameLower.contains('albert')) return 'assets/circuits/albert_park.png';
  if (nameLower.contains('chinese') || nameLower.contains('shanghai')) return 'assets/circuits/shanghai.png';
  if (nameLower.contains('japanese') || nameLower.contains('suzuka')) return 'assets/circuits/suzuka.png';
  if (nameLower.contains('bahrain') || nameLower.contains('sakhir')) return 'assets/circuits/bahrain.png';
  if (nameLower.contains('saudi') || nameLower.contains('jeddah')) return 'assets/circuits/jeddah.png';
  if (nameLower.contains('miami')) return 'assets/circuits/miami.png';
  if (nameLower.contains('emilia') || nameLower.contains('imola')) return 'assets/circuits/imola.png';
  if (nameLower.contains('monaco')) return 'assets/circuits/monaco.png';
  if (nameLower.contains('spanish') || nameLower.contains('barcelona') || nameLower.contains('catalunya')) return 'assets/circuits/catalunya.png';
  if (nameLower.contains('canadian') || nameLower.contains('montreal') || nameLower.contains('villeneuve')) return 'assets/circuits/villeneuve.png';
  if (nameLower.contains('austrian') || nameLower.contains('spielberg') || nameLower.contains('red bull')) return 'assets/circuits/red_bull_ring.png';
  if (nameLower.contains('british') || nameLower.contains('silverstone')) return 'assets/circuits/silverstone.png';
  if (nameLower.contains('belgian') || nameLower.contains('spa')) return 'assets/circuits/spa.png';
  if (nameLower.contains('hungarian') || nameLower.contains('hungaroring')) return 'assets/circuits/hungaroring.png';
  if (nameLower.contains('dutch') || nameLower.contains('zandvoort')) return 'assets/circuits/zandvoort.png';
  if (nameLower.contains('italian') || nameLower.contains('monza')) return 'assets/circuits/monza.png';
  if (nameLower.contains('azerbaijan') || nameLower.contains('baku')) return 'assets/circuits/baku.png';
  if (nameLower.contains('singapore') || nameLower.contains('marina')) return 'assets/circuits/marina_bay.png';
  if (nameLower.contains('states') || nameLower.contains('cota') || nameLower.contains('austin') || nameLower.contains('americas')) return 'assets/circuits/americas.png';
  if (nameLower.contains('mexico') || nameLower.contains('rodriguez')) return 'assets/circuits/rodriguez.png';
  if (nameLower.contains('paulo') || nameLower.contains('brazil') || nameLower.contains('interlagos')) return 'assets/circuits/interlagos.png';
  if (nameLower.contains('vegas')) return 'assets/circuits/vegas.png';
  if (nameLower.contains('qatar') || nameLower.contains('lusail') || nameLower.contains('losail')) return 'assets/circuits/losail.png';
  if (nameLower.contains('abu dhabi') || nameLower.contains('yas marina')) return 'assets/circuits/yas_marina.png';
  return 'assets/circuits/monaco.png';
}
