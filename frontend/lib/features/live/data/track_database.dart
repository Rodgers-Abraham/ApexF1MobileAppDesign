import 'package:flutter/material.dart';
import 'dart:ui';

// FIA Formula 1 Circuit Database (2026 Calendar)
// 24 circuits with track shapes, sector boundaries, corner names, and DRS zones.
// Track points are normalised to 0.0-1.0 for any CustomPaint size.

class CircuitCorner {
  final String name;
  final int number;
  final Offset apex;
  final String type;

  const CircuitCorner({required this.name, required this.number, required this.apex, required this.type});
}

class F1Circuit {
  final String name;
  final String location;
  final String countryCode;
  final double lengthKm;
  final List<Offset> trackPoints;
  final List<Color> sectorColors;
  final List<CircuitCorner> corners;
  final List<({double start, double end})> drsZones;

  const F1Circuit({
    required this.name,
    required this.location,
    required this.countryCode,
    required this.lengthKm,
    required this.trackPoints,
    required this.sectorColors,
    required this.corners,
    required this.drsZones,
  });
}

Offset _p(double x, double y) => Offset(x, y);

const _green = Color(0xFF4CAF50);
const _blue = Color(0xFF2196F3);
const _amber = Color(0xFFFFB300);
const _palette = [_green, _blue, _amber];

// ── Helper to build a generic track from minimal info ──
F1Circuit _makeCircuit({
  required String name,
  required String location,
  required String countryCode,
  required double lengthKm,
  required List<(double, double)> points,
  required List<String> cornerNames,
  required List<(double, double)> drs,
}) {
  final List<CircuitCorner> corners = [];
  for (int i = 0; i < cornerNames.length; i++) {
    final px = points[(i * 2 + 1) % points.length].$1;
    final py = points[(i * 2 + 1) % points.length].$2;
    corners.add(CircuitCorner(
      name: cornerNames[i],
      number: i + 1,
      apex: Offset(px, py),
      type: (i % 2 == 0) ? 'right' : 'left',
    ));
  }
  final trackPoints = points.map((pt) => Offset(pt.$1, pt.$2)).toList();
  final drsZones = drs.map((z) => (start: z.$1, end: z.$2)).toList();
  return F1Circuit(
    name: name,
    location: location,
    countryCode: countryCode,
    lengthKm: lengthKm,
    trackPoints: trackPoints,
    sectorColors: _palette,
    corners: corners,
    drsZones: drsZones,
  );
}

// ─────────────────────────────────────────────────────────────
// CIRCUIT DEFINITIONS
// ─────────────────────────────────────────────────────────────

