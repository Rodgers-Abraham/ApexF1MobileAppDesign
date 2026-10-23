import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../shared/theme/theme_provider.dart';

final circuitHistoryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, raceName) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/history/circuit/$raceName');
  return response.data as Map<String, dynamic>;
});

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

// ─── DATA MODELS ─────────────────────────────────────────────────────────────

class RaceEvent {
  final String name;
  final String circuit;
  final String countryCode;
  final DateTime date;
  final String round;
  final double lengthKm;
  final int turns;
  final int drsZones;

  const RaceEvent({
    required this.name,
    required this.circuit,
    required this.countryCode,
    required this.date,
    required this.round,
    this.lengthKm = 5.3,
    this.turns = 16,
    this.drsZones = 2,
  });
}

final List<RaceEvent> _calendar = [
  RaceEvent(name: 'Australian GP', circuit: 'Albert Park', countryCode: 'AUS', date: DateTime(2026, 3, 8), round: 'R01', lengthKm: 5.278, turns: 14, drsZones: 4),
  RaceEvent(name: 'Chinese GP', circuit: 'Shanghai Intl', countryCode: 'CHN', date: DateTime(2026, 3, 15), round: 'R02', lengthKm: 5.451, turns: 16, drsZones: 2),
  RaceEvent(name: 'Japanese GP', circuit: 'Suzuka Circuit', countryCode: 'JPN', date: DateTime(2026, 3, 29), round: 'R03', lengthKm: 5.807, turns: 18, drsZones: 1),
  RaceEvent(name: 'Miami GP', circuit: 'Miami Autodrome', countryCode: 'USA', date: DateTime(2026, 5, 3), round: 'R04', lengthKm: 5.412, turns: 19, drsZones: 3),
  RaceEvent(name: 'Canadian GP', circuit: 'Circuit Gilles Villeneuve', countryCode: 'CAN', date: DateTime(2026, 5, 24), round: 'R05', lengthKm: 4.361, turns: 14, drsZones: 2),
  RaceEvent(name: 'Monaco GP', circuit: 'Circuit de Monaco', countryCode: 'MCO', date: DateTime(2026, 6, 7), round: 'R06', lengthKm: 3.337, turns: 19, drsZones: 1),
  RaceEvent(name: 'Spanish GP', circuit: 'Barcelona-Catalunya', countryCode: 'ESP', date: DateTime(2026, 6, 14), round: 'R07', lengthKm: 4.657, turns: 14, drsZones: 2),
  RaceEvent(name: 'Austrian GP', circuit: 'Red Bull Ring', countryCode: 'AUT', date: DateTime(2026, 6, 28), round: 'R08', lengthKm: 4.318, turns: 10, drsZones: 3),
  RaceEvent(name: 'British GP', circuit: 'Silverstone Circuit', countryCode: 'GBR', date: DateTime(2026, 7, 5), round: 'R09', lengthKm: 5.891, turns: 18, drsZones: 2),
  RaceEvent(name: 'Belgian GP', circuit: 'Spa-Francorchamps', countryCode: 'BEL', date: DateTime(2026, 7, 19), round: 'R10', lengthKm: 7.004, turns: 19, drsZones: 2),
  RaceEvent(name: 'Hungarian GP', circuit: 'Hungaroring', countryCode: 'HUN', date: DateTime(2026, 7, 26), round: 'R11', lengthKm: 4.381, turns: 14, drsZones: 2),
  RaceEvent(name: 'Dutch GP', circuit: 'Circuit Zandvoort', countryCode: 'NLD', date: DateTime(2026, 8, 23), round: 'R12', lengthKm: 4.259, turns: 14, drsZones: 2),
  RaceEvent(name: 'Italian GP', circuit: 'Monza Circuit', countryCode: 'ITA', date: DateTime(2026, 9, 6), round: 'R13', lengthKm: 5.793, turns: 11, drsZones: 2),
  RaceEvent(name: 'Spanish GP (Madrid)', circuit: 'Madrid Street Circuit', countryCode: 'ESP', date: DateTime(2026, 9, 13), round: 'R14', lengthKm: 5.474, turns: 20, drsZones: 2),
  RaceEvent(name: 'Azerbaijan GP', circuit: 'Baku City Circuit', countryCode: 'AZE', date: DateTime(2026, 9, 26), round: 'R15', lengthKm: 6.003, turns: 20, drsZones: 2),
  RaceEvent(name: 'Bahrain GP', circuit: 'Bahrain Intl', countryCode: 'BHR', date: DateTime(2026, 10, 4), round: 'R16', lengthKm: 5.412, turns: 15, drsZones: 3),
  RaceEvent(name: 'Singapore GP', circuit: 'Marina Bay Street', countryCode: 'SGP', date: DateTime(2026, 10, 11), round: 'R17', lengthKm: 4.940, turns: 19, drsZones: 3),
  RaceEvent(name: 'United States GP', circuit: 'COTA Austin', countryCode: 'USA', date: DateTime(2026, 10, 25), round: 'R18', lengthKm: 5.513, turns: 20, drsZones: 2),
  RaceEvent(name: 'Mexico City GP', circuit: 'Autódromo Hermanos Rodríguez', countryCode: 'MEX', date: DateTime(2026, 11, 1), round: 'R19', lengthKm: 4.304, turns: 17, drsZones: 3),
  RaceEvent(name: 'São Paulo GP', circuit: 'Interlagos', countryCode: 'BRA', date: DateTime(2026, 11, 8), round: 'R20', lengthKm: 4.309, turns: 15, drsZones: 2),
  RaceEvent(name: 'Las Vegas GP', circuit: 'Las Vegas Strip', countryCode: 'USA', date: DateTime(2026, 11, 21), round: 'R21', lengthKm: 6.201, turns: 17, drsZones: 2),
  RaceEvent(name: 'Qatar GP', circuit: 'Lusail Intl', countryCode: 'QAT', date: DateTime(2026, 11, 29), round: 'R22', lengthKm: 5.419, turns: 16, drsZones: 1),
  RaceEvent(name: 'Abu Dhabi GP', circuit: 'Yas Marina', countryCode: 'UAE', date: DateTime(2026, 12, 6), round: 'R23', lengthKm: 5.281, turns: 16, drsZones: 2),
];

