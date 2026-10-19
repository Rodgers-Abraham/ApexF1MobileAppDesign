import 'package:flutter/material.dart';

/// 2026 Team Metadata model
class TeamData2026 {
  final String name;
  final String slug;
  final String chassis;
  final String powerUnit;
  final String chassisPu;
  final Color primaryColor;
  final Color secondaryColor;
  final String logoWhiteAsset;
  final String logoColorAsset;
  final String carFrontAsset;

  const TeamData2026({
    required this.name,
    required this.slug,
    required this.chassis,
    required this.powerUnit,
    required this.chassisPu,
    required this.primaryColor,
    required this.secondaryColor,
    required this.logoWhiteAsset,
    required this.logoColorAsset,
    required this.carFrontAsset,
  });
}

/// 2026 Driver Metadata model
class DriverData2026 {
  final String name;
  final String code;
  final String team;
  final String country;
  final String portraitAsset;
  final String helmetAsset;
  final String numberAsset;

  const DriverData2026({
    required this.name,
    required this.code,
    required this.team,
    required this.country,
    required this.portraitAsset,
    required this.helmetAsset,
    required this.numberAsset,
  });
}

/// Comprehensive official 2026 F1 Teams map
const Map<String, TeamData2026> kTeams2026 = {
  'Alpine': TeamData2026(
    name: 'Alpine',
    slug: 'alpine',
    chassis: 'A526',
    powerUnit: 'Mercedes',
    chassisPu: 'A526 Mercedes',
    primaryColor: Color(0xFF00A1E8),
    secondaryColor: Color(0xFF004E70),
    logoWhiteAsset: 'assets/teams/alpine_white.svg',
    logoColorAsset: 'assets/teams/alpine_color.svg',
    carFrontAsset: 'assets/teams/alpine_car_front.png',
  ),
  'Aston Martin': TeamData2026(
    name: 'Aston Martin',
    slug: 'astonmartin',
    chassis: 'AMR26',
    powerUnit: 'Honda',
    chassisPu: 'AMR26 Honda',
    primaryColor: Color(0xFF229971),
    secondaryColor: Color(0xFF0F4331),
    logoWhiteAsset: 'assets/teams/astonmartin_white.svg',
    logoColorAsset: 'assets/teams/astonmartin_color.svg',
    carFrontAsset: 'assets/teams/astonmartin_car_front.png',
  ),
  'Audi': TeamData2026(
    name: 'Audi',
    slug: 'audi',
    chassis: 'R26',
    powerUnit: 'Audi',
    chassisPu: 'R26 Audi',
    primaryColor: Color(0xFFFF2D00),
    secondaryColor: Color(0xFF751500),
    logoWhiteAsset: 'assets/teams/audi_white.svg',
    logoColorAsset: 'assets/teams/audi_color.svg',
    carFrontAsset: 'assets/teams/audi_car_front.png',
  ),
  'Cadillac': TeamData2026(
    name: 'Cadillac',
    slug: 'cadillac',
    chassis: 'MAC-26',
    powerUnit: 'Ferrari',
    chassisPu: 'MAC-26 Ferrari',
    primaryColor: Color(0xFFAAAAAD),
    secondaryColor: Color(0xFF58585B),
    logoWhiteAsset: 'assets/teams/cadillac_white.svg',
    logoColorAsset: 'assets/teams/cadillac_color.svg',
    carFrontAsset: 'assets/teams/cadillac_car_front.png',
  ),
  'Ferrari': TeamData2026(
    name: 'Ferrari',
    slug: 'ferrari',
    chassis: 'SF-26',
    powerUnit: 'Ferrari',
    chassisPu: 'SF-26 Ferrari',
    primaryColor: Color(0xFFE8002D),
    secondaryColor: Color(0xFF750017),
    logoWhiteAsset: 'assets/teams/ferrari_white.svg',
    logoColorAsset: 'assets/teams/ferrari_color.svg',
    carFrontAsset: 'assets/teams/ferrari_car_front.png',
  ),
  'Haas': TeamData2026(
    name: 'Haas',
    slug: 'haasf1team',
    chassis: 'VF-26',
    powerUnit: 'Ferrari',
    chassisPu: 'VF-26 Ferrari',
    primaryColor: Color(0xFFDEE1E2),
    secondaryColor: Color(0xFF6F7071),
    logoWhiteAsset: 'assets/teams/haasf1team_white.svg',
    logoColorAsset: 'assets/teams/haasf1team_color.svg',
    carFrontAsset: 'assets/teams/haasf1team_car_front.png',
  ),
  'Haas F1 Team': TeamData2026(
    name: 'Haas',
    slug: 'haasf1team',
    chassis: 'VF-26',
    powerUnit: 'Ferrari',
    chassisPu: 'VF-26 Ferrari',
    primaryColor: Color(0xFFDEE1E2),
    secondaryColor: Color(0xFF6F7071),
    logoWhiteAsset: 'assets/teams/haasf1team_white.svg',
    logoColorAsset: 'assets/teams/haasf1team_color.svg',
    carFrontAsset: 'assets/teams/haasf1team_car_front.png',
  ),
  'McLaren': TeamData2026(
    name: 'McLaren',
    slug: 'mclaren',
    chassis: 'MCL40',
    powerUnit: 'Mercedes',
    chassisPu: 'MCL40 Mercedes',
    primaryColor: Color(0xFFFF8000),
    secondaryColor: Color(0xFF804000),
    logoWhiteAsset: 'assets/teams/mclaren_white.svg',
    logoColorAsset: 'assets/teams/mclaren_color.svg',
    carFrontAsset: 'assets/teams/mclaren_car_front.png',
  ),
  'Mercedes': TeamData2026(
    name: 'Mercedes',
    slug: 'mercedes',
    chassis: 'W17',
    powerUnit: 'Mercedes',
    chassisPu: 'W17 Mercedes',
    primaryColor: Color(0xFF27F4D2),
    secondaryColor: Color(0xFF147A69),
    logoWhiteAsset: 'assets/teams/mercedes_white.svg',
    logoColorAsset: 'assets/teams/mercedes_color.svg',
    carFrontAsset: 'assets/teams/mercedes_car_front.png',
  ),
  'Racing Bulls': TeamData2026(
    name: 'Racing Bulls',
    slug: 'racingbulls',
    chassis: 'VCARB 03',
    powerUnit: 'Red Bull Ford',
    chassisPu: 'VCARB 03 Red Bull Ford',
    primaryColor: Color(0xFF6692FF),
    secondaryColor: Color(0xFF334980),
    logoWhiteAsset: 'assets/teams/racingbulls_white.svg',
    logoColorAsset: 'assets/teams/racingbulls_color.svg',
    carFrontAsset: 'assets/teams/racingbulls_car_front.png',
  ),
  'RB': TeamData2026(
    name: 'Racing Bulls',
    slug: 'racingbulls',
    chassis: 'VCARB 03',
    powerUnit: 'Red Bull Ford',
    chassisPu: 'VCARB 03 Red Bull Ford',
    primaryColor: Color(0xFF6692FF),
    secondaryColor: Color(0xFF334980),
    logoWhiteAsset: 'assets/teams/racingbulls_white.svg',
    logoColorAsset: 'assets/teams/racingbulls_color.svg',
    carFrontAsset: 'assets/teams/racingbulls_car_front.png',
  ),
  'Red Bull': TeamData2026(
    name: 'Red Bull Racing',
    slug: 'redbullracing',
    chassis: 'RB22',
    powerUnit: 'Red Bull Ford',
    chassisPu: 'RB22 Red Bull Ford',
    primaryColor: Color(0xFF3671C6),
    secondaryColor: Color(0xFF1B3963),
    logoWhiteAsset: 'assets/teams/redbullracing_white.svg',
    logoColorAsset: 'assets/teams/redbullracing_color.svg',
    carFrontAsset: 'assets/teams/redbullracing_car_front.png',
  ),
  'Red Bull Racing': TeamData2026(
    name: 'Red Bull Racing',
    slug: 'redbullracing',
    chassis: 'RB22',
    powerUnit: 'Red Bull Ford',
    chassisPu: 'RB22 Red Bull Ford',
    primaryColor: Color(0xFF3671C6),
    secondaryColor: Color(0xFF1B3963),
    logoWhiteAsset: 'assets/teams/redbullracing_white.svg',
    logoColorAsset: 'assets/teams/redbullracing_color.svg',
    carFrontAsset: 'assets/teams/redbullracing_car_front.png',
  ),
  'Williams': TeamData2026(
    name: 'Williams',
    slug: 'williams',
    chassis: 'FW48',
    powerUnit: 'Mercedes',
    chassisPu: 'FW48 Mercedes',
    primaryColor: Color(0xFF1868DB),
    secondaryColor: Color(0xFF0C346E),
    logoWhiteAsset: 'assets/teams/williams_white.svg',
    logoColorAsset: 'assets/teams/williams_color.svg',
    carFrontAsset: 'assets/teams/williams_car_front.png',
  ),
};

