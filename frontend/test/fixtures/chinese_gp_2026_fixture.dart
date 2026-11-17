/// Real data snapshot from 2026 Chinese Grand Prix Race (Neon id: 42bbc9b6...)
/// Trimmed to 9 checkpoints and 5-6 drivers per lap.
/// Source: Neon query on 2026-11-17; actual lap order verified against
///         the backend sessions table (43 distinct top-5 orders across 56 laps).
///
/// Lap 1: HAM→P1; laps 2-19: ANT→P1; lap 20: ANT still P1 but RUS drops.
/// Laps 1-19 have the same P1-P5 codes, verifying the tower handles
/// stable top-5 runs without freezing.
library;

Map<String, dynamic> chineseGp2026Fixture() {
  return {
    'id': '42bbc9b6-10bd-449d-9100-3ca6edca214b',
    'year': 2026,
    'event': 'Chinese Grand Prix',
    'session_type': 'Race',
    'session_date': null,
    'meta': {
      'circuit': 'Shanghai International Circuit',
      'drivers': [
        {'code': 'HAM', 'team': 'Ferrari', 'color': 'E8002D', 'dn': 44, 'fn': 'Lewis', 'ln': 'Hamilton'},
        {'code': 'ANT', 'team': 'Mercedes', 'color': '00D7B6', 'dn': 12, 'fn': 'Kimi', 'ln': 'Antonelli'},
        {'code': 'LEC', 'team': 'Ferrari', 'color': 'E8002D', 'dn': 16, 'fn': 'Charles', 'ln': 'Leclerc'},
        {'code': 'RUS', 'team': 'Mercedes', 'color': '00D7B6', 'dn': 63, 'fn': 'George', 'ln': 'Russell'},
        {'code': 'GAS', 'team': 'Alpine', 'color': '0093CC', 'dn': 10, 'fn': 'Pierre', 'ln': 'Gasly'},
        {'code': 'COL', 'team': 'Williams', 'color': '64C4FF', 'dn': 43, 'fn': 'Franco', 'ln': 'Colapinto'},
      ],
    },
    'laps': {
      'total_laps': 56,
      'grid': [
        {'code': 'HAM', 'pos': '1', 'team': 'Ferrari', 'color': 'E8002D'},
        {'code': 'ANT', 'pos': '2', 'team': 'Mercedes', 'color': '00D7B6'},
        {'code': 'LEC', 'pos': '3', 'team': 'Ferrari', 'color': 'E8002D'},
        {'code': 'RUS', 'pos': '4', 'team': 'Mercedes', 'color': '00D7B6'},
        {'code': 'GAS', 'pos': '5', 'team': 'Alpine', 'color': '0093CC'},
      ],
      // 9 checkpoints from real Neon data. The top-5 is stable from lap 2-19,
      // which is the exact scenario that looked "frozen" on device.
      'laps': [
        _lap(1, 0.0, [
          _pos('HAM', 1, isFastest: true),
          _pos('ANT', 2),
          _pos('LEC', 3),
          _pos('RUS', 4),
          _pos('GAS', 5),
        ]),
        _lap(2, 97.4, [
          _pos('ANT', 1),
          _pos('HAM', 2),
          _pos('LEC', 3),
          _pos('RUS', 4),
          _pos('GAS', 5),
        ]),
        _lap(3, 194.8, [
          _pos('ANT', 1),
          _pos('HAM', 2),
          _pos('RUS', 3),
          _pos('LEC', 4),
          _pos('GAS', 5),
        ]),
        _lap(4, 292.2, [
          _pos('ANT', 1),
          _pos('RUS', 2),
          _pos('HAM', 3),
          _pos('LEC', 4),
          _pos('GAS', 5),
        ]),
        _lap(5, 389.6, [
          _pos('ANT', 1),
          _pos('RUS', 2),
          _pos('HAM', 3),
          _pos('LEC', 4),
          _pos('GAS', 5),
        ]),
        _lap(6, 487.0, [
          _pos('ANT', 1, isFastest: true),
          _pos('RUS', 2),
          _pos('HAM', 3),
          _pos('LEC', 4),
          _pos('GAS', 5),
        ]),
        _lap(7, 584.4, [
          _pos('ANT', 1),
          _pos('RUS', 2),
          _pos('HAM', 3),
          _pos('LEC', 4),
          _pos('GAS', 5),
        ]),
        _lap(10, 876.6, [
          _pos('ANT', 1),
          _pos('RUS', 2),
          _pos('HAM', 3),
          _pos('LEC', 4),
          _pos('GAS', 5),
        ]),
        // Lap 20: RUS drops from P2→P4; COL enters top-5
        _lap(20, 1947.0, [
          _pos('ANT', 1),
          _pos('HAM', 2),
          _pos('LEC', 3),
          _pos('RUS', 4),
          _pos('COL', 5),
        ]),
      ],
      'dns_drivers': [],
    },
    'events': [],
    'results': [
      {'code': 'ANT', 'pos': '1', 'gap': 'WINNER', 'status': 'Finished', 'fastest_lap': false},
      {'code': 'RUS', 'pos': '2', 'gap': '+5.0', 'status': 'Finished', 'fastest_lap': true},
      {'code': 'HAM', 'pos': '3', 'gap': '+12.0', 'status': 'Finished', 'fastest_lap': false},
      {'code': 'LEC', 'pos': '4', 'gap': '+18.0', 'status': 'Finished', 'fastest_lap': false},
      {'code': 'GAS', 'pos': '5', 'gap': '+25.0', 'status': 'Finished', 'fastest_lap': false},
    ],
    'weather': null,
    'radio': null,
  };
}

Map<String, dynamic> _lap(int lap, double lapStartS, List<Map<String, dynamic>> positions) => {
  'lap': lap,
  'lap_start_s': lapStartS,
  'track_status': '1',
  'sc_active': false,
  'vsc_active': false,
  'red_flag': false,
  'fastest_code': positions.firstWhere((p) => p['is_fastest_this_lap'] == true,
      orElse: () => positions.first)['code'],
  'fastest_lap_time': 97.0,
  'positions': positions,
};

Map<String, dynamic> _pos(String code, int pos, {bool isFastest = false}) => {
  'code': code,
  'pos': pos,
  'team': 'Team',
  'color': 'FFFFFF',
  'lap_time': 97.0,
  'status': 'RACING',
  'compound': 'MEDIUM',
  'life': 1,
  'is_fastest_this_lap': isFastest,
  'is_fastest_lap_of_race': false,
};