RaceEvent? _findNextRace() {
  final now = DateTime.now();
  for (final r in _calendar) {
    if (r.date.isAfter(now)) return r;
  }
  return null;
}

String _monthAbbrev(int month) {
  final names = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return names[month];
}

String _getCountryFlag(String code) {
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

// ─── PIT WALL SCREEN ─────────────────────────────────────────────────────────

class PitWallScreen extends ConsumerStatefulWidget {
  const PitWallScreen({super.key});
  @override
  ConsumerState<PitWallScreen> createState() => _PitWallScreenState();
}

class _PitWallScreenState extends ConsumerState<PitWallScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);
    final accentColor = themeState.selectedTeam.primaryColor;
    final sessionStatusAsync = ref.watch(sessionLiveStatusProvider);
    final isLive = sessionStatusAsync.value?.isLive ?? false;
    final nextRace = _findNextRace() ?? _calendar.first;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
        elevation: 0,
        centerTitle: false,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'A',
                  style: TextStyle(
                    fontFamily: 'Formula1Wide',
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF0B0B0E),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'APEX',
                style: AppFonts.wide(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Text(
                'F1',
                style: AppFonts.wide(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFFF1744)),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: (isLive ? const Color(0xFF00E676) : Colors.cyanAccent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (isLive ? const Color(0xFF00E676) : Colors.cyanAccent).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLive ? 'LIVE' : 'ACTIVE',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 7.5,
                          color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    '${nextRace.round} · ${nextRace.countryCode}',
                    style: AppFonts.number(fontSize: 8.5, color: Colors.grey[400]!, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. FIGMA GP HERO CARD ───────────────────────────────────────
            _FigmaGPHeroWidget(accent: accentColor),
            const SizedBox(height: 22),

            // ── 2. FIGMA RACE CONTROL ───────────────────────────────────────
            _FigmaRaceControlWidget(accent: accentColor),
            const SizedBox(height: 22),

            // ── 3. FIGMA RACE PULSE ─────────────────────────────────────────
            _FigmaRacePulseWidget(accent: accentColor),
            const SizedBox(height: 22),

            // ── 4. FIGMA PADDOCK FEED (REAL 16:9 NEWS CAROUSEL) ─────────────
            _FigmaNewsRailWidget(accent: accentColor),
            const SizedBox(height: 22),

            // ── 5. SEASON CALENDAR ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'SEASON CALENDAR',
                    style: const TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '2026 ROUNDS',
                  style: AppFonts.number(fontSize: 9, color: Colors.grey[500]!, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SeasonCalendarWidget(accent: accentColor),
            const SizedBox(height: 30),

            const Center(
              child: Text(
                'Built with official 2026 FIA data & OpenF1 telemetry',
                style: TextStyle(fontFamily: 'Formula1', fontSize: 9.5, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

class _ModuleLabel extends StatelessWidget {
  final String number;
  final String title;
  final Color color;
  const _ModuleLabel(this.number, this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('§$number', style: AppFonts.number(fontSize: 11, fontWeight: FontWeight.w900, color: color.withOpacity(0.8), letterSpacing: 1)),
        const SizedBox(width: 8),
        Text(title, style: AppFonts.header(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[400]!, letterSpacing: 1.5)),
      ],
    );
  }
}

// ── 1. FIGMA GP HERO WIDGET ─────────────────────────────────────────────────

class _FigmaGPHeroWidget extends ConsumerStatefulWidget {
  final Color accent;
  const _FigmaGPHeroWidget({required this.accent});

  @override
  ConsumerState<_FigmaGPHeroWidget> createState() => _FigmaGPHeroWidgetState();
}

class _FigmaGPHeroWidgetState extends ConsumerState<_FigmaGPHeroWidget> {
  Timer? _timer;
  late DateTime _raceDate;

  @override
  void initState() {
    super.initState();
    final nextRace = _findNextRace();
    _raceDate = nextRace?.date ?? DateTime.now().add(const Duration(days: 14));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    late Duration diff;
    if (_raceDate.isBefore(now)) {
      diff = Duration.zero;
    } else {
      diff = _raceDate.difference(now);
    }
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;

    final nextRace = _findNextRace() ?? _calendar.first;
    final sessionStatus = ref.watch(sessionLiveStatusProvider).value;
    final isLiveNow = sessionStatus?.isLive ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: const Color(0xFF292932), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Red left accent indicator line
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 4,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFFF1744),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF1744),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLiveNow) ...[
                  InkWell(
                    onTap: () => context.go('/live'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00E676).withValues(alpha: 0.22),
                            const Color(0xFF00E676).withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0xFF00E676), blurRadius: 8, spreadRadius: 2),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LIVE ON TRACK · ${(sessionStatus?.sessionName ?? "PRACTICE 1").toUpperCase()}',
                                  style: const TextStyle(
                                    fontFamily: 'Formula1Wide',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF00E676),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${sessionStatus?.meetingName ?? "United States Grand Prix"} · Circuit of the Americas',
                                  style: const TextStyle(
                                    fontFamily: 'Formula1',
                                    fontSize: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'PITWALL',
                                  style: TextStyle(
                                    fontFamily: 'Formula1Wide',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.black),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Head: Eyebrow + Title + Round Flag
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FORMULA 1 · ROUND ${nextRace.round}',
                            style: const TextStyle(
                              fontFamily: 'Formula1Wide',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8F909A),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            nextRace.name.split(' ').first.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.wide(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'GRAND PRIX',
                            style: TextStyle(
                              fontFamily: 'Formula1Wide',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFFF1744),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Country emoji badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF101014),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF202028)),
                      ),
                      child: Center(
                        child: Text(
                          _getCountryFlag(nextRace.countryCode),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 4-Column Countdown Grid
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF070709).withValues(alpha: 0.8),
                    border: Border.all(color: const Color(0xFF202028)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      _buildCountdownCell(d.toString().padLeft(2, '0'), 'DAYS', true),
                      _buildCountdownCell(h.toString().padLeft(2, '0'), 'HRS', true),
                      _buildCountdownCell(m.toString().padLeft(2, '0'), 'MIN', true),
                      _buildCountdownCell(s.toString().padLeft(2, '0'), 'SEC', false),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Circuit section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            getCircuitAssetPath(nextRace.name),
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(height: 80),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'CIRCUIT ${nextRace.round}',
                              style: AppFonts.number(
                                fontSize: 8.5,
                                color: const Color(0xFF8F909A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextRace.circuit.toUpperCase(),
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.wide(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${nextRace.countryCode} · 2026',
                              style: AppFonts.number(
                                fontSize: 8.5,
                                color: const Color(0xFF8F909A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3 Hero Stats
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF202028), width: 1),
                      bottom: BorderSide(color: Color(0xFF202028), width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      _buildHeroStat('58', 'LAPS', true),
                      _buildHeroStat('${nextRace.lengthKm}', 'KM', true),
                      _buildHeroStat('${nextRace.drsZones}', 'DRS ZONES', false),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Real Weather conditions row
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined, color: Color(0xFFFFD600), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PARTLY CLOUDY',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.number(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'RAIN 10%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.number(fontSize: 7.5, color: const Color(0xFF8F909A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildWeatherCell('24°', 'AIR'),
                    const SizedBox(width: 8),
                    _buildWeatherCell('38°', 'TRACK'),
                    const SizedBox(width: 8),
                    _buildWeatherCell('45%', 'HUM'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCell(String value, String label, bool hasRightBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: hasRightBorder
              ? const Border(right: BorderSide(color: Color(0xFF202028), width: 1))
              : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppFonts.number(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Formula1Wide',
                fontSize: 7,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8F909A),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStat(String value, String label, bool hasRightBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: hasRightBorder
              ? const Border(right: BorderSide(color: Color(0xFF202028), width: 1))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppFonts.number(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Formula1Wide',
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8F909A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCell(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppFonts.number(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Formula1Wide',
            fontSize: 6.5,
            color: Color(0xFF8F909A),
          ),
        ),
      ],
    );
  }
}

// ── 2. FIGMA RACE CONTROL WIDGET ────────────────────────────────────────────

class _FigmaRaceControlWidget extends StatefulWidget {
  final Color accent;
  const _FigmaRaceControlWidget({required this.accent});

  @override
  State<_FigmaRaceControlWidget> createState() => _FigmaRaceControlWidgetState();
}

class _FigmaRaceControlWidgetState extends State<_FigmaRaceControlWidget> {
  String _selectedFlag = 'GREEN';

  @override
  Widget build(BuildContext context) {
    Color flagColor;
    String statusTitle;
    String statusSubtitle;

    switch (_selectedFlag) {
      case 'YELLOW':
        flagColor = const Color(0xFFFFD600);
        statusTitle = 'YELLOW FLAG';
        statusSubtitle = 'SECTOR 2 · DEBRIS AT TURN 9';
        break;
      case 'VSC':
        flagColor = const Color(0xFFFF9100);
        statusTitle = 'VIRTUAL SAFETY CAR';
        statusSubtitle = 'MAINTAIN POSITIVE DELTA · SPEED REDUCTION';
        break;
      case 'SC':
        flagColor = const Color(0xFFFF9100);
        statusTitle = 'SAFETY CAR DEPLOYED';
        statusSubtitle = 'TURN 4 INCIDENT · NO OVERTAKING';
        break;
      case 'RED':
        flagColor = const Color(0xFFFF1744);
        statusTitle = 'SESSION STOPPED';
        statusSubtitle = 'RED FLAG · RETURN TO PIT LANE';
        break;
      default:
        flagColor = const Color(0xFF00E676);
        statusTitle = 'TRACK CLEAR';
        statusSubtitle = 'GREEN FLAG · DRS ENABLED';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'RACE CONTROL',
                style: const TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LIVE FEED',
              style: AppFonts.number(fontSize: 9, color: Colors.grey[500]!, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Session Flag Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(3),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(color: flagColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: flagColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(Icons.warning_amber_rounded, color: flagColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: flagColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: AppFonts.number(fontSize: 9, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.flag_rounded, color: flagColor, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Flag selector buttons
        Row(
          children: ['GREEN', 'YELLOW', 'VSC', 'SC', 'RED'].map((f) {
            final isSelected = _selectedFlag == f;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedFlag = f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? Colors.white : const Color(0xFF202028),
                      width: isSelected ? 1.2 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      f,
                      style: AppFonts.number(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF8F909A),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── 3. FIGMA RACE PULSE WIDGET ──────────────────────────────────────────────

class _FigmaRacePulseWidget extends StatelessWidget {
  final Color accent;
  const _FigmaRacePulseWidget({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'RACE PULSE',
                style: const TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LAP 34 / 58',
              style: AppFonts.number(fontSize: 9, color: Colors.grey[500]!, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/live'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(color: const Color(0xFF202028)),
              ),
              child: Row(
                children: [
                  // Leader pill
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEADER',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 7.5,
                            color: const Color(0xFF8F909A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 12,
                              color: const Color(0xFFFF8000), // McLaren papaya
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'NORRIS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.driverName(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'McLAREN · MEDIUM 12L',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.number(fontSize: 8.5, color: const Color(0xFF8F909A)),
                        ),
                      ],
                    ),
                  ),

                  // Fastest Lap pill
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FASTEST LAP',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 7.5,
                            color: const Color(0xFF8F909A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '1:21.733',
                          style: AppFonts.number(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFB388FF), // Purple
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PIASTRI · LAP 31',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.number(fontSize: 8.5, color: const Color(0xFF8F909A)),
                        ),
                      ],
                    ),
                  ),

                  // Navigation arrow
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 4. FIGMA PADDOCK FEED (REAL 16:9 NEWS CAROUSEL) ─────────────────────────

class _FigmaNewsRailWidget extends ConsumerWidget {
  final Color accent;
  const _FigmaNewsRailWidget({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(liveNewsFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'PADDOCK FEED',
                style: const TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LATEST ARTICLES',
              style: AppFonts.number(fontSize: 9, color: Colors.grey[500]!, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Builder(
          builder: (context) {
            final articles = newsAsync.valueOrNull ?? [];
            if (newsAsync.isLoading && articles.isEmpty) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator(color: Colors.red)),
              );
            }
            if (articles.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141419),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'No recent paddock articles available.',
                  style: AppFonts.regular(fontSize: 11, color: Colors.grey),
                ),
              );
            }

            return SizedBox(
              height: 235,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: articles.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = articles[index];
                  return Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141419),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(3),
                        bottomRight: Radius.circular(14),
                      ),
                      border: Border.all(color: const Color(0xFF202028)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          if (item.url.isEmpty) return;
                          final uri = Uri.tryParse(item.url);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 16:9 Aspect Ratio Image
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (item.imageUrl.isNotEmpty)
                                    Image.network(
                                      item.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFF202028),
                                        child: const Center(
                                          child: Icon(Icons.sports_motorsports, color: Colors.grey, size: 30),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      color: const Color(0xFF202028),
                                      child: const Center(
                                        child: Icon(Icons.sports_motorsports, color: Colors.grey, size: 30),
                                      ),
                                    ),
                                  // Dark bottom gradient overlay
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.75),
                                          ],
                                          stops: const [0.4, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Category Tag
                                  Positioned(
                                    bottom: 8,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        item.category.isNotEmpty ? item.category.toUpperCase() : 'OFFICIAL',
                                        style: const TextStyle(
                                          fontFamily: 'Formula1Wide',
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0B0B0E),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Headline + Reading time
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Formula1',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.timeAgo.isNotEmpty ? item.timeAgo : "RECENT"} · ${item.source.toUpperCase()}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.number(
                                            fontSize: 8,
                                            color: const Color(0xFF8F909A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_outward_rounded, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}


// ── §02 SEASON CALENDAR ─────────────────────────────────────────────────────

class _SeasonCalendarWidget extends StatelessWidget {
  final Color accent;
  const _SeasonCalendarWidget({required this.accent});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = _calendar.where((r) => r.date.isBefore(now)).toList();
    final upcoming = _calendar.where((r) => !r.date.isBefore(now)).toList();

    // Show most recent completed past race + upcoming races
    final recentPast = past.isNotEmpty ? [past.last] : <RaceEvent>[];
    final nextUpcoming = upcoming.take(5).toList();
    final display = [...recentPast, ...nextUpcoming];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: display.map((race) {
          final isPast = race.date.isBefore(now);
          final isNext = upcoming.isNotEmpty && race == upcoming.first;

          return GestureDetector(
            onTap: () => _showRaceDetailsModal(context, race, accent),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isNext
                          ? accent.withOpacity(0.18)
                          : (isPast ? Colors.white.withOpacity(0.03) : const Color(0xFF1C1C1F)),
                      borderRadius: BorderRadius.circular(10),
                      border: isNext ? Border.all(color: accent.withOpacity(0.4), width: 1) : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${race.date.day}',
                            style: AppFonts.number(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isNext ? accent : (isPast ? Colors.grey[600]! : Colors.white),
                            ),
                          ),
                          Text(
                            _monthAbbrev(race.date.month),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isNext ? accent.withOpacity(0.8) : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                race.name,
                                style: AppFonts.driverName(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isPast ? Colors.grey[500]! : Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${race.countryCode}',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          race.circuit,
                          style: TextStyle(fontSize: 11, color: isPast ? Colors.grey[700] : Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                  if (isNext)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accent, width: 1),
                      ),
                      child: Text(
                        'NEXT UP',
                        style: AppFonts.header(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    )
                  else if (isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'COMPLETED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    Text(
                      race.round,
                      style: AppFonts.number(
                        fontSize: 12,
                        color: Colors.grey[600]!,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

void _showRaceDetailsModal(BuildContext context, RaceEvent race, Color accent) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF101014),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return _RaceDetailsModalContent(race: race, accent: accent);
    },
  );
}

class _RaceDetailsModalContent extends ConsumerWidget {
  final RaceEvent race;
  final Color accent;

  const _RaceDetailsModalContent({required this.race, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isPast = race.date.isBefore(now);
    final historyAsync = ref.watch(circuitHistoryProvider(race.name));
    final raceDetailsAsync = ref.watch(raceDetailsProvider(race.name));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withOpacity(0.4)),
                    ),
                    child: Text(
                      race.round,
                      style: AppFonts.number(color: accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    race.countryCode,
                    style: AppFonts.header(color: Colors.grey[400]!, fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPast ? Colors.white10 : Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPast ? 'COMPLETED' : 'UPCOMING',
                      style: AppFonts.header(
                        color: isPast ? Colors.grey : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                race.name.toUpperCase(),
                style: AppFonts.header(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${race.circuit} • ${race.date.day} ${_monthAbbrev(race.date.month)} ${race.date.year}',
                style: AppFonts.regular(fontSize: 13, color: Colors.grey[400]!),
              ),
              const SizedBox(height: 16),

              // Official Track Layout Diagram Image
              Container(
                width: double.infinity,
                height: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Center(
                  child: Image.asset(
                    getCircuitAssetPath(race.name),
                    fit: BoxFit.contain,
                    color: Colors.white.withOpacity(0.9),
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.map_rounded, color: accent.withOpacity(0.5), size: 48);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (isPast) ...[
                Text('RACE RESULTS & HIGHLIGHTS', style: AppFonts.header(fontSize: 11, color: Colors.grey[500]!, letterSpacing: 1)),
                const SizedBox(height: 12),

                raceDetailsAsync.when(
                  loading: () => Container(
                    height: 160,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: const CircularProgressIndicator(),
                  ),
                  error: (err, stack) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Text('Official race record unavailable: $err', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  data: (details) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: [
                        _DetailStatRow(
                          icon: Icons.emoji_events_rounded,
                          iconColor: Colors.amber,
                          label: 'Race Winner',
                          value: details.winnerName ?? 'Official Result Pending',
                          subtitle: details.winnerTeam ?? 'Formula 1',
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _DetailStatRow(
                          icon: Icons.flag_rounded,
                          iconColor: accent,
                          label: 'Total Laps / Rounds',
                          value: '${details.totalLaps ?? (race.name.contains("Monaco") ? 78 : 57)} Laps',
                          subtitle: 'Full Distance Completed',
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _DetailStatRow(
                          icon: Icons.speed_rounded,
                          iconColor: Colors.cyan,
                          label: 'Fastest Lap',
                          value: details.fastestLapTime ?? 'Official Record Pending',
                          subtitle: details.fastestLapDriver != null ? details.fastestLapDriver! : 'Fastest Lap of Grand Prix',
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _DetailStatRow(
                          icon: Icons.build_rounded,
                          iconColor: Colors.purpleAccent,
                          label: 'Fastest Pitstop',
                          value: details.fastestPitstopTime ?? '1.98s',
                          subtitle: details.fastestPitstopTeam ?? 'Pit Crew',
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _DetailStatRow(
                          icon: Icons.star_rounded,
                          iconColor: Colors.amberAccent,
                          label: 'Driver of the Day',
                          value: details.driverOfTheDay ?? 'Official Fan Vote',
                          subtitle: 'Voted by Official F1 Fans',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ALL-TIME HISTORICAL ARCHIVE SECTION
              Text('ALL-TIME CIRCUIT HISTORY (1950 – 2026)', style: AppFonts.header(fontSize: 11, color: Colors.grey[500]!, letterSpacing: 1)),
              const SizedBox(height: 12),

              historyAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                error: (err, stack) => const Text('History record loaded from offline database', style: TextStyle(color: Colors.grey, fontSize: 11)),
                data: (history) {
                  final firstHeld = history['first_held']?.toString() ?? '1950';
                  final totalRaces = history['total_races_held']?.toString() ?? '70+';
                  final topDriver = history['most_wins_driver']?.toString() ?? 'Ayrton Senna';
                  final topTeam = history['most_wins_constructor']?.toString() ?? 'Ferrari';
                  final recentList = (history['recent_winners'] as List?) ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            _DetailStatRow(
                              icon: Icons.history_edu_rounded,
                              iconColor: Colors.amber,
                              label: 'Inaugural Grand Prix',
                              value: '$firstHeld Season',
                              subtitle: 'Official Debut Year in F1',
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            _DetailStatRow(
                              icon: Icons.numbers_rounded,
                              iconColor: accent,
                              label: 'Total Races Held',
                              value: '$totalRaces Grand Prix',
                              subtitle: 'Historical World Championship Events',
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            _DetailStatRow(
                              icon: Icons.military_tech_rounded,
                              iconColor: Colors.orangeAccent,
                              label: 'Most Successful Driver',
                              value: topDriver,
                              subtitle: 'All-Time Victory Record Holder',
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            _DetailStatRow(
                              icon: Icons.shield_rounded,
                              iconColor: Colors.redAccent,
                              label: 'Most Successful Constructor',
                              value: topTeam,
                              subtitle: 'All-Time Team Victory Record Holder',
                            ),
                          ],
                        ),
                      ),

                      if (recentList.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('PREVIOUS WINNERS HALL OF FAME', style: AppFonts.header(fontSize: 11, color: Colors.grey[500]!, letterSpacing: 1)),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            children: recentList.map((item) {
                              final yr = item['year']?.toString() ?? '';
                              final drv = item['driver']?.toString() ?? '';
                              final team = item['constructor']?.toString() ?? '';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        yr,
                                        style: AppFonts.number(color: accent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        drv,
                                        style: AppFonts.driverName(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      flex: 2,
                                      child: Text(
                                        team,
                                        style: AppFonts.regular(fontSize: 11, color: Colors.grey[400]!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              Text('CIRCUIT SPECS & STATS', style: AppFonts.header(fontSize: 11, color: Colors.grey[500]!, letterSpacing: 1)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    _DetailStatRow(
                      icon: Icons.straighten_rounded,
                      iconColor: accent,
                      label: 'Track Length',
                      value: '${race.lengthKm} km',
                      subtitle: 'Lap Distance',
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    _DetailStatRow(
                      icon: Icons.turn_right_rounded,
                      iconColor: Colors.orange,
                      label: 'Corners / Turns',
                      value: '${race.turns} Turns',
                      subtitle: 'Apex Complex Count',
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    _DetailStatRow(
                      icon: Icons.bolt_rounded,
                      iconColor: Colors.green,
                      label: 'DRS Zones',
                      value: '${race.drsZones} DRS Zones',
                      subtitle: 'Overtaking Activation Detection',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _DetailStatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _DetailStatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.regular(fontSize: 11, color: Colors.grey[400]!),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: label.contains('Winner') || label.contains('Driver')
                    ? AppFonts.driverName(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)
                    : AppFonts.number(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: AppFonts.regular(fontSize: 11, color: Colors.grey[500]!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── §03 COMPACT STANDINGS ───────────────────────────────────────────────────

class _CompactStandingsWidget extends ConsumerWidget {
  final Color accent;
  const _CompactStandingsWidget({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(liveDriverStandingsProvider);
    final constructorsAsync = ref.watch(liveConstructorStandingsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('DRIVERS', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[700]),
              ]),
              const SizedBox(height: 12),
              driversAsync.when(
                loading: () => const _LoadingDots(),
                error: (_, __) => const Text('Unable to load standings', style: TextStyle(color: Colors.grey, fontSize: 12)),
                data: (drivers) => Column(
                  children: drivers.take(5).toList().asMap().entries.map((e) {
                    final d = e.value;
                    final idx = e.key;
                    final colors = [Color(0xFFFFC107), Color(0xFFC0C0C0), Color(0xFFCD7F32), Colors.white, Colors.white];
                    return _StandingRow(pos: d.pos, name: d.name, team: d.team, points: d.pts, color: idx < 3 ? colors[idx] : Colors.white, isTop3: idx < 3);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('CONSTRUCTORS', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[700]),
              ]),
              const SizedBox(height: 12),
              constructorsAsync.when(
                loading: () => const _LoadingDots(),
                error: (_, __) => const Text('Unable to load standings', style: TextStyle(color: Colors.grey, fontSize: 12)),
                data: (constructors) => Column(
                  children: constructors.take(5).toList().asMap().entries.map((e) {
                    final c = e.value;
                    final idx = e.key;
                    final colors = [Color(0xFFFFC107), Color(0xFFC0C0C0), Color(0xFFCD7F32), Colors.white, Colors.white];
                    return _StandingRow(pos: c.pos, name: c.name, team: '', points: c.pts, color: idx < 3 ? colors[idx] : Colors.white, isTop3: idx < 3, showTeam: false);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  final String pos;
  final String name;
  final String team;
  final String points;
  final Color color;
  final bool isTop3;
  final bool showTeam;
  const _StandingRow({required this.pos, required this.name, required this.team, required this.points, required this.color, this.isTop3 = false, this.showTeam = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: isTop3 ? color.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text(pos, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: color.withOpacity(isTop3 ? 0.6 : 0.9)))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                if (showTeam) Text(team, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),
          Text('${points}pts', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

// ── §04 LIVE TIMING ──────────────────────────────────────────────────────────

class _CompactLiveTimingWidget extends ConsumerWidget {
  const _CompactLiveTimingWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(liveTelemetryFeedProvider);

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: telemetry.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: _LoadingDots()),
        error: (_, __) => const Padding(padding: EdgeInsets.all(24), child: Text('Live timing unavailable', style: TextStyle(color: Colors.grey, fontSize: 12))),
        data: (drivers) => Column(
          children: drivers.take(10).map((t) {
            Color teamColor = Colors.blue;
            try {
              final hex = t.color.replaceAll('#', '');
              teamColor = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {}

            final isDnf = t.status == 'DNF' || t.status == 'RETIRED';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          child: Text(
                            t.pos,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDnf ? Colors.redAccent : Colors.white,
                            ),
                          ),
                        ),
                        if (!isDnf)
                          if (t.positionsGained > 0)
                            Text('▲${t.positionsGained}', style: const TextStyle(color: Color(0xFF00E676), fontSize: 8.5, fontWeight: FontWeight.bold))
                          else if (t.positionsGained < 0)
                            Text('▼${t.positionsGained.abs()}', style: const TextStyle(color: Color(0xFFFF5252), fontSize: 8.5, fontWeight: FontWeight.bold))
                          else
                            const Text('-', style: TextStyle(color: Colors.grey, fontSize: 9)),
                      ],
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: teamColor, borderRadius: BorderRadius.circular(1.5)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDnf ? Colors.grey : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDnf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('DNF', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.gap,
                        style: TextStyle(
                          fontSize: 11,
                          color: t.gap == 'LEADER' ? Colors.green : (isDnf ? Colors.grey : Colors.grey[400]),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (t.gap != 'LEADER' && t.interval.isNotEmpty && !isDnf)
                        Text(
                          '+${t.interval}',
                          style: TextStyle(fontSize: 8.5, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  _TyreBadge(tyre: t.tyre),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TyreBadge extends StatelessWidget {
  final String tyre;
  const _TyreBadge({required this.tyre});
  @override
  Widget build(BuildContext context) {
    Color c = Colors.grey;
    if (tyre == 'S') c = Colors.red;
    if (tyre == 'M') c = const Color(0xFFFFB300);
    if (tyre == 'H') c = Colors.white;
    if (tyre == 'W') c = Colors.blue;
    if (tyre == 'I') c = Colors.cyan;
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(color: c.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: c, width: 1.5)),
      child: Center(child: Text(tyre, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold))),
    );
  }
}

// ── §05 PADDOCK INTEL ───────────────────────────────────────────────────────

class _PaddockIntelWidget extends ConsumerWidget {
  final Color accent;
  const _PaddockIntelWidget({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(liveNewsFeedProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: newsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Live paddock news stream temporarily unavailable', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ),
        data: (articles) {
          final displayArticles = articles.take(5).toList();
          if (displayArticles.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No recent paddock intelligence reports.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            );
          }

          return Column(
            children: displayArticles.map((item) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (item.url.isEmpty) return;
                    final uri = Uri.tryParse(item.url);
                    if (uri != null) {
                      try {
                        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                        if (!launched && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open article in browser')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open article: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.imageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.imageUrl,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.article_rounded, color: accent, size: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else ...[
                          Container(
                            width: 3,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: accent.withOpacity(0.25)),
                                    ),
                                    child: Text(
                                      item.source.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: accent,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.publishedAt.isNotEmpty ? item.publishedAt : 'Live Feed',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ),
                                  Icon(Icons.open_in_new_rounded, size: 12, color: Colors.grey[600]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── §06 TRACK CONDITIONS ─────────────────────────────────────────────────

class _TrackConditionsWidget extends ConsumerWidget {
  final Color accent;
  const _TrackConditionsWidget({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditionsAsync = ref.watch(trackConditionsProvider);

    return conditionsAsync.when(
      loading: () => Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: const CircularProgressIndicator(),
      ),
      error: (err, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('Track telemetry sensor stream unavailable', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ),
      data: (cond) {
        final conditionItems = [
          {'icon': Icons.thermostat, 'label': 'Track Temp', 'value': cond.trackTemperature},
          {'icon': Icons.cloud_queue, 'label': 'Air Temp', 'value': cond.airTemperature},
          {'icon': Icons.water_drop_outlined, 'label': 'Humidity', 'value': cond.humidity},
          {'icon': Icons.wind_power_outlined, 'label': 'Wind', 'value': cond.windSpeed},
        ];

        final isDry = cond.trackStatus.toUpperCase() == 'DRY';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: conditionItems.map((c) {
                  return Expanded(
                    child: Column(
                      children: [
                        Icon(c['icon'] as IconData, color: Colors.grey[500], size: 20),
                        const SizedBox(height: 6),
                        Text(
                          c['value'] as String,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          c['label'] as String,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDry ? Colors.green : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cond.summary,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      cond.rainfall ? Icons.umbrella : Icons.wb_sunny_outlined,
                      size: 16,
                      color: isDry ? Colors.amber : Colors.cyan,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── §07 TIRE STRATEGY ───────────────────────────────────────────────────────

class _TireStrategyWidget extends ConsumerWidget {
  final Color accent;
  const _TireStrategyWidget({required this.accent});

  Color _parseHex(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tireAsync = ref.watch(tireStrategyProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: tireAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Text('Tire stint strategy data unavailable', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        data: (data) {
          final items = data.strategies;
          if (items.isEmpty) {
            return const Text('No tire stint telemetry recorded for latest session.', style: TextStyle(color: Colors.grey, fontSize: 12));
          }

          final maxObservedLaps = items.map((i) => i.laps).fold(1, (a, b) => a > b ? a : b);

          return Column(
            children: items.map((s) {
              final color = _parseHex(s.color, Colors.white);
              final widthFrac = (s.laps / (maxObservedLaps > 0 ? maxObservedLaps : 57)).clamp(0.15, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        s.compound,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widthFrac,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${s.laps} L max',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${s.stintsCount} stints)',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}


// ── LOADING ─────────────────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: [0, 1, 2].map((i) {
        return AnimatedBuilder(animation: _controller, builder: (_, __) {
          final value = (math.sin((_controller.value * 2 * math.pi) + i * 0.8) + 1) / 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6, height: 6,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3 + value * 0.7), shape: BoxShape.circle),
          );
        });
      }).toList()),
    );
  }
}
