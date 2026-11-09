/// Country list with UTC offset (hours, fractional for half-hour zones like India).
/// Offsets are standard time — DST adds +1 during summer for applicable regions.
/// We use a fixed offset per country for simplicity; device timezone takes
/// precedence when the user hasn't explicitly selected a country.

class CountryTz {
  final String name;
  final String flag;
  final double utcOffset; // hours, e.g. 3.0 for EAT, 5.5 for IST
  final String abbr;      // timezone abbreviation for display

  const CountryTz({
    required this.name,
    required this.flag,
    required this.utcOffset,
    required this.abbr,
  });
}

const List<CountryTz> kCountries = [
  // Africa
  CountryTz(name: 'Algeria',            flag: '🇩🇿', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Egypt',              flag: '🇪🇬', utcOffset:  2.0, abbr: 'EET'),
  CountryTz(name: 'Ethiopia',           flag: '🇪🇹', utcOffset:  3.0, abbr: 'EAT'),
  CountryTz(name: 'Ghana',              flag: '🇬🇭', utcOffset:  0.0, abbr: 'GMT'),
  CountryTz(name: 'Kenya',              flag: '🇰🇪', utcOffset:  3.0, abbr: 'EAT'),
  CountryTz(name: 'Morocco',            flag: '🇲🇦', utcOffset:  1.0, abbr: 'WET'),
  CountryTz(name: 'Nigeria',            flag: '🇳🇬', utcOffset:  1.0, abbr: 'WAT'),
  CountryTz(name: 'South Africa',       flag: '🇿🇦', utcOffset:  2.0, abbr: 'SAST'),
  CountryTz(name: 'Tanzania',           flag: '🇹🇿', utcOffset:  3.0, abbr: 'EAT'),
  CountryTz(name: 'Uganda',             flag: '🇺🇬', utcOffset:  3.0, abbr: 'EAT'),
  CountryTz(name: 'Zimbabwe',           flag: '🇿🇼', utcOffset:  2.0, abbr: 'CAT'),
  // Americas
  CountryTz(name: 'Argentina',          flag: '🇦🇷', utcOffset: -3.0, abbr: 'ART'),
  CountryTz(name: 'Brazil',             flag: '🇧🇷', utcOffset: -3.0, abbr: 'BRT'),
  CountryTz(name: 'Canada (East)',       flag: '🇨🇦', utcOffset: -5.0, abbr: 'EST'),
  CountryTz(name: 'Canada (West)',       flag: '🇨🇦', utcOffset: -8.0, abbr: 'PST'),
  CountryTz(name: 'Chile',              flag: '🇨🇱', utcOffset: -3.0, abbr: 'CLT'),
  CountryTz(name: 'Colombia',           flag: '🇨🇴', utcOffset: -5.0, abbr: 'COT'),
  CountryTz(name: 'Mexico',             flag: '🇲🇽', utcOffset: -6.0, abbr: 'CST'),
  CountryTz(name: 'USA (East)',          flag: '🇺🇸', utcOffset: -5.0, abbr: 'EST'),
  CountryTz(name: 'USA (Central)',       flag: '🇺🇸', utcOffset: -6.0, abbr: 'CST'),
  CountryTz(name: 'USA (Mountain)',      flag: '🇺🇸', utcOffset: -7.0, abbr: 'MST'),
  CountryTz(name: 'USA (Pacific)',       flag: '🇺🇸', utcOffset: -8.0, abbr: 'PST'),
  CountryTz(name: 'Venezuela',          flag: '🇻🇪', utcOffset: -4.0, abbr: 'VET'),
  // Asia
  CountryTz(name: 'Azerbaijan',         flag: '🇦🇿', utcOffset:  4.0, abbr: 'AZT'),
  CountryTz(name: 'Bahrain',            flag: '🇧🇭', utcOffset:  3.0, abbr: 'AST'),
  CountryTz(name: 'Bangladesh',         flag: '🇧🇩', utcOffset:  6.0, abbr: 'BST'),
  CountryTz(name: 'China',              flag: '🇨🇳', utcOffset:  8.0, abbr: 'CST'),
  CountryTz(name: 'India',              flag: '🇮🇳', utcOffset:  5.5, abbr: 'IST'),
  CountryTz(name: 'Indonesia (West)',    flag: '🇮🇩', utcOffset:  7.0, abbr: 'WIB'),
  CountryTz(name: 'Israel',             flag: '🇮🇱', utcOffset:  2.0, abbr: 'IST'),
  CountryTz(name: 'Japan',              flag: '🇯🇵', utcOffset:  9.0, abbr: 'JST'),
  CountryTz(name: 'Jordan',             flag: '🇯🇴', utcOffset:  3.0, abbr: 'EAT'),
  CountryTz(name: 'Kazakhstan',         flag: '🇰🇿', utcOffset:  5.0, abbr: 'ALMT'),
  CountryTz(name: 'Kuwait',             flag: '🇰🇼', utcOffset:  3.0, abbr: 'AST'),
  CountryTz(name: 'Malaysia',           flag: '🇲🇾', utcOffset:  8.0, abbr: 'MYT'),
  CountryTz(name: 'Oman',               flag: '🇴🇲', utcOffset:  4.0, abbr: 'GST'),
  CountryTz(name: 'Pakistan',           flag: '🇵🇰', utcOffset:  5.0, abbr: 'PKT'),
  CountryTz(name: 'Philippines',        flag: '🇵🇭', utcOffset:  8.0, abbr: 'PHT'),
  CountryTz(name: 'Qatar',              flag: '🇶🇦', utcOffset:  3.0, abbr: 'AST'),
  CountryTz(name: 'Saudi Arabia',       flag: '🇸🇦', utcOffset:  3.0, abbr: 'AST'),
  CountryTz(name: 'Singapore',          flag: '🇸🇬', utcOffset:  8.0, abbr: 'SGT'),
  CountryTz(name: 'South Korea',        flag: '🇰🇷', utcOffset:  9.0, abbr: 'KST'),
  CountryTz(name: 'Sri Lanka',          flag: '🇱🇰', utcOffset:  5.5, abbr: 'IST'),
  CountryTz(name: 'Taiwan',             flag: '🇹🇼', utcOffset:  8.0, abbr: 'CST'),
  CountryTz(name: 'Thailand',           flag: '🇹🇭', utcOffset:  7.0, abbr: 'ICT'),
  CountryTz(name: 'Turkey',             flag: '🇹🇷', utcOffset:  3.0, abbr: 'TRT'),
  CountryTz(name: 'UAE',                flag: '🇦🇪', utcOffset:  4.0, abbr: 'GST'),
  CountryTz(name: 'Uzbekistan',         flag: '🇺🇿', utcOffset:  5.0, abbr: 'UZT'),
  CountryTz(name: 'Vietnam',            flag: '🇻🇳', utcOffset:  7.0, abbr: 'ICT'),
  // Europe
  CountryTz(name: 'Austria',            flag: '🇦🇹', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Belgium',            flag: '🇧🇪', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Denmark',            flag: '🇩🇰', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Finland',            flag: '🇫🇮', utcOffset:  2.0, abbr: 'EET'),
  CountryTz(name: 'France',             flag: '🇫🇷', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Germany',            flag: '🇩🇪', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Greece',             flag: '🇬🇷', utcOffset:  2.0, abbr: 'EET'),
  CountryTz(name: 'Hungary',            flag: '🇭🇺', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Ireland',            flag: '🇮🇪', utcOffset:  0.0, abbr: 'GMT'),
  CountryTz(name: 'Italy',              flag: '🇮🇹', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Monaco',             flag: '🇲🇨', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Netherlands',        flag: '🇳🇱', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Norway',             flag: '🇳🇴', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Poland',             flag: '🇵🇱', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Portugal',           flag: '🇵🇹', utcOffset:  0.0, abbr: 'WET'),
  CountryTz(name: 'Romania',            flag: '🇷🇴', utcOffset:  2.0, abbr: 'EET'),
  CountryTz(name: 'Russia',             flag: '🇷🇺', utcOffset:  3.0, abbr: 'MSK'),
  CountryTz(name: 'Spain',              flag: '🇪🇸', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Sweden',             flag: '🇸🇪', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Switzerland',        flag: '🇨🇭', utcOffset:  1.0, abbr: 'CET'),
  CountryTz(name: 'Ukraine',            flag: '🇺🇦', utcOffset:  2.0, abbr: 'EET'),
  CountryTz(name: 'United Kingdom',     flag: '🇬🇧', utcOffset:  0.0, abbr: 'GMT'),
  // Oceania
  CountryTz(name: 'Australia (East)',   flag: '🇦🇺', utcOffset: 10.0, abbr: 'AEST'),
  CountryTz(name: 'Australia (West)',   flag: '🇦🇺', utcOffset:  8.0, abbr: 'AWST'),
  CountryTz(name: 'New Zealand',        flag: '🇳🇿', utcOffset: 12.0, abbr: 'NZST'),
];

CountryTz? findCountry(String name) {
  try {
    return kCountries.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}

/// Format a UTC [dt] as "HH:MM TZZ" in the given timezone offset.
String fmtLocalTime(DateTime utcDt, CountryTz tz) {
  final offsetHours = tz.utcOffset.truncate();
  final offsetMins = ((tz.utcOffset - offsetHours) * 60).round();
  final local = utcDt.toUtc().add(Duration(hours: offsetHours, minutes: offsetMins));
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return "$h:$m ${tz.abbr}";
}
