import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../data/calendar_provider.dart';
import '../widgets/gp_hero_widget.dart';
import '../widgets/race_control_widget.dart';
import '../widgets/race_pulse_widget.dart';
import '../widgets/news_rail_widget.dart';
import '../widgets/season_calendar_widget.dart';
import '../widgets/race_recaps_widget.dart';
import '../../../../shared/widgets/error_retry_widget.dart';

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
    final backendReachable = ref.watch(backendReachableProvider);

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: DSAppBar(
        subtitle: 'PITWALL TELEMETRY',
        isLive: isLive,
        liveLabel: isLive ? 'LIVE' : null,
        latencyMs: '12',
      ),
      body: Column(
        children: [
          DSTickerStrip(
            text: 'TRACK STATUS: ${isLive ? "GREEN FLAG" : "CIRCUIT ACTIVE"} // TRK 44.2°C // AIR 28.1°C // WIND 14 KM/H HEADWIND // NEXT: ${nextRace?.name ?? "UPCOMING GP"}',
            dotColor: isLive ? DS.green : DS.teal,
          ),
          if (!backendReachable) const BackendOfflineBanner(),
          Expanded(child: _buildScrollBody(context, accentColor)),
        ],
      ),
    );
  }

  Widget _buildScrollBody(BuildContext context, Color accentColor) {
    return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GPHeroWidget(accent: accentColor),
            const SizedBox(height: 16),
            RaceControlWidget(accent: accentColor),
            const SizedBox(height: 16),
            RacePulseWidget(accent: accentColor),
            const SizedBox(height: 16),
            // Section header — Paddock Telemetry Dispatch
            Row(
              children: [
                Container(width: 3, height: 14, color: DS.orange),
                const SizedBox(width: 8),
                Text('PADDOCK TELEMETRY DISPATCH', style: DS.driverCode(size: 11)),
                const Spacer(),
                Text('LATEST', style: DS.labelCaps(size: 8)),
              ],
            ),
            const SizedBox(height: 10),
            NewsRailWidget(accent: accentColor),
            const SizedBox(height: 16),
            // Section header — Race Recaps
            Row(
              children: [
                Container(width: 3, height: 14, color: DS.red),
                const SizedBox(width: 8),
                Text('RACE RECAPS', style: DS.driverCode(size: 11)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/history'),
                  child: Text('VIEW ARCHIVE', style: DS.labelCaps(size: 8, color: DS.teal)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            RaceRecapsWidget(accent: accentColor),
            const SizedBox(height: 16),
            // Section header — Season Calendar
            Row(
              children: [
                Container(width: 3, height: 14, color: DS.teal),
                const SizedBox(width: 8),
                Text('SEASON CALENDAR PROGRESS', style: DS.driverCode(size: 11)),
                const Spacer(),
                Text('24 ROUNDS', style: DS.labelCaps(size: 8)),
              ],
            ),
            const SizedBox(height: 10),
            SeasonCalendarWidget(accent: accentColor),
            const SizedBox(height: 20),
            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go('/live'),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(color: DS.red, borderRadius: DS.aeroCorner),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.speed, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('LIVE SECTOR SPLITS', style: DS.labelCaps(size: 9, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go('/live'),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: DS.surface1,
                        borderRadius: DS.aeroCorner,
                        border: Border.all(color: DS.outline),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.build_outlined, size: 14, color: Color(0xFF29DEC9)),
                          const SizedBox(width: 6),
                          Text('PIT STRATEGY MATRIX', style: DS.labelCaps(size: 9, color: DS.teal)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Footer
            Center(
              child: Text(
                'APEX F1 v2.1.0 · Powered by Sportradar · FIA Data',
                style: DS.labelCaps(size: 8, color: DS.textMuted),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
    );
  }
}
