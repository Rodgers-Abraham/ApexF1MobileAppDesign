import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/widgets/pro_gate.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../../home/presentation/screens/pitwall_screen.dart';
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
  String _selectedDriverCode = 'VER';
  String? _currentlyPlayingRadioId;
  late AnimationController _waveAnimController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerCompleteSubscription;
  String _selectedReplayMeeting = 'Singapore Grand Prix';
  int _playbackProgressMs = 0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _currentlyPlayingRadioId = null;
          _playbackProgressMs = 0;
          _playbackTimer?.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _waveAnimController.dispose();
    super.dispose();
  }

  Future<void> _toggleRadioPlayback(String radioId, String audioUrl) async {
    try {
      if (_currentlyPlayingRadioId == radioId) {
        await _audioPlayer.stop();
        _playbackTimer?.cancel();
        setState(() {
          _currentlyPlayingRadioId = null;
          _playbackProgressMs = 0;
        });
      } else {
        await _audioPlayer.stop();
        _playbackTimer?.cancel();
        _playbackProgressMs = 0;
        setState(() {
          _currentlyPlayingRadioId = radioId;
        });

        // Use supplied audioUrl or fallback to official F1 team radio recording
        final targetUrl = audioUrl.isNotEmpty
            ? audioUrl
            : 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/MAXVER01_1_20230915_103928.mp3';

        await _audioPlayer.play(UrlSource(targetUrl));

        _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (!mounted || _currentlyPlayingRadioId != radioId) {
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
    } catch (e) {
      debugPrint('Radio audio playback error: $e');
      _playbackTimer?.cancel();
      if (mounted) {
        setState(() {
          _currentlyPlayingRadioId = null;
          _playbackProgressMs = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;
    final telemetryAsync = ref.watch(liveTelemetryFeedProvider);
    final radioAsync = ref.watch(teamRadioFeedProvider);
    final latestSessionAsync = ref.watch(latestSessionProvider);
    final sessionStatusAsync = ref.watch(sessionLiveStatusProvider);
    final flagStatusAsync = ref.watch(raceFlagStatusProvider);
    final replayState = ref.watch(raceReplayProvider);

    final sessionStatus = sessionStatusAsync.value;
    final isLive = sessionStatus?.isLive ?? false;
    final effectiveMeetingName = isLive
        ? (sessionStatus?.meetingName ??
            latestSessionAsync.value?.meetingName ??
            'Singapore Grand Prix')
        : replayState.meetingName;
    final telemetryList = isLive
        ? (telemetryAsync.value ?? [])
        : (replayState.telemetry.isNotEmpty ? replayState.telemetry : (telemetryAsync.value ?? []));
    final effectiveFlagStatus = isLive
        ? flagStatusAsync.value
        : replayState.flagStatus;

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
            // Live / Race Replay status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: (isLive ? const Color(0xFF00E676) : Colors.cyanAccent)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLive
                      ? const Color(0xFF00E676).withValues(alpha: 0.6)
                      : Colors.cyanAccent.withValues(alpha: 0.6),
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
                      color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isLive ? 'RACE LIVE' : 'RACE REPLAY',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent,
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
                          isLive
                              ? effectiveMeetingName.toUpperCase()
                              : '2026 REPLAY · ${effectiveMeetingName.toUpperCase()}',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: isLive ? Colors.grey[400] : Colors.cyanAccent,
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
                        if (!isLive) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showReplayRaceSelector(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16161E),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.35), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history_rounded, size: 12, color: Colors.cyanAccent),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'SELECT RACE REPLAY',
                                      style: const TextStyle(
                                        fontFamily: 'Formula1',
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.cyanAccent,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.cyanAccent),
                                ],
                              ),
                            ),
                          ),
                        ],
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

              // Lap Progress Header Box & Interactive Replay Controls
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
                  border: Border.all(
                    color: isLive ? const Color(0xFF202028) : Colors.cyanAccent.withValues(alpha: 0.3),
                  ),
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
                            Text(
                              isLive ? 'LAP 34' : 'LAP ${replayState.currentLap}',
                              style: const TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isLive ? '/ 58' : '/ ${replayState.totalLaps}',
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
                          isLive
                              ? '58.6%'
                              : '${((replayState.currentLap / (replayState.totalLaps > 0 ? replayState.totalLaps : 1)) * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isLive ? accentColor : Colors.cyanAccent,
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
                          widthFactor: isLive
                              ? 0.586
                              : (replayState.currentLap / (replayState.totalLaps > 0 ? replayState.totalLaps : 1)).clamp(0.01, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isLive
                                    ? [accentColor.withValues(alpha: 0.6), accentColor]
                                    : [Colors.cyanAccent.withValues(alpha: 0.6), Colors.cyanAccent],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!isLive) ...[
                      const SizedBox(height: 12),
                      // Interactive Replay Scrubber & Playback Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.first_page_rounded, color: Colors.cyanAccent, size: 20),
                                tooltip: 'Jump to Lap 1',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => ref.read(raceReplayProvider.notifier).setLap(1),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, color: Colors.cyanAccent, size: 22),
                                tooltip: 'Previous Lap',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => ref.read(raceReplayProvider.notifier).prevLap(),
                              ),
                            ],
                          ),
                          // Play / Pause Button
                          GestureDetector(
                            onTap: () => ref.read(raceReplayProvider.notifier).togglePlay(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: replayState.isPlaying
                                    ? const Color(0xFFFF9100).withValues(alpha: 0.2)
                                    : Colors.cyanAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: replayState.isPlaying ? const Color(0xFFFF9100) : Colors.cyanAccent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    replayState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    size: 14,
                                    color: replayState.isPlaying ? const Color(0xFFFF9100) : Colors.cyanAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    replayState.isPlaying ? 'PAUSE' : 'PLAY REPLAY',
                                    style: TextStyle(
                                      fontFamily: 'Formula1Wide',
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: replayState.isPlaying ? const Color(0xFFFF9100) : Colors.cyanAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, color: Colors.cyanAccent, size: 22),
                                tooltip: 'Next Lap',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => ref.read(raceReplayProvider.notifier).nextLap(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.last_page_rounded, color: Colors.cyanAccent, size: 20),
                                tooltip: 'Jump to Finish',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => ref.read(raceReplayProvider.notifier).setLap(replayState.totalLaps),
                              ),
                            ],
                          ),
                          if (replayState.isLoading)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                            ),
                        ],
                      ),
                      // Lap Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: Colors.cyanAccent,
                          inactiveTrackColor: const Color(0xFF252530),
                          thumbColor: Colors.cyanAccent,
                          overlayColor: Colors.cyanAccent.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: replayState.currentLap.toDouble().clamp(1.0, replayState.totalLaps.toDouble()),
                          min: 1.0,
                          max: replayState.totalLaps.toDouble(),
                          divisions: replayState.totalLaps > 1 ? replayState.totalLaps - 1 : 1,
                          label: 'Lap ${replayState.currentLap}',
                          onChanged: (val) {
                            ref.read(raceReplayProvider.notifier).setLap(val.round());
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Live Flag / Race Control Banner
              _FigmaSessionFlagBanner(status: effectiveFlagStatus),
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
                _buildTimingTower(telemetryList, isLive ? telemetryAsync.isLoading : replayState.isLoading),
              ] else if (_selectedMode == LiveMode.map) ...[
                _buildTrackMapPanel(telemetryList, effectiveMeetingName, accentColor, isLive),
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
  Widget _buildTimingTower(List<LiveTelemetry> telemetryList, bool isLoading) {
    if (isLoading && telemetryList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (telemetryList.isEmpty) {
      return _buildTimingFallbackTower();
    }

    // Determine the single fastest lap driver in the session
    String overallFastestLapTime = '';
    for (final item in telemetryList) {
      if (item.isFastestLap) {
        overallFastestLapTime = item.bestLap.isNotEmpty ? item.bestLap : item.lastLap;
        break;
      }
    }
    if (overallFastestLapTime.isEmpty) {
      double minSec = 999999.0;
      for (final item in telemetryList) {
        final t = item.bestLap.isNotEmpty ? item.bestLap : item.lastLap;
        if (t.isNotEmpty && t.contains(':')) {
          final parts = t.split(':');
          final sec = (double.tryParse(parts[0]) ?? 0) * 60 + (double.tryParse(parts[1]) ?? 0);
          if (sec > 50 && sec < minSec) {
            minSec = sec;
            overallFastestLapTime = t;
          }
        }
      }
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
                width: 60,
                child: Text(
                  'POS / DRIVER',
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    color: Color(0xFF5F606B),
                    fontSize: 8,
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
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'TYRE',
                style: TextStyle(
                  fontFamily: 'Formula1',
                  color: Color(0xFF5F606B),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              const SizedBox(
                width: 50,
                child: Text(
                  'LAST LAP',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    color: Color(0xFF5F606B),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
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

            final isFastest = d.isFastestLap ||
                (overallFastestLapTime.isNotEmpty &&
                    (d.bestLap == overallFastestLapTime || d.lastLap == overallFastestLapTime));

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
              lastLap: d.lastLap.isNotEmpty ? d.lastLap : (d.bestLap.isNotEmpty ? d.bestLap : '-'),
              isFastestLap: isFastest,
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
                width: 60,
                child: Text(
                  'POS / DRIVER',
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    color: Color(0xFF5F606B),
                    fontSize: 8,
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
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'TYRE',
                style: TextStyle(
                  fontFamily: 'Formula1',
                  color: Color(0xFF5F606B),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              const SizedBox(
                width: 50,
                child: Text(
                  'LAST LAP',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    color: Color(0xFF5F606B),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
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

  void _showReplayRaceSelector(BuildContext context) {
    final replayRaces = [
      'Singapore Grand Prix',
      'Azerbaijan Grand Prix',
      'Italian Grand Prix',
      'Dutch Grand Prix',
      'Belgian Grand Prix',
      'Hungarian Grand Prix',
      'British Grand Prix',
      'Austrian Grand Prix',
      'Spanish Grand Prix',
      'Monaco Grand Prix',
      'Canadian Grand Prix',
      'Miami Grand Prix',
      'Chinese Grand Prix',
      'Australian Grand Prix',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SELECT RACE WEEK REPLAY',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: replayRaces.length,
                    itemBuilder: (context, i) {
                      final race = replayRaces[i];
                      final isSelected = race == _selectedReplayMeeting;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        tileColor: isSelected ? Colors.cyanAccent.withValues(alpha: 0.1) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.history_rounded,
                          color: isSelected ? Colors.cyanAccent : Colors.grey,
                          size: 18,
                        ),
                        title: Text(
                          race,
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: isSelected ? Colors.cyanAccent : Colors.white,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedReplayMeeting = race;
                          });
                          ref.read(raceReplayProvider.notifier).selectMeeting(race);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // 2. TRACK MAP VIEW
  // ---------------------------------------------------------
  Widget _buildTrackMapPanel(
    List<LiveTelemetry> telemetryList,
    String meetingName,
    Color accentColor,
    bool isLive,
  ) {
    // 1. Gather all driver codes from live telemetry or fallback roster
    final availableCodes = telemetryList.isNotEmpty
        ? telemetryList
            .map((d) => (getDriverData(d.name)?.code ?? d.name.split(' ').last.substring(0, 3)).toUpperCase())
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList()
        : kDrivers2026List.map((d) => d.code).toList();

    // Active focused driver code
    final activeCode = availableCodes.contains(_selectedDriverCode)
        ? _selectedDriverCode
        : (availableCodes.isNotEmpty ? availableCodes.first : 'VER');

    final selectedMeta = getDriverData(activeCode);
    final targetTelemetry = telemetryList.firstWhere(
      (d) =>
          (getDriverData(d.name)?.code ?? '').toUpperCase() == activeCode ||
          d.name.toUpperCase().contains(activeCode),
      orElse: () => telemetryList.isNotEmpty
          ? telemetryList.first
          : LiveTelemetry(
              name: selectedMeta?.name ?? 'Max Verstappen',
              pos: '1',
              speed: '294 km/h',
              gear: '8',
              status: 'RACING',
              drs: false,
              bestLap: '1:21.432',
              lastLap: '1:21.890',
              tyre: 'M',
              tyreLife: '12 laps',
              gap: 'LEADER',
              color: '#3671C6',
              x: 0.5,
              y: 0.5,
            ),
    );

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLive ? 'LIVE TRACK' : 'OFFICIAL TRACK REPLAY',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 9,
                            color: isLive ? const Color(0xFF8F909A) : Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isLive ? const Color(0xFF00E676) : Colors.cyanAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: isLive ? const Color(0xFF00E676) : Colors.cyanAccent),
                        const SizedBox(width: 5),
                        Text(
                          isLive ? 'TRACK CLEAR' : 'REPLAY ACTIVE',
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Dedicated Driver Selection Strip (Tap driver to focus on circuit)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded, size: 12, color: Colors.cyanAccent),
                      const SizedBox(width: 5),
                      const Text(
                        'FOCUS DRIVER ON CIRCUIT',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF8F909A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'SHOWING: $activeCode',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: getTeamColor(selectedMeta?.team ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableCodes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final code = availableCodes[index];
                        final isSelected = code == activeCode;
                        final meta = getDriverData(code);
                        final teamColor = getTeamColor(meta?.team ?? '');

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDriverCode = code),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? teamColor.withValues(alpha: 0.25)
                                  : const Color(0xFF0F0F13),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? teamColor : const Color(0xFF282834),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: teamColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  code,
                                  style: TextStyle(
                                    fontFamily: 'Formula1Wide',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? Colors.white : const Color(0xFF8F909A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Interactive Track Canvas with Real Circuit Map
              Container(
                height: 235,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Official Circuit Track Layout Map Image
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Center(
                          child: Image.asset(
                            getCircuitAssetPath(meetingName),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TrackPainter(
                          accentColor,
                          telemetryList,
                          meetingName,
                          selectedDriverCode: activeCode,
                          isLive: isLive,
                        ),
                      ),
                    ),
                  ],
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
          driverName: selectedMeta?.name ?? targetTelemetry.name,
          driverCode: activeCode,
          speedKph: targetTelemetry.speed.isNotEmpty && targetTelemetry.speed != '-'
              ? targetTelemetry.speed.replaceAll(' km/h', '')
              : '294',
          gear: targetTelemetry.gear.isNotEmpty && targetTelemetry.gear != '-'
              ? targetTelemetry.gear
              : '8',
          throttlePct: targetTelemetry.status == 'DNF' ? '0' : '97',
          ersPct: '61',
          isDnf: targetTelemetry.status == 'DNF' || targetTelemetry.status == 'RETIRED',
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
              onTogglePlay: () => _toggleRadioPlayback(r.id, r.audioUrl),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFallbackRadioList(Color accentColor) {
    final simulatedRadios = [
      TeamRadioItem(
        id: 'radio_ver_1',
        driverName: 'Max Verstappen',
        driverNumber: 1,
        team: 'Red Bull Racing',
        timestamp: 'LAP 39 · 14:41',
        transcript: 'Balance is spot on, building gap to P2.',
        audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/MAXVER01_1_20230915_103928.mp3',
        color: '#3671C6',
      ),
      TeamRadioItem(
        id: 'radio_sai_1',
        driverName: 'Carlos Sainz',
        driverNumber: 55,
        team: 'Williams',
        timestamp: 'LAP 42 · 14:48',
        transcript: 'Tires feel great, let\'s keep this rhythm.',
        audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/CARSAI01_55_20230915_103326.mp3',
        color: '#00A0DE',
      ),
      TeamRadioItem(
        id: 'radio_rus_1',
        driverName: 'George Russell',
        driverNumber: 63,
        team: 'Mercedes',
        timestamp: 'LAP 31 · 14:45',
        transcript: 'Track status clear, DRS active.',
        audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/GEORUS01_63_20230915_103406.mp3',
        color: '#00D2BE',
      ),
      TeamRadioItem(
        id: 'radio_pia_1',
        driverName: 'Oscar Piastri',
        driverNumber: 81,
        team: 'McLaren',
        timestamp: 'LAP 38 · 14:40',
        transcript: 'Box box, changing to hard compound.',
        audioUrl: 'https://livetiming.formula1.com/static/2023/2023-09-17_Singapore_Grand_Prix/2023-09-15_Practice_1/TeamRadio/OSCPIA01_81_20230915_104409.mp3',
        color: '#FF8000',
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
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
              width: 3.0,
              height: 20,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            // 1. Position & Delta
            SizedBox(
              width: 24,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      pos,
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isDnf ? const Color(0xFFFF5252) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  if (!isDnf)
                    if (positionsGained > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '▲$positionsGained',
                          style: const TextStyle(
                            fontFamily: 'Formula1',
                            color: Color(0xFF00E676),
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (positionsGained < 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '▼${positionsGained.abs()}',
                          style: const TextStyle(
                            fontFamily: 'Formula1',
                            color: Color(0xFFFF5252),
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Text(
                        '—',
                        style: TextStyle(color: Colors.grey, fontSize: 7),
                      ),
                ],
              ),
            ),
            const SizedBox(width: 3),

            // 2. Driver Portrait Avatar with team ring
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222228),
                border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1.0),
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
                            fontSize: 8,
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
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: teamColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 5),

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
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '#$driverNumber',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 7.5,
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
                      fontSize: 8,
                      color: Color(0xFF8F909A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),

            // 4. Gap & Interval
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDnf)
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'OUT',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF1744),
                        ),
                      ),
                    )
                  else if (isPit)
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'IN PIT',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF9100),
                        ),
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        gap,
                        style: TextStyle(
                          fontFamily: 'Formula1',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: gap == 'LEADER' ? const Color(0xFF00E676) : Colors.white,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),

            // 5. DRS + Compound Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (drs && !isDnf) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2.5),
                      border: Border.all(color: const Color(0xFF00E676), width: 0.8),
                    ),
                    child: const Text(
                      'DRS',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 6,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: tyreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2.5),
                    border: Border.all(color: tyreColor, width: 0.9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tyre,
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: tyreColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        tyreLife.replaceAll(' laps', '').replaceAll('L', ''),
                        style: TextStyle(
                          fontFamily: 'Formula1',
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: tyreColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 5),

            // 6. Last Lap / Fastest Lap
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      lastLap,
                      style: TextStyle(
                        fontFamily: 'Formula1',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isFastestLap ? const Color(0xFFB388FF) : Colors.white,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isFastestLap ? 'FASTEST' : 'LAST LAP',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                        color: isFastestLap ? const Color(0xFFB388FF) : const Color(0xFF5F606B),
                      ),
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
// TRACK PAINTER (Official Broadcast Map Overlay)
// -------------------------------------------------------------
class _TrackPainter extends CustomPainter {
  final Color accentColor;
  final List<LiveTelemetry> drivers;
  final String meetingName;
  final String selectedDriverCode;
  final bool isLive;

  _TrackPainter(
    this.accentColor,
    this.drivers,
    this.meetingName, {
    required this.selectedDriverCode,
    this.isLive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Note: The authentic high-resolution circuit diagram from assets/circuits/*.png
    // is rendered directly beneath this canvas. We render official broadcast sector
    // checkpoints, Start/Finish badge, DRS/Speed Trap, and STRICTLY the single
    // driver selected by the user.
    final circuit = findCircuitByName(meetingName) ?? circuitSingapore;
    final points = circuit.trackPoints.isNotEmpty ? circuit.trackPoints : circuitSingapore.trackPoints;

    if (points.isNotEmpty) {
      // 1. Start / Finish Line Badge
      final sf = Offset(points.first.dx * size.width, points.first.dy * size.height);
      _drawBadge(canvas, sf, 'S/F', Colors.white, Colors.black);

      // 2. Sector 1, Sector 2, Sector 3 Badges
      if (points.length >= 7) {
        final s1 = Offset(points[2].dx * size.width, points[2].dy * size.height);
        _drawBadge(canvas, s1, 'S1', const Color(0xFFFFD600), Colors.black);

        final s2 = Offset(points[5].dx * size.width, points[5].dy * size.height);
        _drawBadge(canvas, s2, 'S2', const Color(0xFF00E5FF), Colors.black);

        final s3 = Offset(points[points.length - 2].dx * size.width, points[points.length - 2].dy * size.height);
        _drawBadge(canvas, s3, 'S3', const Color(0xFFB388FF), Colors.black);
      }

      // 3. DRS Detection / Speed Trap
      if (points.length >= 9) {
        final drs = Offset(points[points.length - 4].dx * size.width, points[points.length - 4].dy * size.height);
        _drawBadge(canvas, drs, 'DRS', const Color(0xFF00E676), Colors.black);
      }

      // 4. STRICTLY ONLY THE SELECTED DRIVER IS DISPLAYED
      LiveTelemetry? targetDriver;
      int driverIndex = 0;
      for (int i = 0; i < drivers.length; i++) {
        final d = drivers[i];
        final code = (getDriverData(d.name)?.code ?? d.name.split(' ').last.substring(0, 3)).toUpperCase();
        if (code == selectedDriverCode || d.name.toUpperCase().contains(selectedDriverCode.toUpperCase())) {
          targetDriver = d;
          driverIndex = i;
          break;
        }
      }

      final meta = getDriverData(selectedDriverCode);
      Color teamColor = getTeamColor(meta?.team ?? '');
      if (targetDriver != null) {
        try {
          final hex = targetDriver.color.replaceAll('#', '');
          teamColor = Color(int.parse('FF$hex', radix: 16));
        } catch (_) {}
      }

      final posStr = targetDriver?.pos.isNotEmpty == true ? targetDriver!.pos : '${driverIndex + 1}';
      final ptIndex = ((driverIndex * 3) + 2) % points.length;
      final carPoint = Offset(points[ptIndex].dx * size.width, points[ptIndex].dy * size.height);

      _drawSingleFocusedDriver(canvas, carPoint, 'P$posStr $selectedDriverCode', teamColor);
    }
  }

  void _drawBadge(Canvas canvas, Offset pos, String text, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: 'Formula1', fontSize: 7, fontWeight: FontWeight.w900, color: fg),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: tp.width + 8, height: tp.height + 4),
      const Radius.circular(3),
    );
    canvas.drawRRect(rrect, Paint()..color = bg);
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawSingleFocusedDriver(Canvas canvas, Offset pos, String text, Color color) {
    // 1. Radar Pulse / Halo Beacon Rings around car position
    final pulsePaint1 = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 16, pulsePaint1);

    final pulsePaint2 = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(pos, 9, pulsePaint2);

    // 2. Glowing Core Beacon Dot
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 4.5, corePaint);

    final coreBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(pos, 4.5, coreBorder);

    // 3. Floating Callout Pill
    final isNearTop = pos.dy < 45;
    final pillOffset = Offset(0, isNearTop ? 22 : -22);
    final badgeCenter = pos + pillOffset;

    // Leader indicator line from car to pill
    final leaderPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.2;
    canvas.drawLine(pos + Offset(0, isNearTop ? 6 : -6), badgeCenter + Offset(0, isNearTop ? -10 : 10), leaderPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Formula1Wide',
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: badgeCenter, width: tp.width + 16, height: tp.height + 7),
      const Radius.circular(5),
    );

    // Pill background
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF141419));
    // Pill accent border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Pill team indicator bar on left
    final leftBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeCenter.dx - (tp.width + 16) / 2, badgeCenter.dy - (tp.height + 7) / 2, 3.5, tp.height + 7),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(leftBar, Paint()..color = color);

    tp.paint(canvas, badgeCenter - Offset(tp.width / 2 - 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) =>
      oldDelegate.selectedDriverCode != selectedDriverCode ||
      oldDelegate.drivers != drivers;
}
