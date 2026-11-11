import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/utils/api_config.dart';

class SessionEntry {
  final String id;
  final String sessionType;
  final String? sessionDate;

  const SessionEntry({required this.id, required this.sessionType, this.sessionDate});

  factory SessionEntry.fromJson(Map<String, dynamic> j) => SessionEntry(
        id: j['id']?.toString() ?? '',
        sessionType: j['session_type']?.toString() ?? '',
        sessionDate: j['session_date']?.toString(),
      );
}

class EventSessions {
  final int year;
  final String event;
  final String eventName;
  final String country;
  final List<SessionEntry> sessions;

  const EventSessions({
    required this.year,
    required this.event,
    required this.eventName,
    required this.country,
    required this.sessions,
  });

  factory EventSessions.fromJson(Map<String, dynamic> j) => EventSessions(
        year: (j['year'] as num?)?.toInt() ?? 0,
        event: j['event']?.toString() ?? '',
        eventName: j['event_name']?.toString() ?? '',
        country: j['country']?.toString() ?? '',
        sessions: (j['sessions'] as List?)
                ?.map((s) => SessionEntry.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );

  static String sessionTypeLabel(String type) {
    switch (type) {
      case 'P1':
        return 'FP1';
      case 'P2':
        return 'FP2';
      case 'P3':
        return 'FP3';
      case 'Q':
        return 'QUALI';
      case 'SQ':
        return 'SQ';
      case 'Sprint':
        return 'SPRINT';
      case 'Race':
        return 'RACE';
      default:
        return type;
    }
  }
}

final allSessionsProvider =
    FutureProvider.autoDispose<List<EventSessions>>((ref) async {
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final resp = await dio.get('/api/timing/sessions');
  final list = resp.data as List;
  return list
      .map((e) => EventSessions.fromJson(e as Map<String, dynamic>))
      .toList();
});

final sessionDataProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, sessionId) async {
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final resp = await dio.get('/api/timing/sessions/$sessionId/data');
  return resp.data as Map<String, dynamic>;
});
