import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../data/calendar_provider.dart';
import '../widgets/gp_hero_widget.dart';
import '../widgets/race_control_widget.dart';
import '../widgets/race_pulse_widget.dart';
import '../widgets/news_rail_widget.dart';
import '../widgets/season_calendar_widget.dart';

export '../../data/calendar_provider.dart' show RaceEvent, getCircuitAssetPath, getCountryFlag, monthAbbrev, calendarProvider, nextRaceProvider, circuitHistoryProvider;

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
    final accentColor = themeState.selectedTeam.primaryColor;
    final sessionStatusAsync = ref.watch(sessionLiveStatusProvider);
    final isLive = sessionStatusAsync.value?.isLive ?? false;
    final nextRace = ref.watch(nextRaceProvider);

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
              Text('APEX', style: AppFonts.wide(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(width: 4),
              Text('F1', style: AppFonts.wide(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFFF1744))),
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
                if (nextRace != null)
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
            GPHeroWidget(accent: accentColor),
            const SizedBox(height: 22),
            RaceControlWidget(accent: accentColor),
            const SizedBox(height: 22),
            RacePulseWidget(accent: accentColor),
            const SizedBox(height: 22),
            NewsRailWidget(accent: accentColor),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'SEASON CALENDAR',
                    style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('2026 ROUNDS', style: AppFonts.number(fontSize: 9, color: Colors.grey[500]!, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            SeasonCalendarWidget(accent: accentColor),
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
