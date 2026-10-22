import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/widgets/pro_gate.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../data/track_database.dart';

enum LiveMode { timing, map, radio, tyres }

class LiveTrackerScreen extends ConsumerStatefulWidget {
  const LiveTrackerScreen({super.key});

  @override
  ConsumerState<LiveTrackerScreen> createState() => _LiveTrackerScreenState();
}

class _LiveTrackerScreenState extends ConsumerState<LiveTrackerScreen>
    with SingleTickerProviderStateMixin {
  LiveMode _selectedMode = LiveMode.timing;
  String _selectedDriverCode = 'NOR';
  String? _currentlyPlayingRadioId;
  late AnimationController _waveAnimController;
  Timer? _playbackTimer;
  int _playbackProgressMs = 0;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _waveAnimController.dispose();
    super.dispose();
  }

  void _toggleRadioPlayback(String radioId) {
    setState(() {
      if (_currentlyPlayingRadioId == radioId) {
        _currentlyPlayingRadioId = null;
        _playbackTimer?.cancel();
        _playbackProgressMs = 0;
      } else {
        _currentlyPlayingRadioId = radioId;
        _playbackProgressMs = 0;
        _playbackTimer?.cancel();
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _playbackProgressMs += 200;
            if (_playbackProgressMs >= 17000) {
              _playbackProgressMs = 0;
              _currentlyPlayingRadioId = null;
              timer.cancel();
            }
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;
    final telemetryAsync = ref.watch(liveTelemetryFeedProvider);
    final radioAsync = ref.watch(teamRadioFeedProvider);
    final eventsAsync = ref.watch(raceEventsFeedProvider);
    final latestSessionAsync = ref.watch(latestSessionProvider);
    final sessionStatusAsync = ref.watch(sessionLiveStatusProvider);
    final flagStatusAsync = ref.watch(raceFlagStatusProvider);

    final sessionStatus = sessionStatusAsync.value;
    final isLive = sessionStatus?.isLive ?? false;
    final meetingName = sessionStatus?.meetingName ??
        latestSessionAsync.value?.meetingName ??
        'Australian Grand Prix';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            // Apex Logo mark
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'A',
                style: TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'APEX ',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  TextSpan(
                    text: 'F1',
                    style: TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFFFF1744),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Live / Simulated status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: (isLive ? const Color(0xFF00E676) : Colors.white24)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLive
                      ? const Color(0xFF00E676).withValues(alpha: 0.6)
                      : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isLive ? const Color(0xFF00E676) : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isLive ? 'RACE LIVE' : 'SIMULATED',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isLive ? const Color(0xFF00E676) : Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ProGateWidget(
        featureName: 'Live Telemetry & Race Center',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meetingName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'LIVE TIMING',
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF19191F),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF282832)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'R01 · MEL',
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 9.5,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lap Progress Header Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141419),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(3),
                    bottomRight: Radius.circular(10),
                  ),
                  border: Border.all(color: const Color(0xFF202028)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'LAP 34',
                              style: TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ 58',
                              style: TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '58.6%',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 5,
                        width: double.infinity,
                        color: const Color(0xFF202028),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.586,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentColor.withValues(alpha: 0.6), accentColor],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Live Flag / Race Control Banner
              _FigmaSessionFlagBanner(status: flagStatusAsync.value),
              const SizedBox(height: 12),

              // Figma Mode Switcher (TIMING, MAP, RADIO, TYRES)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F13),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF202028)),
                ),
                child: Row(
                  children: [
                    _buildSegmentButton(LiveMode.timing, 'TIMING'),
                    _buildSegmentButton(LiveMode.map, 'MAP'),
                    _buildSegmentButton(LiveMode.radio, 'RADIO'),
                    _buildSegmentButton(LiveMode.tyres, 'TYRES'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // View Body based on Mode Switcher
              if (_selectedMode == LiveMode.timing) ...[
                _buildTimingTower(telemetryAsync),
              ] else if (_selectedMode == LiveMode.map) ...[
                _buildTrackMapPanel(telemetryAsync, meetingName, accentColor),
              ] else if (_selectedMode == LiveMode.radio) ...[
                _buildTeamRadioPanel(radioAsync, accentColor),
              ] else if (_selectedMode == LiveMode.tyres) ...[
                _buildTyreStrategyPanel(telemetryAsync, accentColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton(LiveMode mode, String title) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Formula1Wide',
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: isSelected ? const Color(0xFF09090C) : const Color(0xFF8F909A),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 1. TIMING TOWER
  // ---------------------------------------------------------
  Widget _buildTimingTower(AsyncValue<List<LiveTelemetry>> telemetryAsync) {
    return telemetryAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => _buildTimingFallbackTower(),
      data: (telemetryList) {
        if (telemetryList.isEmpty) {
          return _buildTimingFallbackTower();
        }

        // Identify selected driver data
        final selectedDriver = telemetryList.firstWhere(
          (d) =>
              (getDriverData(d.name)?.code ?? '').toUpperCase() ==
                  _selectedDriverCode ||
              d.name.toLowerCase().contains(_selectedDriverCode.toLowerCase()),
          orElse: () => telemetryList.first,
        );

        return Column(
          children: [
            // Tower column labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 72,
                    child: Text(
                      'POS / DRIVER',
                      style: TextStyle(
                        fontFamily: 'Formula1',
                        color: Color(0xFF5F606B),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'GAP / INT',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      color: Color(0xFF5F606B),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Text(
                    'TYRE',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      color: Color(0xFF5F606B),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 28),
                  const Text(
                    'LAST LAP',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      color: Color(0xFF5F606B),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Rows list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: telemetryList.length,
              itemBuilder: (context, index) {
                final d = telemetryList[index];
                final driverMeta = getDriverData(d.name);
                final code = driverMeta?.code ?? d.name.split(' ').last.substring(0, 3).toUpperCase();
                final isSelected = code == _selectedDriverCode;

                Color teamColor = Colors.white;
                try {
                  final hex = d.color.replaceAll('#', '');
                  teamColor = Color(int.parse('FF$hex', radix: 16));
                } catch (_) {
                  teamColor = getDriverTeamColor(d.name);
                }

                return _FigmaTimingRowWidget(
                  pos: d.pos,
                  code: code,
                  name: d.name,
                  team: d.team,
                  driverNumber: d.driverNumber,
                  gap: d.gap,
                  interval: d.interval,
                  positionsGained: d.positionsGained,
                  status: d.status,
                  dnfReason: d.dnfReason,
                  tyre: d.tyre,
                  tyreLife: d.tyreLife,
                  pitStops: d.pitStops,
                  lastLap: d.lastLap,
                  isFastestLap: d.bestLap.isNotEmpty && d.bestLap != '-',
                  drs: d.drs,
                  teamColor: teamColor,
                  isSelected: isSelected,
                  portraitAsset: driverMeta?.portraitAsset ?? '',
                  onTap: () => setState(() => _selectedDriverCode = code),
                );
              },
            ),
            const SizedBox(height: 12),

            // Pinned Onboard Telemetry Strip
            _FigmaTelemetryStrip(
              driverName: selectedDriver.name,
              driverCode: _selectedDriverCode,
              speedKph: selectedDriver.speed.isNotEmpty && selectedDriver.speed != '-'
                  ? selectedDriver.speed.replaceAll(' km/h', '')
                  : '294',
              gear: selectedDriver.gear.isNotEmpty && selectedDriver.gear != '-'
                  ? selectedDriver.gear
                  : '8',
              throttlePct: '97',
              ersPct: '61',
              isDnf: selectedDriver.status == 'DNF' || selectedDriver.status == 'RETIRED',
            ),
          ],
        );
      },
    );
  }

  // Fallback Timing Tower with 2026 Drivers
  Widget _buildTimingFallbackTower() {
    final drivers = kDrivers2026List;
    final selectedDriver = drivers.firstWhere(
      (d) => d.code == _selectedDriverCode,
      orElse: () => drivers.first,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const SizedBox(
                width: 72,
                child: Text(
                  'POS / DRIVER',
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    color: Color(0xFF5F606B),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'GAP / INT',
                style: TextStyle(
                  fontFamily: 'Formula1',
                  color: Color(0xFF5F606B),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 24),
              const Text(
                'TYRE',
                style: TextStyle(
                  fontFamily: 'Formula1',
                  color: Color(0xFF5F606B),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 28),
              const Text(
                'LAST LAP',
                style: TextStyle(
                  fontFamily: 'Formula1',
                  color: Color(0xFF5F606B),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            final pos = (index + 1).toString();
            final isSelected = driver.code == _selectedDriverCode;
            final teamColor = getTeamColor(driver.team);
            final isFastest = driver.code == 'PIA';
            final isDnf = driver.code == 'ALB';
            final isPit = driver.code == 'TSU';
            final gap = index == 0
                ? 'LEADER'
                : isDnf
                    ? 'OUT'
                    : '+${(index * 1.842).toStringAsFixed(3)}s';
            final interval = index == 0
                ? '—'
                : '+${(1.2 + (index % 3) * 0.4).toStringAsFixed(3)}s';
            final tyre = index % 3 == 0 ? 'S' : (index % 3 == 1 ? 'M' : 'H');
            final tyreAge = '${14 + (index * 2)}L';
            final lastLap = isDnf
                ? 'RETIRED'
                : (isFastest ? '1:21.733' : '1:22.${(800 + index * 42)}');

            return _FigmaTimingRowWidget(
              pos: pos,
              code: driver.code,
              name: driver.name,
              team: driver.team,
              driverNumber: int.tryParse(driver.code.hashCode.abs().toString().substring(0, 2)) ?? (index + 1),
              gap: gap,
              interval: interval,
              positionsGained: (index % 5 == 1) ? 2 : ((index % 4 == 0) ? -1 : 0),
              status: isDnf ? 'DNF' : (isPit ? 'PIT' : 'RACING'),
              dnfReason: isDnf ? 'Power Unit Failure' : '',
              tyre: tyre,
              tyreLife: tyreAge,
              pitStops: (index > 8) ? 2 : 1,
              lastLap: lastLap,
              isFastestLap: isFastest,
              drs: index % 2 == 1 && !isDnf,
              teamColor: teamColor,
              isSelected: isSelected,
              portraitAsset: driver.portraitAsset,
              onTap: () => setState(() => _selectedDriverCode = driver.code),
            );
          },
        ),
        const SizedBox(height: 12),

        _FigmaTelemetryStrip(
          driverName: selectedDriver.name,
          driverCode: _selectedDriverCode,
          speedKph: selectedDriver.code == 'ALB' ? '0' : '294',
          gear: selectedDriver.code == 'ALB' ? 'N' : '8',
          throttlePct: selectedDriver.code == 'ALB' ? '0' : '97',
          ersPct: '61',
          isDnf: selectedDriver.code == 'ALB',
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 2. TRACK MAP VIEW
  // ---------------------------------------------------------
  Widget _buildTrackMapPanel(
    AsyncValue<List<LiveTelemetry>> telemetryAsync,
    String meetingName,
    Color accentColor,
  ) {
    final telemetryList = telemetryAsync.value ?? [];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF202028)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE TRACK',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 9,
                          color: Color(0xFF8F909A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meetingName.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Formula1',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00E676), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFF00E676)),
                        SizedBox(width: 5),
                        Text(
                          'TRACK CLEAR',
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive Track Canvas with Driver Markers
              Container(
                height: 230,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: CustomPaint(
                  painter: _TrackPainter(
                    accentColor,
                    telemetryList,
                    meetingName,
                    isLive: true,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Sector & DRS Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMapLegendItem(const Color(0xFFFFD600), 'SECTOR 1'),
                  _buildMapLegendItem(const Color(0xFF00E5FF), 'SECTOR 2'),
                  _buildMapLegendItem(const Color(0xFFB388FF), 'SECTOR 3'),
                  _buildMapLegendItem(const Color(0xFF00E676), 'DRS ZONE'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bottom Telemetry Strip for Selected Driver
        _FigmaTelemetryStrip(
          driverName: _selectedDriverCode,
          driverCode: _selectedDriverCode,
          speedKph: '294',
          gear: '8',
          throttlePct: '97',
          ersPct: '61',
        ),
      ],
    );
  }

  Widget _buildMapLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Formula1',
            fontSize: 9,
            color: Color(0xFF8F909A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 3. TEAM RADIO PANEL
  // ---------------------------------------------------------
  Widget _buildTeamRadioPanel(
    AsyncValue<List<TeamRadioItem>> radioAsync,
    Color accentColor,
  ) {
    return radioAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => _buildFallbackRadioList(accentColor),
      data: (radios) {
        if (radios.isEmpty) {
          return _buildFallbackRadioList(accentColor);
        }
        return _buildRadioList(radios, accentColor);
      },
    );
  }

  Widget _buildRadioList(List<TeamRadioItem> radios, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202028)),
          ),
          child: Row(
            children: [
              Icon(Icons.podcasts_rounded, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TEAM RADIO STREAM',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${radios.length} MESSAGES · LIVE SESSION',
                    style: const TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontSize: 8.5,
                      color: Color(0xFF8F909A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontFamily: 'Formula1Wide',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: radios.length,
          itemBuilder: (context, index) {
            final r = radios[index];
            final isPlaying = _currentlyPlayingRadioId == r.id;
            final teamColor = getTeamColor(r.team);
            final driverMeta = getDriverData(r.driverName);

            return _FigmaRadioCard(
              id: r.id,
              driverName: r.driverName,
              teamName: r.team,
              timestamp: r.timestamp,
              transcript: r.transcript,
              teamColor: teamColor,
              portraitAsset: driverMeta?.portraitAsset ?? '',
              isPlaying: isPlaying,
              progressRatio: isPlaying ? (_playbackProgressMs / 17000).clamp(0.0, 1.0) : 0.0,
              elapsedStr: isPlaying
                  ? '0:0${(_playbackProgressMs ~/ 1000).toString().padLeft(2, '0')} / 0:17'
                  : '0:00 / 0:17',
              anim: _waveAnimController,
              onTogglePlay: () => _toggleRadioPlayback(r.id),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFallbackRadioList(Color accentColor) {
    final simulatedRadios = [
      TeamRadioItem(
        id: 'radio_nor_1',
        driverName: 'Lando Norris',
        driverNumber: 4,
        team: 'McLaren',
        timestamp: 'LAP 33 · 14:48',
        transcript: 'Box this lap. Confirm box. We are switching to plan C.',
        audioUrl: '',
        color: '#FF8000',
      ),
      TeamRadioItem(
        id: 'radio_lec_1',
        driverName: 'Charles Leclerc',
        driverNumber: 16,
        team: 'Ferrari',
        timestamp: 'LAP 31 · 14:45',
        transcript: 'Mode push. Gap behind to Piastri is three point seven seconds.',
        audioUrl: '',
        color: '#E8002D',
      ),
      TeamRadioItem(
        id: 'radio_ver_1',
        driverName: 'Max Verstappen',
        driverNumber: 1,
        team: 'Red Bull Racing',
        timestamp: 'LAP 28 · 14:41',
        transcript: 'Safety car window is open. Tyre degradation is manageable, stay out.',
        audioUrl: '',
        color: '#3671C6',
      ),
    ];
    return _buildRadioList(simulatedRadios, accentColor);
  }

  // ---------------------------------------------------------
  // 4. TYRE STRATEGY PANEL
  // ---------------------------------------------------------
  Widget _buildTyreStrategyPanel(
    AsyncValue<List<LiveTelemetry>> telemetryAsync,
    Color accentColor,
  ) {
    final drivers = kDrivers2026List.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compound Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202028)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompoundLegendBadge('S', 'SOFT', const Color(0xFFFF1744)),
              _buildCompoundLegendBadge('M', 'MEDIUM', const Color(0xFFFFD600)),
              _buildCompoundLegendBadge('H', 'HARD', Colors.white),
              _buildCompoundLegendBadge('I', 'INTER', const Color(0xFF00E676)),
              _buildCompoundLegendBadge('W', 'WET', const Color(0xFF00B0FF)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Driver stint rows
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            final pos = (index + 1).toString();
            final teamColor = getTeamColor(driver.team);
            final softWidth = 25.0 + (index % 4) * 6;
            final tyre = index % 3 == 0 ? 'S' : (index % 3 == 1 ? 'M' : 'H');
            final tyreAge = '${14 + index}L';
            final pitWindow = index % 3 == 0 ? 'BOX NOW' : 'L${40 + index}–${43 + index}';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(8),
                ),
                border: Border.all(color: const Color(0xFF202028)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: teamColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    child: Text(
                      pos,
                      style: const TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      driver.code,
                      style: const TextStyle(
                        fontFamily: 'Formula1',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Stint bars
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: softWidth,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1744).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFFFF1744), width: 1),
                          ),
                          child: const Text(
                            'S',
                            style: TextStyle(
                              fontFamily: 'Formula1',
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF1744),
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Container(
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: (tyre == 'H' ? Colors.white : const Color(0xFFFFD600))
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: tyre == 'H' ? Colors.white70 : const Color(0xFFFFD600),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$tyre · $tyreAge',
                              style: TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: tyre == 'H' ? Colors.white : const Color(0xFFFFD600),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: pitWindow == 'BOX NOW'
                          ? const Color(0xFFFF9100).withValues(alpha: 0.25)
                          : const Color(0xFF19191F),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: pitWindow == 'BOX NOW'
                            ? const Color(0xFFFF9100)
                            : const Color(0xFF282832),
                      ),
                    ),
                    child: Text(
                      pitWindow,
                      style: TextStyle(
                        fontFamily: 'Formula1',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: pitWindow == 'BOX NOW'
                            ? const Color(0xFFFF9100)
                            : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Undercut Pitwall Prediction Callout Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202028)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFFD600),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PITWALL STRATEGY CALL',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 9,
                        color: Color(0xFFFFD600),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Undercut Window Opening',
                      style: TextStyle(
                        fontFamily: 'Formula1',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Medium tyre runners gain an estimated 1.8s by stopping before lap 39 against hard runners.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF8F909A),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompoundLegendBadge(String code, String name, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.3),
          ),
          child: Center(
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'Formula1',
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'Formula1',
            fontSize: 9,
            color: Color(0xFF8F909A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// TIMING ROW COMPONENT
// -------------------------------------------------------------
class _FigmaTimingRowWidget extends StatelessWidget {
  final String pos;
  final String code;
  final String name;
  final String team;
  final int driverNumber;
  final String gap;
  final String interval;
  final int positionsGained;
  final String status;
  final String dnfReason;
  final String tyre;
  final String tyreLife;
  final int pitStops;
  final String lastLap;
  final bool isFastestLap;
  final bool drs;
  final Color teamColor;
  final bool isSelected;
  final String portraitAsset;
  final VoidCallback onTap;

  const _FigmaTimingRowWidget({
    required this.pos,
    required this.code,
    required this.name,
    required this.team,
    required this.driverNumber,
    required this.gap,
    required this.interval,
    required this.positionsGained,
    required this.status,
    required this.dnfReason,
    required this.tyre,
    required this.tyreLife,
    required this.pitStops,
    required this.lastLap,
    required this.isFastestLap,
    required this.drs,
    required this.teamColor,
    required this.isSelected,
    required this.portraitAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDnf = status == 'DNF' || status == 'RETIRED';
    final isPit = status == 'PIT';

    Color tyreColor = Colors.white;
    if (tyre == 'S') tyreColor = const Color(0xFFFF1744);
    if (tyre == 'M') tyreColor = const Color(0xFFFFD600);
    if (tyre == 'H') tyreColor = Colors.white;
    if (tyre == 'I') tyreColor = const Color(0xFF00E676);
    if (tyre == 'W') tyreColor = const Color(0xFF00B0FF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isDnf
              ? const Color(0xFF1E1012)
              : isSelected
                  ? Color.lerp(teamColor.withValues(alpha: 0.12), const Color(0xFF141419), 0.7)
                  : const Color(0xFF141419),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(7),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(7),
          ),
          border: Border.all(
            color: isSelected ? teamColor.withValues(alpha: 0.7) : const Color(0xFF202028),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3.5,
              height: 22,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            // 1. Position & Delta
            SizedBox(
              width: 30,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    pos,
                    style: TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDnf ? const Color(0xFFFF5252) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  if (!isDnf)
                    if (positionsGained > 0)
                      Text(
                        '▲$positionsGained',
                        style: const TextStyle(
                          fontFamily: 'Formula1',
                          color: Color(0xFF00E676),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (positionsGained < 0)
                      Text(
                        '▼${positionsGained.abs()}',
                        style: const TextStyle(
                          fontFamily: 'Formula1',
                          color: Color(0xFFFF5252),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        '—',
                        style: TextStyle(color: Colors.grey, fontSize: 8),
                      ),
                ],
              ),
            ),
            const SizedBox(width: 4),

            // 2. Driver Portrait Avatar with team ring
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222228),
                border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: portraitAsset.isNotEmpty
                  ? Image.asset(
                      portraitAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          code,
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: teamColor,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        code,
                        style: TextStyle(
                          fontFamily: 'Formula1',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: teamColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),

            // 3. Driver Code, Number, Team
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'Formula1',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '#$driverNumber',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 8,
                          color: teamColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    team,
                    style: const TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 8.5,
                      color: Color(0xFF8F909A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 4. Gap & Interval
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDnf)
                    const Text(
                      'OUT',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF1744),
                      ),
                    )
                  else if (isPit)
                    const Text(
                      'IN PIT',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF9100),
                      ),
                    )
                  else
                    Text(
                      gap,
                      style: TextStyle(
                        fontFamily: 'Formula1',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: gap == 'LEADER' ? const Color(0xFF00E676) : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 1),
                  Text(
                    isDnf
                        ? (dnfReason.isNotEmpty ? dnfReason : 'CRASH')
                        : isPit
                            ? 'STOP $pitStops'
                            : 'INT $interval',
                    style: const TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 7.5,
                      color: Color(0xFF8F909A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 5. DRS + Compound Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (drs && !isDnf) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF00E676), width: 0.8),
                    ),
                    child: const Text(
                      'DRS',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 6.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: tyreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: tyreColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tyre,
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: tyreColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        tyreLife.replaceAll(' laps', '').replaceAll('L', ''),
                        style: TextStyle(
                          fontFamily: 'Formula1',
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: tyreColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // 6. Last Lap / Fastest Lap
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lastLap,
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: isFastestLap ? const Color(0xFFB388FF) : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isFastestLap ? 'FASTEST' : 'LAST LAP',
                    style: TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontSize: 6.5,
                      fontWeight: FontWeight.bold,
                      color: isFastestLap ? const Color(0xFFB388FF) : const Color(0xFF5F606B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// ONBOARD TELEMETRY STRIP COMPONENT
// -------------------------------------------------------------
class _FigmaTelemetryStrip extends StatelessWidget {
  final String driverName;
  final String driverCode;
  final String speedKph;
  final String gear;
  final String throttlePct;
  final String ersPct;
  final bool isDnf;

  const _FigmaTelemetryStrip({
    required this.driverName,
    required this.driverCode,
    required this.speedKph,
    required this.gear,
    required this.throttlePct,
    required this.ersPct,
    this.isDnf = false,
  });

  @override
  Widget build(BuildContext context) {
    final driverMeta = getDriverData(driverCode);
    final teamColor = getTeamColor(driverMeta?.team ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202028)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Onboard Driver info
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF222228),
                  border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: driverMeta != null && driverMeta.portraitAsset.isNotEmpty
                    ? Image.asset(
                        driverMeta.portraitAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            driverCode,
                            style: TextStyle(
                              fontFamily: 'Formula1',
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: teamColor,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          driverCode,
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: teamColor,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ONBOARD',
                    style: TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontSize: 7.5,
                      color: Color(0xFF8F909A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    driverCode,
                    style: const TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Speed
          _buildStatCol(
            isDnf ? '0' : speedKph,
            'KM/H',
            const Color(0xFF00E676),
          ),

          // Gear
          _buildStatCol(
            isDnf ? 'N' : gear,
            'GEAR',
            Colors.white,
          ),

          // Throttle
          _buildStatCol(
            isDnf ? '0%' : '$throttlePct%',
            'THR %',
            const Color(0xFFFFD600),
          ),

          // ERS
          _buildStatCol(
            '$ersPct%',
            'ERS %',
            const Color(0xFF00E5FF),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String value, String label, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Formula1Wide',
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Formula1',
            fontSize: 7.5,
            color: Color(0xFF8F909A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// TEAM RADIO CARD COMPONENT
// -------------------------------------------------------------
class _FigmaRadioCard extends StatelessWidget {
  final String id;
  final String driverName;
  final String teamName;
  final String timestamp;
  final String transcript;
  final Color teamColor;
  final String portraitAsset;
  final bool isPlaying;
  final double progressRatio;
  final String elapsedStr;
  final Animation<double> anim;
  final VoidCallback onTogglePlay;

  const _FigmaRadioCard({
    required this.id,
    required this.driverName,
    required this.teamName,
    required this.timestamp,
    required this.transcript,
    required this.teamColor,
    required this.portraitAsset,
    required this.isPlaying,
    required this.progressRatio,
    required this.elapsedStr,
    required this.anim,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPlaying ? teamColor.withValues(alpha: 0.6) : const Color(0xFF202028),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 3.5,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF222228),
                  border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: portraitAsset.isNotEmpty
                    ? Image.asset(
                        portraitAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      )
                    : const SizedBox(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timestamp.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 8,
                        color: Color(0xFF8F909A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontFamily: 'Formula1',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      teamName,
                      style: TextStyle(
                        fontFamily: 'Formula1',
                        fontSize: 8.5,
                        color: teamColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTogglePlay,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPlaying ? teamColor : Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: isPlaying ? Colors.black : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Animated Waveform
          AnimatedBuilder(
            animation: anim,
            builder: (context, child) {
              return Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(36, (index) {
                    final baseHeight = 6.0 + ((index * 13) % 20);
                    final oscillation = isPlaying ? sin(anim.value * pi + index * 0.3) * 6 : 0;
                    final h = (baseHeight + oscillation).clamp(4.0, 26.0);

                    final isPassed = isPlaying && (index / 36.0) <= progressRatio;

                    return Container(
                      width: 2.5,
                      height: h,
                      decoration: BoxDecoration(
                        color: isPassed
                            ? teamColor
                            : (isPlaying
                                ? teamColor.withValues(alpha: 0.4)
                                : Colors.white24),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Transcript
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '“$transcript”',
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Elapsed Audio Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                elapsedStr,
                style: const TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontSize: 8,
                  color: Color(0xFF8F909A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPlaying)
                Text(
                  'AUDIO PLAYING',
                  style: TextStyle(
                    fontFamily: 'Formula1Wide',
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    color: teamColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// SESSION FLAG BANNER
// -------------------------------------------------------------
class _FigmaSessionFlagBanner extends StatelessWidget {
  final RaceFlagStatus? status;

  const _FigmaSessionFlagBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const SizedBox.shrink();
    }

    Color bannerColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    if (status!.isRedFlag) {
      bannerColor = const Color(0xFFFF1744);
      textColor = Colors.white;
      icon = Icons.flag_rounded;
      title = 'RED FLAG — SESSION SUSPENDED';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Track blocked / hazardous condition. Return to pitlane.';
    } else if (status!.isSafetyCar) {
      bannerColor = const Color(0xFFFF9100);
      textColor = Colors.black;
      icon = Icons.warning_rounded;
      title = 'SAFETY CAR DEPLOYED (FULL SC)';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Reduce speed, maintain delta, no overtaking.';
    } else if (status!.isVsc) {
      bannerColor = const Color(0xFFFF9100);
      textColor = Colors.black;
      icon = Icons.speed_rounded;
      title = 'VIRTUAL SAFETY CAR (VSC)';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Observe positive delta. Pit lane speed limit applies.';
    } else if (status!.isYellowFlag) {
      bannerColor = const Color(0xFFFFD600);
      textColor = Colors.black;
      icon = Icons.flag_rounded;
      title = status!.flag == 'DOUBLE_YELLOW'
          ? 'DOUBLE YELLOW FLAG — HAZARD'
          : 'YELLOW FLAG — CAUTION';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Caution in sector.';
    } else {
      // Clear
      bannerColor = const Color(0xFF00E676);
      textColor = Colors.black;
      icon = Icons.check_circle_rounded;
      title = 'TRACK CLEAR — GREEN FLAG';
      subtitle = 'DRS Enabled • Full Racing Conditions';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bannerColor.withValues(alpha: 0.7), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bannerColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Formula1Wide',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: bannerColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// TRACK PAINTER
// -------------------------------------------------------------
class _TrackPainter extends CustomPainter {
  final Color accentColor;
  final List<LiveTelemetry> drivers;
  final String meetingName;
  final bool isLive;

  _TrackPainter(this.accentColor, this.drivers, this.meetingName, {this.isLive = false});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final circuit = findCircuitByName(meetingName) ?? findCircuitByName('Monaco');
    final points = circuit?.trackPoints ?? [];

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
      }
      path.close();
    } else {
      path.moveTo(size.width * 0.1, size.height * 0.5);
      path.quadraticBezierTo(size.width * 0.2, size.height * 0.1, size.width * 0.5, size.height * 0.2);
      path.cubicTo(size.width * 0.7, size.height * 0.1, size.width * 0.9, size.height * 0.4, size.width * 0.8, size.height * 0.7);
      path.quadraticBezierTo(size.width * 0.6, size.height * 0.9, size.width * 0.3, size.height * 0.8);
      path.close();
    }

    canvas.drawPath(path, trackPaint);

    // Draw driver dots along path
    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final totalLen = metric.length;

      final count = drivers.isNotEmpty ? drivers.length : 12;
      for (int i = 0; i < count; i++) {
        final progress = (0.05 + (i * 0.08)) % 1.0;
        final tangent = metric.getTangentForOffset(totalLen * progress);
        if (tangent != null) {
          Color dotColor = accentColor;
          if (i < drivers.length) {
            try {
              final hex = drivers[i].color.replaceAll('#', '');
              dotColor = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {}
          } else {
            dotColor = i % 3 == 0 ? Colors.red : (i % 3 == 1 ? Colors.orange : Colors.blue);
          }

          final dotPaint = Paint()..color = dotColor;
          canvas.drawCircle(tangent.position, 4.5, dotPaint);
          canvas.drawCircle(
            tangent.position,
            6.5,
            Paint()
              ..color = dotColor.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) => true;
}
