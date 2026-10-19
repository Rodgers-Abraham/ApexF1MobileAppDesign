import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum F1Team {
  ferrari('Ferrari', Color(0xFFE10600)),
  mclaren('McLaren', Color(0xFFFF8000)),
  mercedes('Mercedes', Color(0xFF00D2BE)),
  redBull('Red Bull', Color(0xFF3671C6)),
  alpine('Alpine', Color(0xFF006EFF)),
  astonMartin('Aston Martin', Color(0xFF006F62)),
  williams('Williams', Color(0xFF1565C0)),
  haas('Haas', Color(0xFFB6BABD)),
  audi('Audi', Color(0xFFFE0000)),
  rb('RB', Color(0xFF1434CB)),
  cadillac('Cadillac', Color(0xFF1E3F66));

  final String name;
  final Color primaryColor;

  const F1Team(this.name, this.primaryColor);
}

class AppFonts {
  /// Authentic Formula 1 Header font (Formula1-Bold / Formula1-Black)
  static TextStyle header({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w900,
    Color color = Colors.white,
    double letterSpacing = 1.0,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Formula1',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Authentic Formula 1 font for Driver & Constructor names
  static TextStyle driverName({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    Color color = Colors.white,
    double letterSpacing = 0.8,
  }) {
    return TextStyle(
      fontFamily: 'Formula1',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Authentic Formula 1 Wide font for banners, badges, and section headers
  static TextStyle wide({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    Color color = Colors.white,
    double letterSpacing = 1.2,
  }) {
    return TextStyle(
      fontFamily: 'Formula1Wide',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Authentic Formula 1 font for Numbers, Lap Times, Speeds, Gaps, Points, Positions
  static TextStyle number({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    Color color = Colors.white,
    double letterSpacing = 0.5,
  }) {
    return TextStyle(
      fontFamily: 'Formula1',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Formula 1 Regular font for body & subtitle text
  static TextStyle regular({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = const Color(0xFFE1E1E1),
    double letterSpacing = 0.2,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Formula1',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

class ThemeState {
  final F1Team selectedTeam;
  final ThemeMode themeMode;

  ThemeState({
    required this.selectedTeam,
    this.themeMode = ThemeMode.dark,
  });

  ThemeState copyWith({
    F1Team? selectedTeam,
    ThemeMode? themeMode,
  }) {
    return ThemeState(
      selectedTeam: selectedTeam ?? this.selectedTeam,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _teamPrefsKey = 'selected_f1_team';

  ThemeNotifier() : super(ThemeState(selectedTeam: F1Team.ferrari)) {
    _loadSelectedTeam();
  }

  Future<void> _loadSelectedTeam() async {
    final prefs = await SharedPreferences.getInstance();
    final teamName = prefs.getString(_teamPrefsKey);
    if (teamName != null) {
      try {
        final team = F1Team.values.firstWhere((t) => t.name == teamName);
        state = state.copyWith(selectedTeam: team);
      } catch (_) {}
    }
  }

  Future<void> selectTeam(F1Team team) async {
    state = state.copyWith(selectedTeam: team);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teamPrefsKey, team.name);
  }

  ThemeData getThemeData() {
    final accentColor = state.selectedTeam.primaryColor;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accentColor,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor.withOpacity(0.8),
        tertiary: const Color(0xFF1E1E1E),
        surface: const Color(0xFF121215),
        error: const Color(0xFFCF6679),
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: const Color(0xFFE1E1E1),
      ),
      scaffoldBackgroundColor: const Color(0xFF09090B),
      cardTheme: CardThemeData(
        color: const Color(0xFF141418),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF101014),
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.orbitron(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFFE1E1E1)),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
      ),
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
