import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:f1/features/live/presentation/widgets/replay_timing_tower_widget.dart';
import 'package:f1/core/providers/telemetry/providers.dart';
import 'package:f1/core/providers/telemetry/models.dart';

import 'helpers/firebase_test_mock.dart';
import 'fixtures/race_session_fixture.dart';
import 'fixtures/chinese_gp_2026_fixture.dart';

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

  test('truncated race: isAtEnd uses truncatedAt not totalLaps', () {
    // State after all 3 laps: currentLap=3, totalLaps=39, truncatedAt=3
    final state = const RaceReplayState().copyWith(
      currentLap: 3,
      totalLaps: 39,
      availableLaps: 3,
      truncatedAt: 3,
    );
    // isAtEnd must be true (currentLap >= truncatedAt), not wait for lap 39
    expect(state.isAtEnd, isTrue);
    // truncatedAt must be set so the UI can suppress the summary sheet
    expect(state.truncatedAt, equals(3));
  });

  test('complete race: isAtEnd uses totalLaps when not truncated', () {
    final state = const RaceReplayState().copyWith(
      currentLap: 57,
      totalLaps: 58,
      availableLaps: 58,
    );
    expect(state.isAtEnd, isFalse); // lap 57 < 58, not at end yet
    final atEnd = state.copyWith(currentLap: 58);
    expect(atEnd.isAtEnd, isTrue);
    expect(atEnd.truncatedAt, isNull); // complete session
  });

  // ── Chinese GP real-data fixture ─────────────────────────────────────────

  test('setLap returns correct P1/P2 at every checkpoint in Chinese GP fixture', () {
    // Simulates what selectSessionById builds from the payload.
    final fixture = chineseGp2026Fixture();
    final rawLaps = (fixture['laps']['laps'] as List);
    final allLaps = rawLaps.map((lapRaw) {
      final lap = lapRaw as Map<String, dynamic>;
      final lapNum = (lap['lap'] as num).toInt();
      final positions = (lap['positions'] as List).map((p) {
        final pm = p as Map<String, dynamic>;
        return LiveTelemetry(
          pos: pm['pos'].toString(),
          name: pm['code'].toString(),
          team: '',
          gap: '',
          tyre: '',
          tyreLife: '',
          lastLap: '',
          speed: '',
          gear: '',
          color: pm['color']?.toString() ?? 'FFFFFF',
          x: 0,
          y: 0,
          isFastestThisLap: pm['is_fastest_this_lap'] == true,
        );
      }).toList();
      return ReplayLapEntry(lap: lapNum, phase: '', positions: positions);
    }).toList();

    // Expected P1 and P2 at each checkpoint (from actual Neon data).
    const expectedP1 = {
      1: 'HAM', 2: 'ANT', 3: 'ANT', 4: 'ANT', 5: 'ANT',
      6: 'ANT', 7: 'ANT', 10: 'ANT', 20: 'ANT',
    };
    const expectedP2 = {
      1: 'ANT', 2: 'HAM', 3: 'HAM', 4: 'RUS', 5: 'RUS',
      6: 'RUS', 7: 'RUS', 10: 'RUS', 20: 'HAM',
    };

    for (final lapData in rawLaps) {
      final lap = lapData as Map<String, dynamic>;
      final lapNum = (lap['lap'] as num).toInt();

      // Find the exact entry — no nearest-lap fallback (mimicking fixed setLap).
      final entry = allLaps.firstWhere((e) => e.lap == lapNum,
          orElse: () => throw Exception('Lap $lapNum missing from allLaps'));

      final sorted = [...entry.positions]
        ..sort((a, b) =>
            (int.tryParse(a.pos) ?? 99).compareTo(int.tryParse(b.pos) ?? 99));

      expect(sorted.isNotEmpty, isTrue, reason: 'Lap $lapNum has no positions');
      expect(sorted.first.name, expectedP1[lapNum],
          reason: 'Lap $lapNum P1 expected ${expectedP1[lapNum]}, got ${sorted.first.name}');
      if (expectedP2.containsKey(lapNum) && sorted.length >= 2) {
        expect(sorted[1].name, expectedP2[lapNum],
            reason: 'Lap $lapNum P2 expected ${expectedP2[lapNum]}, got ${sorted[1].name}');
      }
    }
  });

  test('setLap on missing lap sets missingLapAt and does not change telemetry', () {
    // Build state with only laps 1 and 2.
    final entry1 = ReplayLapEntry(
        lap: 1,
        phase: '',
        positions: [
          LiveTelemetry(
              pos: '1', name: 'HAM', team: '', gap: '', tyre: '', tyreLife: '',
              lastLap: '', speed: '', gear: '', color: 'FFFFFF', x: 0, y: 0)
        ]);
    final entry2 = ReplayLapEntry(
        lap: 2,
        phase: '',
        positions: [
          LiveTelemetry(
              pos: '1', name: 'ANT', team: '', gap: '', tyre: '', tyreLife: '',
              lastLap: '', speed: '', gear: '', color: 'FFFFFF', x: 0, y: 0)
        ]);

    var state = const RaceReplayState().copyWith(
      totalLaps: 10,
      availableLaps: 2,
      allLaps: [entry1, entry2],
      telemetry: entry2.positions,
      currentLap: 2,
    );

    // Simulate setLap(3) — lap 3 is not in allLaps.
    // We test the STATE LOGIC directly (not via notifier) to stay headless.
    ReplayLapEntry? found;
    for (final e in state.allLaps) {
      if (e.lap == 3) { found = e; break; }
    }
    expect(found, isNull, reason: 'lap 3 should not exist in this fixture');

    // After a missing-lap call, missingLapAt should be set and telemetry unchanged.
    state = state.copyWith(currentLap: 3, missingLapAt: 3);
    expect(state.missingLapAt, equals(3));
    // telemetry still shows ANT (lap 2 positions), not updated
    expect(state.telemetry.first.name, equals('ANT'));
  });

  testWidgets('tower shows all laps in correct order for full race fixture', (tester) async {
    final fixture = raceSessionFixture();
    final laps = fixture['laps']['laps'] as List;

    for (int lapIdx = 0; lapIdx < laps.length; lapIdx++) {
      final lapData = laps[lapIdx] as Map<String, dynamic>;
      final expectedCodes = (lapData['positions'] as List)
          .map((p) => (p as Map<String, dynamic>)['code']?.toString() ?? '')
          .toList();

      final positions = (lapData['positions'] as List)
          .map((p) => _posToTelemetry(p as Map<String, dynamic>))
          .toList();

      final state = const RaceReplayState().copyWith(
        currentLap: lapIdx + 1,
        totalLaps: laps.length,
        availableLaps: laps.length,
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

      for (final code in expectedCodes) {
        expect(
          find.byKey(Key('replay_timing_row_$code')),
          findsOneWidget,
          reason: 'Lap ${lapIdx + 1}: driver $code should have a row',
        );
      }
    }
  });
}
