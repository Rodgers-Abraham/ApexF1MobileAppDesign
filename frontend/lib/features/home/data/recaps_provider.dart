import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';

class RaceRecap {
  final String round;
  final String raceName;
  final String circuitName;
  final String country;
  final String date;
  final String winnerDriver;
  final String winnerTeam;
  final bool isCompleted;

  const RaceRecap({
    required this.round,
    required this.raceName,
    required this.circuitName,
    required this.country,
    required this.date,
    required this.winnerDriver,
    required this.winnerTeam,
    required this.isCompleted,
  });

  factory RaceRecap.fromJson(Map<String, dynamic> json) {
    return RaceRecap(
      round: json['round']?.toString() ?? '',
      raceName: json['race_name']?.toString() ?? '',
      circuitName: json['circuit_name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      winnerDriver: json['winner_driver']?.toString() ?? '',
      winnerTeam: json['winner_team']?.toString() ?? '',
      isCompleted: json['is_completed'] == true);
  }

  String get youtubeSearchUrl {
    final query = Uri.encodeComponent('$raceName 2026 race highlights F1');
    return 'https://www.youtube.com/results?search_query=$query';
  }

  String get qualiYoutubeUrl {
    final query = Uri.encodeComponent('$raceName 2026 qualifying highlights F1');
    return 'https://www.youtube.com/results?search_query=$query';
  }
}

final recapsProvider = FutureProvider.autoDispose<List<RaceRecap>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/recaps');
  final list = response.data as List;
  return list
      .map((i) => RaceRecap.fromJson(i as Map<String, dynamic>))
      .toList()
      .reversed
      .toList(); // Most recent first
});