/// 22 Official 2026 Drivers
const List<DriverData2026> kDrivers2026List = [
  DriverData2026(
    name: 'Max Verstappen',
    code: 'VER',
    team: 'Red Bull Racing',
    country: 'Netherlands',
    portraitAsset: 'assets/drivers/max_verstappen_portrait.png',
    helmetAsset: 'assets/helmets/max_verstappen_helmet.png',
    numberAsset: 'assets/numbers/max_verstappen_number.svg',
  ),
  DriverData2026(
    name: 'Isack Hadjar',
    code: 'HAD',
    team: 'Red Bull Racing',
    country: 'France',
    portraitAsset: 'assets/drivers/isack_hadjar_portrait.png',
    helmetAsset: 'assets/helmets/isack_hadjar_helmet.png',
    numberAsset: 'assets/numbers/isack_hadjar_number.svg',
  ),
  DriverData2026(
    name: 'Lewis Hamilton',
    code: 'HAM',
    team: 'Ferrari',
    country: 'United Kingdom',
    portraitAsset: 'assets/drivers/lewis_hamilton_portrait.png',
    helmetAsset: 'assets/helmets/lewis_hamilton_helmet.png',
    numberAsset: 'assets/numbers/lewis_hamilton_number.svg',
  ),
  DriverData2026(
    name: 'Charles Leclerc',
    code: 'LEC',
    team: 'Ferrari',
    country: 'Monaco',
    portraitAsset: 'assets/drivers/charles_leclerc_portrait.png',
    helmetAsset: 'assets/helmets/charles_leclerc_helmet.png',
    numberAsset: 'assets/numbers/charles_leclerc_number.svg',
  ),
  DriverData2026(
    name: 'Lando Norris',
    code: 'NOR',
    team: 'McLaren',
    country: 'United Kingdom',
    portraitAsset: 'assets/drivers/lando_norris_portrait.png',
    helmetAsset: 'assets/helmets/lando_norris_helmet.png',
    numberAsset: 'assets/numbers/lando_norris_number.svg',
  ),
  DriverData2026(
    name: 'Oscar Piastri',
    code: 'PIA',
    team: 'McLaren',
    country: 'Australia',
    portraitAsset: 'assets/drivers/oscar_piastri_portrait.png',
    helmetAsset: 'assets/helmets/oscar_piastri_helmet.png',
    numberAsset: 'assets/numbers/oscar_piastri_number.svg',
  ),
  DriverData2026(
    name: 'George Russell',
    code: 'RUS',
    team: 'Mercedes',
    country: 'United Kingdom',
    portraitAsset: 'assets/drivers/george_russell_portrait.png',
    helmetAsset: 'assets/helmets/george_russell_helmet.png',
    numberAsset: 'assets/numbers/george_russell_number.svg',
  ),
  DriverData2026(
    name: 'Kimi Antonelli',
    code: 'ANT',
    team: 'Mercedes',
    country: 'Italy',
    portraitAsset: 'assets/drivers/kimi_antonelli_portrait.png',
    helmetAsset: 'assets/helmets/kimi_antonelli_helmet.png',
    numberAsset: 'assets/numbers/kimi_antonelli_number.svg',
  ),
  DriverData2026(
    name: 'Fernando Alonso',
    code: 'ALO',
    team: 'Aston Martin',
    country: 'Spain',
    portraitAsset: 'assets/drivers/fernando_alonso_portrait.png',
    helmetAsset: 'assets/helmets/fernando_alonso_helmet.png',
    numberAsset: 'assets/numbers/fernando_alonso_number.svg',
  ),
  DriverData2026(
    name: 'Lance Stroll',
    code: 'STR',
    team: 'Aston Martin',
    country: 'Canada',
    portraitAsset: 'assets/drivers/lance_stroll_portrait.png',
    helmetAsset: 'assets/helmets/lance_stroll_helmet.png',
    numberAsset: 'assets/numbers/lance_stroll_number.svg',
  ),
  DriverData2026(
    name: 'Pierre Gasly',
    code: 'GAS',
    team: 'Alpine',
    country: 'France',
    portraitAsset: 'assets/drivers/pierre_gasly_portrait.png',
    helmetAsset: 'assets/helmets/pierre_gasly_helmet.png',
    numberAsset: 'assets/numbers/pierre_gasly_number.svg',
  ),
  DriverData2026(
    name: 'Franco Colapinto',
    code: 'COL',
    team: 'Alpine',
    country: 'Argentina',
    portraitAsset: 'assets/drivers/franco_colapinto_portrait.png',
    helmetAsset: 'assets/helmets/franco_colapinto_helmet.png',
    numberAsset: 'assets/numbers/franco_colapinto_number.svg',
  ),
  DriverData2026(
    name: 'Liam Lawson',
    code: 'LAW',
    team: 'Racing Bulls',
    country: 'New Zealand',
    portraitAsset: 'assets/drivers/liam_lawson_portrait.png',
    helmetAsset: 'assets/helmets/liam_lawson_helmet.png',
    numberAsset: 'assets/numbers/liam_lawson_number.svg',
  ),
  DriverData2026(
    name: 'Arvid Lindblad',
    code: 'LIN',
    team: 'Racing Bulls',
    country: 'United Kingdom',
    portraitAsset: 'assets/drivers/arvid_lindblad_portrait.png',
    helmetAsset: 'assets/helmets/arvid_lindblad_helmet.png',
    numberAsset: 'assets/numbers/arvid_lindblad_number.svg',
  ),
  DriverData2026(
    name: 'Oliver Bearman',
    code: 'BEA',
    team: 'Haas',
    country: 'United Kingdom',
    portraitAsset: 'assets/drivers/oliver_bearman_portrait.png',
    helmetAsset: 'assets/helmets/oliver_bearman_helmet.png',
    numberAsset: 'assets/numbers/oliver_bearman_number.svg',
  ),
  DriverData2026(
    name: 'Esteban Ocon',
    code: 'OCO',
    team: 'Haas',
    country: 'France',
    portraitAsset: 'assets/drivers/esteban_ocon_portrait.png',
    helmetAsset: 'assets/helmets/esteban_ocon_helmet.png',
    numberAsset: 'assets/numbers/esteban_ocon_number.svg',
  ),
  DriverData2026(
    name: 'Carlos Sainz',
    code: 'SAI',
    team: 'Williams',
    country: 'Spain',
    portraitAsset: 'assets/drivers/carlos_sainz_portrait.png',
    helmetAsset: 'assets/helmets/carlos_sainz_helmet.png',
    numberAsset: 'assets/numbers/carlos_sainz_number.svg',
  ),
  DriverData2026(
    name: 'Alex Albon',
    code: 'ALB',
    team: 'Williams',
    country: 'Thailand',
    portraitAsset: 'assets/drivers/alexander_albon_portrait.png',
    helmetAsset: 'assets/helmets/alexander_albon_helmet.png',
    numberAsset: 'assets/numbers/alexander_albon_number.svg',
  ),
  DriverData2026(
    name: 'Nico Hülkenberg',
    code: 'HUL',
    team: 'Audi',
    country: 'Germany',
    portraitAsset: 'assets/drivers/nico_hulkenberg_portrait.png',
    helmetAsset: 'assets/helmets/nico_hulkenberg_helmet.png',
    numberAsset: 'assets/numbers/nico_hulkenberg_number.svg',
  ),
  DriverData2026(
    name: 'Gabriel Bortoleto',
    code: 'BOR',
    team: 'Audi',
    country: 'Brazil',
    portraitAsset: 'assets/drivers/gabriel_bortoleto_portrait.png',
    helmetAsset: 'assets/helmets/gabriel_bortoleto_helmet.png',
    numberAsset: 'assets/numbers/gabriel_bortoleto_number.svg',
  ),
  DriverData2026(
    name: 'Sergio Perez',
    code: 'PER',
    team: 'Cadillac',
    country: 'Mexico',
    portraitAsset: 'assets/drivers/sergio_perez_portrait.png',
    helmetAsset: 'assets/helmets/sergio_perez_helmet.png',
    numberAsset: 'assets/numbers/sergio_perez_number.svg',
  ),
  DriverData2026(
    name: 'Valtteri Bottas',
    code: 'BOT',
    team: 'Cadillac',
    country: 'Finland',
    portraitAsset: 'assets/drivers/valtteri_bottas_portrait.png',
    helmetAsset: 'assets/helmets/valtteri_bottas_helmet.png',
    numberAsset: 'assets/numbers/valtteri_bottas_number.svg',
  ),
];