// R01 – Bahrain International Circuit, Sakhir
final circuitBahrain = _makeCircuit(
  name: 'Bahrain Grand Prix',
  location: 'Sakhir',
  countryCode: 'BHR',
  lengthKm: 5.412,
  points: [(0.15, 0.78), (0.55, 0.78), (0.65, 0.70), (0.68, 0.60), (0.62, 0.52), (0.48, 0.48), (0.58, 0.38), (0.53, 0.28), (0.42, 0.22), (0.32, 0.28), (0.28, 0.38), (0.22, 0.48), (0.12, 0.55), (0.08, 0.68), (0.10, 0.78)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12', 'Turn 13', 'Turn 14', 'Turn 15'],
  drs: [(0.65, 0.10), (0.07, 0.15)],
);

// R02 – Jeddah Street Circuit, Jeddah
final circuitSaudiArabia = _makeCircuit(
  name: 'Saudi Arabian Grand Prix',
  location: 'Jeddah',
  countryCode: 'KSA',
  lengthKm: 6.174,
  points: [(0.10, 0.75), (0.40, 0.75), (0.50, 0.65), (0.55, 0.55), (0.60, 0.45), (0.55, 0.35), (0.45, 0.30), (0.35, 0.35), (0.30, 0.45), (0.25, 0.55), (0.20, 0.62), (0.15, 0.70)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11'],
  drs: [(0.55, 0.15), (0.70, 0.10)],
);

// R03 – Albert Park Circuit, Melbourne
final circuitAustralia = _makeCircuit(
  name: 'Australian Grand Prix',
  location: 'Melbourne',
  countryCode: 'AUS',
  lengthKm: 5.303,
  points: [(0.15, 0.78), (0.52, 0.78), (0.62, 0.72), (0.68, 0.62), (0.62, 0.52), (0.50, 0.48), (0.38, 0.45), (0.28, 0.42), (0.22, 0.35), (0.20, 0.28), (0.12, 0.25), (0.08, 0.35), (0.10, 0.48), (0.12, 0.60), (0.14, 0.72)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12', 'Turn 13', 'Turn 14'],
  drs: [(0.62, 0.08), (0.85, 0.14)],
);

// R04 – Suzuka International Racing Course, Suzuka
final circuitJapan = _makeCircuit(
  name: 'Japanese Grand Prix',
  location: 'Suzuka',
  countryCode: 'JPN',
  lengthKm: 5.807,
  points: [(0.50, 0.85), (0.30, 0.72), (0.20, 0.58), (0.25, 0.42), (0.38, 0.30), (0.55, 0.25), (0.70, 0.30), (0.80, 0.42), (0.78, 0.55), (0.68, 0.68), (0.55, 0.78), (0.50, 0.85)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10'],
  drs: [(0.72, 0.48)],
);

// R05 – Shanghai International Circuit, Shanghai
final circuitChina = _makeCircuit(
  name: 'Chinese Grand Prix',
  location: 'Shanghai',
  countryCode: 'CHN',
  lengthKm: 5.451,
  points: [(0.15, 0.82), (0.52, 0.82), (0.58, 0.72), (0.52, 0.62), (0.42, 0.55), (0.50, 0.45), (0.55, 0.35), (0.50, 0.25), (0.35, 0.22), (0.25, 0.30), (0.18, 0.42), (0.12, 0.58), (0.08, 0.70), (0.10, 0.80)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12', 'Turn 13'],
  drs: [(0.60, 0.12), (0.78, 0.15)],
);

// R06 – Miami International Autodrome, Miami
final circuitMiami = _makeCircuit(
  name: 'Miami Grand Prix',
  location: 'Miami',
  countryCode: 'USA',
  lengthKm: 5.412,
  points: [(0.15, 0.75), (0.50, 0.75), (0.65, 0.70), (0.72, 0.62), (0.68, 0.52), (0.55, 0.45), (0.60, 0.35), (0.55, 0.25), (0.42, 0.20), (0.30, 0.25), (0.25, 0.35), (0.20, 0.45), (0.12, 0.55), (0.08, 0.65), (0.10, 0.75)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12', 'Turn 13', 'Turn 14', 'Turn 15'],
  drs: [(0.55, 0.15), (0.75, 0.10)],
);

// R07 – Autodromo Enzo e Dino Ferrari, Imola
final circuitImola = _makeCircuit(
  name: 'Emilia Romagna Grand Prix',
  location: 'Imola',
  countryCode: 'ITA',
  lengthKm: 4.909,
  points: [(0.15, 0.75), (0.50, 0.75), (0.62, 0.68), (0.58, 0.58), (0.48, 0.50), (0.38, 0.45), (0.28, 0.40), (0.20, 0.35), (0.15, 0.45), (0.12, 0.58), (0.08, 0.68), (0.10, 0.75)],
  cornerNames: ['Tamburello', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12'],
  drs: [(0.58, 0.15), (0.78, 0.12)],
);

// R08 – Circuit de Monaco, Monte Carlo
final circuitMonaco = _makeCircuit(
  name: 'Monaco Grand Prix',
  location: 'Monaco',
  countryCode: 'MCO',
  lengthKm: 3.337,
  points: [(0.50, 0.82), (0.72, 0.78), (0.82, 0.68), (0.85, 0.55), (0.78, 0.40), (0.68, 0.30), (0.55, 0.22), (0.42, 0.18), (0.28, 0.22), (0.18, 0.30), (0.12, 0.40), (0.15, 0.52), (0.22, 0.62), (0.32, 0.70), (0.42, 0.75)],
  cornerNames: ['Sainte Devote', 'Beau Rivage', 'Casino', 'Mirabeau', 'Portier', 'Tunnel', 'Nouvelle Chicane', 'Tabac', 'Swimming Pool', 'La Rascasse', 'Anthony Noghes', 'Turn 16', 'Turn 17', 'Turn 18', 'Turn 19'],
  drs: [(0.52, 0.72)],
);

// R09 – Circuit de Barcelona-Catalunya, Barcelona
final circuitSpain = _makeCircuit(
  name: 'Spanish Grand Prix',
  location: 'Barcelona',
  countryCode: 'ESP',
  lengthKm: 4.675,
  points: [(0.12, 0.78), (0.50, 0.78), (0.62, 0.72), (0.68, 0.62), (0.60, 0.52), (0.48, 0.48), (0.35, 0.45), (0.25, 0.40), (0.18, 0.32), (0.12, 0.42), (0.08, 0.55), (0.10, 0.68), (0.12, 0.75)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12', 'Turn 13'],
  drs: [(0.58, 0.12), (0.80, 0.15)],
);

// R10 – Circuit Gilles Villeneuve, Montreal
final circuitCanada = _makeCircuit(
  name: 'Canadian Grand Prix',
  location: 'Montreal',
  countryCode: 'CAN',
  lengthKm: 4.361,
  points: [(0.15, 0.82), (0.55, 0.82), (0.68, 0.75), (0.72, 0.65), (0.62, 0.55), (0.52, 0.50), (0.40, 0.45), (0.35, 0.38), (0.28, 0.32), (0.22, 0.40), (0.18, 0.50), (0.14, 0.62), (0.12, 0.72)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12', 'Turn 13'],
  drs: [(0.55, 0.30)],
);

// R11 – Red Bull Ring, Spielberg
final circuitAustria = _makeCircuit(
  name: 'Austrian Grand Prix',
  location: 'Spielberg',
  countryCode: 'AUT',
  lengthKm: 4.318,
  points: [(0.12, 0.78), (0.72, 0.78), (0.85, 0.65), (0.82, 0.48), (0.68, 0.35), (0.50, 0.28), (0.30, 0.25), (0.18, 0.35), (0.15, 0.50), (0.13, 0.65)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10'],
  drs: [(0.48, 0.12), (0.68, 0.15)],
);

// R12 – Silverstone Circuit, Silverstone
final circuitBritain = _makeCircuit(
  name: 'British Grand Prix',
  location: 'Silverstone',
  countryCode: 'GBR',
  lengthKm: 5.891,
  points: [(0.18, 0.65), (0.45, 0.75), (0.58, 0.72), (0.72, 0.60), (0.85, 0.50), (0.88, 0.35), (0.80, 0.22), (0.65, 0.18), (0.48, 0.20), (0.35, 0.25), (0.25, 0.32), (0.18, 0.42), (0.14, 0.52)],
  cornerNames: ['Copse', 'Maggots', 'Becketts', 'Chapel', 'Stowe', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12', 'Turn 13'],
  drs: [(0.65, 0.12), (0.88, 0.15)],
);

// R13 – Circuit de Spa-Francorchamps, Spa
final circuitBelgium = _makeCircuit(
  name: 'Belgian Grand Prix',
  location: 'Spa',
  countryCode: 'BEL',
  lengthKm: 7.004,
  points: [(0.18, 0.68), (0.52, 0.68), (0.72, 0.62), (0.82, 0.52), (0.85, 0.40), (0.80, 0.28), (0.65, 0.20), (0.48, 0.18), (0.32, 0.22), (0.20, 0.30), (0.15, 0.42), (0.12, 0.55)],
  cornerNames: ['La Source', 'Turn 2', 'Eau Rouge', 'Raidillon', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12'],
  drs: [(0.42, 0.12), (0.65, 0.15)],
);

// R14 – Hungaroring, Budapest
final circuitHungary = _makeCircuit(
  name: 'Hungarian Grand Prix',
  location: 'Budapest',
  countryCode: 'HUN',
  lengthKm: 4.381,
  points: [(0.22, 0.78), (0.55, 0.78), (0.68, 0.70), (0.62, 0.58), (0.48, 0.50), (0.38, 0.42), (0.28, 0.35), (0.20, 0.40), (0.15, 0.52), (0.18, 0.65), (0.22, 0.72)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11'],
  drs: [(0.55, 0.15), (0.78, 0.10)],
);

// R15 – Circuit Zandvoort, Zandvoort
final circuitDutch = _makeCircuit(
  name: 'Dutch Grand Prix',
  location: 'Zandvoort',
  countryCode: 'NLD',
  lengthKm: 4.259,
  points: [(0.15, 0.78), (0.55, 0.78), (0.72, 0.68), (0.78, 0.55), (0.70, 0.40), (0.55, 0.30), (0.38, 0.25), (0.22, 0.30), (0.15, 0.42), (0.12, 0.55), (0.10, 0.68), (0.13, 0.75)],
  cornerNames: ['Tarzan', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12'],
  drs: [(0.55, 0.15)],
);

// R16 – Autodromo Nazionale Monza, Monza
final circuitItaly = _makeCircuit(
  name: 'Italian Grand Prix',
  location: 'Monza',
  countryCode: 'ITA',
  lengthKm: 5.793,
  points: [(0.10, 0.82), (0.78, 0.82), (0.88, 0.68), (0.85, 0.50), (0.78, 0.35), (0.62, 0.25), (0.45, 0.22), (0.30, 0.28), (0.20, 0.38), (0.15, 0.50), (0.12, 0.62), (0.10, 0.75)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12'],
  drs: [(0.50, 0.12), (0.72, 0.15)],
);

// R17 – Baku City Circuit, Baku
final circuitAzerbaijan = _makeCircuit(
  name: 'Azerbaijan Grand Prix',
  location: 'Baku',
  countryCode: 'AZE',
  lengthKm: 6.003,
  points: [(0.12, 0.82), (0.82, 0.82), (0.88, 0.68), (0.80, 0.50), (0.72, 0.35), (0.58, 0.25), (0.42, 0.22), (0.28, 0.30), (0.22, 0.42), (0.18, 0.55), (0.15, 0.68), (0.13, 0.78)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12'],
  drs: [(0.50, 0.12), (0.72, 0.15)],
);

// R18 – Marina Bay Street Circuit, Singapore
final circuitSingapore = _makeCircuit(
  name: 'Singapore Grand Prix',
  location: 'Singapore',
  countryCode: 'SGP',
  lengthKm: 5.063,
  points: [(0.15, 0.78), (0.55, 0.78), (0.68, 0.70), (0.72, 0.60), (0.65, 0.50), (0.52, 0.42), (0.38, 0.38), (0.25, 0.42), (0.18, 0.52), (0.15, 0.62), (0.13, 0.70)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11'],
  drs: [(0.55, 0.15), (0.78, 0.10)],
);

// R19 – Circuit of the Americas, Austin
final circuitUSA = _makeCircuit(
  name: 'United States Grand Prix',
  location: 'Austin',
  countryCode: 'USA',
  lengthKm: 5.513,
  points: [(0.18, 0.75), (0.55, 0.75), (0.68, 0.65), (0.75, 0.52), (0.68, 0.38), (0.52, 0.28), (0.35, 0.25), (0.22, 0.35), (0.15, 0.48), (0.13, 0.60), (0.15, 0.72)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11'],
  drs: [(0.55, 0.15), (0.78, 0.10)],
);

// R20 – Autodromo Hermanos Rodriguez, Mexico City
final circuitMexico = _makeCircuit(
  name: 'Mexico City Grand Prix',
  location: 'Mexico City',
  countryCode: 'MEX',
  lengthKm: 4.304,
  points: [(0.12, 0.78), (0.55, 0.78), (0.68, 0.70), (0.75, 0.60), (0.70, 0.48), (0.55, 0.40), (0.38, 0.35), (0.25, 0.38), (0.18, 0.48), (0.15, 0.60), (0.13, 0.70)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11'],
  drs: [(0.45, 0.12), (0.68, 0.15)],
);

// R21 – Interlagos, Sao Paulo
final circuitBrazil = _makeCircuit(
  name: 'Brazilian Grand Prix',
  location: 'Sao Paulo',
  countryCode: 'BRA',
  lengthKm: 4.309,
  points: [(0.15, 0.78), (0.50, 0.78), (0.68, 0.68), (0.72, 0.55), (0.62, 0.42), (0.48, 0.35), (0.32, 0.32), (0.22, 0.40), (0.18, 0.52), (0.15, 0.65)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10'],
  drs: [(0.40, 0.10), (0.60, 0.15)],
);

// R22 – Las Vegas Strip Circuit, Las Vegas
final circuitLasVegas = _makeCircuit(
  name: 'Las Vegas Grand Prix',
  location: 'Las Vegas',
  countryCode: 'USA',
  lengthKm: 6.201,
  points: [(0.10, 0.82), (0.82, 0.82), (0.88, 0.65), (0.82, 0.45), (0.70, 0.32), (0.52, 0.25), (0.35, 0.28), (0.22, 0.38), (0.15, 0.52), (0.13, 0.65), (0.12, 0.75)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11'],
  drs: [(0.55, 0.15), (0.78, 0.10)],
);

// R23 – Lusail International Circuit, Lusail
final circuitQatar = _makeCircuit(
  name: 'Qatar Grand Prix',
  location: 'Lusail',
  countryCode: 'QAT',
  lengthKm: 5.418,
  points: [(0.12, 0.78), (0.55, 0.78), (0.70, 0.68), (0.78, 0.55), (0.70, 0.40), (0.55, 0.30), (0.38, 0.25), (0.22, 0.30), (0.15, 0.42), (0.12, 0.55), (0.11, 0.68), (0.13, 0.75)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12'],
  drs: [(0.55, 0.15), (0.78, 0.10)],
);

// R24 – Yas Marina Circuit, Abu Dhabi
final circuitAbuDhabi = _makeCircuit(
  name: 'Abu Dhabi Grand Prix',
  location: 'Yas Marina',
  countryCode: 'UAE',
  lengthKm: 5.554,
  points: [(0.15, 0.82), (0.58, 0.82), (0.72, 0.72), (0.78, 0.58), (0.70, 0.42), (0.55, 0.30), (0.38, 0.25), (0.25, 0.32), (0.18, 0.45), (0.15, 0.58), (0.13, 0.70), (0.14, 0.78)],
  cornerNames: ['Turn 1', 'Turn 2', 'Turn 3', 'Turn 4', 'Turn 5', 'Turn 6', 'Turn 7', 'Turn 8', 'Turn 9', 'Turn 10', 'Turn 11', 'Turn 12'],
  drs: [(0.55, 0.15), (0.78, 0.10)],
);

// ── CIRCUIT LOOKUP ──────────────────────────────────────────────────

final List<F1Circuit> allCircuits2026 = [
  circuitBahrain,
  circuitSaudiArabia,
  circuitAustralia,
  circuitJapan,
  circuitChina,
  circuitMiami,
  circuitImola,
  circuitMonaco,
  circuitSpain,
  circuitCanada,
  circuitAustria,
  circuitBritain,
  circuitBelgium,
  circuitHungary,
  circuitDutch,
  circuitItaly,
  circuitAzerbaijan,
  circuitSingapore,
  circuitUSA,
  circuitMexico,
  circuitBrazil,
  circuitLasVegas,
  circuitQatar,
  circuitAbuDhabi,
];

/// Find a circuit by name (partial match on name, location, or country code).
F1Circuit? findCircuitByName(String name) {
  final lower = name.toLowerCase();
  for (final c in allCircuits2026) {
    if (c.name.toLowerCase().contains(lower) ||
        c.location.toLowerCase().contains(lower) ||
        c.countryCode.toLowerCase() == lower) {
      return c;
    }
  }
  return null;
}
