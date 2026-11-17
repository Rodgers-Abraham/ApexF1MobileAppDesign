import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:f1/features/live/presentation/widgets/replay_timing_tower_widget.dart';
import 'package:f1/core/providers/telemetry/providers.dart';
import 'package:f1/core/providers/telemetry/models.dart';

import 'helpers/firebase_test_mock.dart';
import 'fixtures/race_session_fixture.dart';

// Helper: build LiveTelemetry from a fixture position map.
LiveTelemetry _posToTelemetry(Map<String, dynamic> p) {
  final ltRaw = p['lap_time'];
  String lapTimeStr = '';
  if (ltRaw is num && ltRaw > 0) {
    final secs = ltRaw.toDouble();
    final mins = secs ~/ 60;
    final remaining = secs - mins * 60;
    lapTimeStr = '$mins:${remaining.toStringAsFixed(3).padLeft(6, '0')}';
  }
  return LiveTelemetry(
    pos: p['pos']?.toString() ?? '',
    name: p['code']?.toString() ?? '',
    team: p['team']?.toString() ?? '',
    gap: '',
    tyre: p['compound']?.toString() ?? '',
    tyreLife: p['life']?.toString() ?? '',
    lastLap: lapTimeStr,
    speed: '',
    gear: '',
    color: p['color']?.toString() ?? 'FFFFFF',
    x: 0.0,
    y: 0.0,
    status: p['status']?.toString() ?? 'RACING',
    isFastestThisLap: p['is_fastest_this_lap'] as bool? ?? false,
    isFastestLap: p['is_fastest_lap_of_race'] as bool? ?? false,
  );
}

void main() {
  setUpAll(setupFirebaseForTests);

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
  });

  testWidgets(
      'ReplayTimingTowerWidget renders all driver rows and penalty icon',
      (tester) async {
    final fixture = raceSessionFixture();
    final lap2 = (fixture['laps']['laps'] as List)[1] as Map<String, dynamic>;
    final positions = (lap2['positions'] as List)
        .map((p) => _posToTelemetry(p as Map<String, dynamic>))
        .toList();

    final state = const RaceReplayState().copyWith(
      currentLap: 2,
      totalLaps: 3,
      telemetry: positions,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReplayTimingTowerWidget(
            replayState: state,
            // LEC received a penalty on lap 2
            penaltyLaps: const {'LEC': 2},
          ),
        ),
      ),
    );
    await tester.pump();

    // All 5 driver rows must be present
    for (final code in ['VER', 'NOR', 'LEC', 'HAM', 'RUS']) {
      expect(find.byKey(Key('replay_timing_row_$code')), findsOneWidget,
          reason: 'Row for $code should be rendered');
    }

    // Penalty icon on LEC only
    expect(find.byKey(const Key('replay_penalty_icon_LEC')), findsOneWidget);
    expect(find.byKey(const Key('replay_penalty_icon_VER')), findsNothing);
    expect(find.byKey(const Key('replay_penalty_icon_NOR')), findsNothing);
  });

  testWidgets('ReplayTimingTowerWidget shows DNF badge for HAM on lap 3',
      (tester) async {
    final fixture = raceSessionFixture();
    final lap3 = (fixture['laps']['laps'] as List)[2] as Map<String, dynamic>;
    final positions = (lap3['positions'] as List)
        .map((p) => _posToTelemetry(p as Map<String, dynamic>))
        .toList();

    final state = const RaceReplayState().copyWith(
      currentLap: 3,
      totalLaps: 3,
      telemetry: positions,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReplayTimingTowerWidget(
            replayState: state,
            penaltyLaps: const {},
          ),
        ),
      ),
    );
    await tester.pump();

    // HAM DNF badge visible; VER has no DNF badge
    expect(find.byKey(const Key('replay_dnf_badge_HAM')), findsOneWidget);
    expect(find.byKey(const Key('replay_dnf_badge_VER')), findsNothing);
  });
}