/// Driver string names list
final List<String> kDrivers2026 = kDrivers2026List.map((d) => d.name).toList();

/// Map team colors by team name
final Map<String, Color> kTeamColors = {
  for (var entry in kTeams2026.entries) entry.key: entry.value.primaryColor,
};

/// Driver name to team mapping
final Map<String, String> kDriverTeams2026 = {
  for (var driver in kDrivers2026List) driver.name: driver.team,
};

/// Get team metadata
TeamData2026? getTeamData(String teamName) {
  final clean = teamName.trim();
  if (kTeams2026.containsKey(clean)) return kTeams2026[clean];
  for (var entry in kTeams2026.entries) {
    if (clean.toLowerCase().contains(entry.key.toLowerCase()) ||
        entry.key.toLowerCase().contains(clean.toLowerCase())) {
      return entry.value;
    }
  }
  return null;
}

/// Get driver metadata by name or 3-letter code
DriverData2026? getDriverData(String query) {
  final clean = query.trim().toLowerCase();
  for (var driver in kDrivers2026List) {
    if (driver.code.toLowerCase() == clean ||
        driver.name.toLowerCase() == clean ||
        driver.name.toLowerCase().contains(clean)) {
      return driver;
    }
  }
  return null;
}

/// Get team color for driver
Color getDriverTeamColor(String driverName) {
  final driver = getDriverData(driverName);
  if (driver != null) {
    final team = getTeamData(driver.team);
    if (team != null) return team.primaryColor;
  }
  final teamName = kDriverTeams2026[driverName];
  if (teamName != null) {
    return kTeamColors[teamName] ?? const Color(0xFFE10600);
  }
  return const Color(0xFFE10600);
}

/// Get team primary color
Color getTeamColor(String teamName) {
  final team = getTeamData(teamName);
  return team?.primaryColor ?? kTeamColors[teamName] ?? Colors.grey;
}

/// Get team logo asset (white SVG by default)
String getTeamLogoAsset(String teamName, {bool white = true}) {
  final team = getTeamData(teamName);
  if (team != null) {
    return white ? team.logoWhiteAsset : team.logoColorAsset;
  }
  return 'assets/teams/ferrari_white.svg';
}