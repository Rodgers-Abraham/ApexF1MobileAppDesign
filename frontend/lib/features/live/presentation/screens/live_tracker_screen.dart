import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../../home/presentation/screens/pitwall_screen.dart';
import '../widgets/timing_row_widget.dart';
import '../widgets/telemetry_strip.dart';
import '../widgets/radio_card.dart';
import '../widgets/session_flag_banner.dart';
import '../widgets/track_painter.dart';

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
  String _selectedReplayMeeting = '';
  int _playbackProgressMs = 0;
  Timer? _playbackTimer;
  // Replay position-change tracking
  int _lastReplayLap = -1;
  Map<String, int> _prevReplayPositions = {};
  // Overtake toast
  String? _overtakeToastText;
  Timer? _overtakeTimer;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900))..repeat(reverse: true);

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
    _overtakeTimer?.cancel();
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
    // Watch calendar so the replay picker always has fresh data
    ref.watch(calendarProvider);

    final sessionStatus = sessionStatusAsync.value;
    final isLive = sessionStatus?.isLive ?? false;
    final effectiveMeetingName = isLive
        ? (sessionStatus?.meetingName ?? latestSessionAsync.value?.meetingName ?? '')
        : replayState.meetingName;
    final telemetryList = isLive
        ? (telemetryAsync.value ?? [])
        : (replayState.telemetry.isNotEmpty ? replayState.telemetry : (telemetryAsync.value ?? []));
    final effectiveFlagStatus = isLive
        ? flagStatusAsync.value
        : replayState.flagStatus;

    // Update position-change map when lap advances + detect overtakes
    if (!isLive && replayState.currentLap != _lastReplayLap && replayState.currentLap > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final prevLapEntry = replayState.allLaps.firstWhere(
          (l) => l.lap == replayState.currentLap - 1,
          orElse: () => const ReplayLapEntry(lap: -1, phase: '', positions: []));
        final newPrevPositions = prevLapEntry.positions.isNotEmpty
            ? {for (final p in prevLapEntry.positions) if ((int.tryParse(p.pos) ?? 0) > 0) p.name: int.tryParse(p.pos) ?? 0}
            : _prevReplayPositions;
        // Detect overtakes (gained 1+ places) — show toast for any position gain
        if (newPrevPositions.isNotEmpty) {
          for (final d in replayState.telemetry) {
            final curr = int.tryParse(d.pos) ?? 99;
            final prev = newPrevPositions[d.name] ?? 99;
            if (curr < prev && prev - curr >= 1 && curr > 0 && prev < 99) {
              _showOvertakeToast(d.name, prev, curr, replayState.currentLap);
              break;
            }
          }
        }
        setState(() {
          _lastReplayLap = replayState.currentLap;
          _prevReplayPositions = newPrevPositions;
        });
      });
    }

    // Grid screen: full-screen starting grid before playback begins
    if (!isLive && replayState.showingGrid && replayState.allLaps.isNotEmpty) {
      return Scaffold(
        backgroundColor: DS.bg,
        appBar: DSAppBar(
          subtitle: '${replayState.meetingName.toUpperCase()} // REPLAY',
          isLive: false,
          liveLabel: 'REPLAY'),
        body: _buildGridScreen(replayState, accentColor),
      );
    }

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: DSAppBar(
        subtitle: 'PITWALL TELEMETRY',
        isLive: isLive,
        liveLabel: isLive
            ? '${sessionStatus?.sessionName.toUpperCase() ?? 'LIVE'} TRACK'
            : 'REPLAY',
        latencyMs: '12'),
      body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
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
                          style: TextStyle( fontSize: 10,
                            letterSpacing: 1.5,
                            color: isLive ? Colors.grey[400] : Colors.cyanAccent,
                            fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        const Text(
                          'LIVE TIMING',
                          style: TextStyle( fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                        if (!isLive) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showReplayRaceSelector(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16161E),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.35), width: 1)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history_rounded, size: 12, color: Colors.cyanAccent),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'SELECT RACE REPLAY',
                                      style: const TextStyle( fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.cyanAccent),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.cyanAccent),
                                ]))),
                        ],
                      ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF19191F),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF282832))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                          effectiveMeetingName.isNotEmpty
                              ? effectiveMeetingName.split(' ').take(2).join(' ').toUpperCase()
                              : (isLive ? 'LIVE' : 'REPLAY'),
                          style: const TextStyle( fontSize: 9.5,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold)),
                      ])),
                ]),
              const SizedBox(height: 12),

              // Lap Progress Header Box & Interactive Replay Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141419),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(3),
                    bottomRight: Radius.circular(10)),
                  border: Border.all(
                    color: isLive ? const Color(0xFF202028) : Colors.cyanAccent.withValues(alpha: 0.3))),
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
                              isLive
                                  ? ((sessionStatus?.sessionName.toLowerCase().contains('practice') == true ||
                                          sessionStatus?.sessionName.toLowerCase().contains('qualifying') == true ||
                                          sessionStatus?.sessionName.toLowerCase().contains('fp') == true)
                                      ? (sessionStatus?.sessionName.toUpperCase() ?? 'LIVE')
                                      : 'RACE')
                                  : replayState.lapLabel,
                              style: const TextStyle( fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                            const SizedBox(width: 4),
                            Text(
                              isLive
                                  ? ((sessionStatus?.sessionName.toLowerCase().contains('practice') == true ||
                                          sessionStatus?.sessionName.toLowerCase().contains('qualifying') == true ||
                                          sessionStatus?.sessionName.toLowerCase().contains('fp') == true)
                                      ? '· LIVE'
                                      : '')
                                  : '/ ${replayState.totalLaps}',
                              style: TextStyle( fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold)),
                          ]),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isLive
                                ? ((sessionStatus?.sessionName.toLowerCase().contains('practice') == true ||
                                        sessionStatus?.sessionName.toLowerCase().contains('qualifying') == true ||
                                        sessionStatus?.sessionName.toLowerCase().contains('fp') == true)
                                    ? 'LIVE SESSION'
                                    : 'IN PROGRESS')
                                : '${((replayState.currentLap / (replayState.totalLaps > 0 ? replayState.totalLaps : 1)) * 100).toStringAsFixed(1)}%',
                            style: TextStyle( fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isLive ? accentColor : Colors.cyanAccent))),
                      ]),
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
                              ? ((sessionStatus?.sessionName.toLowerCase().contains('practice') == true ||
                                      sessionStatus?.sessionName.toLowerCase().contains('qualifying') == true ||
                                      sessionStatus?.sessionName.toLowerCase().contains('fp') == true)
                                  ? 0.70
                                  : 0.50)
                              : (replayState.currentLap / (replayState.totalLaps > 0 ? replayState.totalLaps : 1)).clamp(0.01, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isLive
                                    ? [accentColor.withValues(alpha: 0.6), accentColor]
                                    : [Colors.cyanAccent.withValues(alpha: 0.6), Colors.cyanAccent])))))),
                    if (!isLive) ...[
                      const SizedBox(height: 10),
                      _buildReplayControlsInline(replayState),
                    ],
                  ])),
              const SizedBox(height: 10),

              // Live Flag / Race Control Banner
              FigmaSessionFlagBanner(status: effectiveFlagStatus),
              const SizedBox(height: 12),

              // Figma Mode Switcher (TIMING, MAP, RADIO, TYRES)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F13),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF202028))),
                child: Row(
                  children: [
                    _buildSegmentButton(LiveMode.timing, 'TIMING'),
                    _buildSegmentButton(LiveMode.map, 'MAP'),
                    _buildSegmentButton(LiveMode.radio, 'RADIO'),
                    _buildSegmentButton(LiveMode.tyres, 'TYRES'),
                  ])),
              const SizedBox(height: 14),

              // Replay — empty / error state
              if (!isLive && replayState.allLaps.isEmpty) ...[
                GestureDetector(
                  onTap: () => _showReplayRaceSelector(context),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141419),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3))),
                    child: Column(
                      children: [
                        const Icon(Icons.history_rounded, color: Colors.cyanAccent, size: 32),
                        const SizedBox(height: 10),
                        if (replayState.isLoading)
                          const SkeletonBox(height: 60)
                        else ...[
                          Text(
                            replayState.loadError ?? 'TAP TO SELECT A SESSION REPLAY',
                            textAlign: TextAlign.center,
                            style: TextStyle( fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: replayState.loadError != null ? Colors.redAccent : Colors.cyanAccent)),
                          if (replayState.loadError == null) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Choose a past race and session to replay\ntiming data lap by lap',
                              textAlign: TextAlign.center,
                              style: TextStyle( fontSize: 10, color: Colors.grey)),
                          ],
                        ],
                      ]))),
              ],

              // Replay: podium card, driver focus picker, end-of-race summary
              if (!isLive && replayState.allLaps.isNotEmpty && _selectedMode == LiveMode.timing) ...[
                if (replayState.isAtEnd && replayState.finalClassification.isNotEmpty)
                  _buildPodiumCard(replayState),
                _buildDriverFocusPicker(replayState, accentColor),
                if (replayState.isAtEnd && replayState.focusedDriverSummary != null)
                  _buildDriverSummaryCard(replayState.focusedDriverSummary!, accentColor),
              ],

              // View Body based on Mode Switcher
              if (_selectedMode == LiveMode.timing) ...[
                // Replay: overtake toast + race control event banner
                if (!isLive && replayState.allLaps.isNotEmpty) ...[
                  if (_overtakeToastText != null)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: DS.orange.withValues(alpha: 0.15),
                          borderRadius: DS.aeroCornerSm,
                          border: Border.all(color: DS.orange.withValues(alpha: 0.4)),
                        ),
                        child: Text(_overtakeToastText!, style: DS.labelCaps(size: 9, color: DS.orange)),
                      ),
                    ),
                  if (replayState.currentLapEvents.isNotEmpty)
                    _buildRaceEventBanner(replayState.currentLapEvents),
                ],
                // Replay uses custom tower with lap time + position change arrows
                if (!isLive && replayState.allLaps.isNotEmpty)
                  _buildReplayTimingTower(replayState)
                else
                  _buildTimingTower(telemetryList, isLive ? telemetryAsync.isLoading : replayState.isLoading),
              ] else if (_selectedMode == LiveMode.map) ...[
                _buildTrackMapPanel(telemetryList, effectiveMeetingName, accentColor, isLive),
              ] else if (_selectedMode == LiveMode.radio) ...[
                _buildTeamRadioPanel(radioAsync, accentColor),
              ] else if (_selectedMode == LiveMode.tyres) ...[
                _buildTyreStrategyPanel(telemetryAsync, accentColor),
              ],
            ])));
  }

  // ─────────────────────────────────────────────────────
  // REPLAY: Grid screen shown before playback starts
  // ─────────────────────────────────────────────────────

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return DS.textMuted;
    }
  }

  Widget _buildGridScreen(RaceReplayState replayState, Color accentColor) {
    final gridEntries = replayState.allLaps
        .firstWhere((l) => l.lap == 0,
            orElse: () => ReplayLapEntry(lap: 0, phase: 'GRID', positions: replayState.telemetry))
        .positions;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: DS.surface0,
          child: Row(children: [
            Container(width: 3, height: 20, color: accentColor),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(replayState.meetingName.toUpperCase(), style: DS.headline(size: 14)),
              Text('STARTING GRID // ${replayState.sessionType.toUpperCase()}',
                  style: DS.labelCaps(size: 8, color: DS.textMuted)),
            ]),
            const Spacer(),
            DSWidgets.statusChip('${gridEntries.length} DRIVERS', color: DS.teal, size: 8),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: gridEntries.length,
            itemBuilder: (context, i) {
              final driver = gridEntries[i];
              final teamColor = _hexToColor(driver.color);
              final posNum = int.tryParse(driver.pos) ?? (i + 1);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: DS.surface1,
                  borderRadius: DS.aeroCornerSm,
                  border: Border(left: BorderSide(color: teamColor, width: 3)),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: posNum <= 3 ? accentColor.withValues(alpha: 0.2) : DS.surface3,
                      borderRadius: DS.aeroCornerSm,
                    ),
                    alignment: Alignment.center,
                    child: Text('P$posNum', style: DS.labelCaps(size: 10, color: posNum <= 3 ? accentColor : DS.textMuted)),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 4, height: 24, color: teamColor),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(driver.name, style: DS.body(size: 13, color: DS.textPrimary)),
                    Text(driver.team, style: DS.labelCaps(size: 8, color: DS.textMuted)),
                  ])),
                  Text(
                    driver.lastLap.isNotEmpty && driver.lastLap != 'Grid' ? driver.lastLap : '—',
                    style: DS.telemetry(size: 11, color: DS.textMuted)),
                ]),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: DS.surface0,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ref.read(raceReplayProvider.notifier).startReplay(),
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                elevation: 0,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text('START REPLAY', style: DS.labelCaps(size: 11, color: Colors.black)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // REPLAY: Inline controls (scrubber + play + speed + incident)
  // ─────────────────────────────────────────────────────

  Widget _buildReplayControlsInline(RaceReplayState replayState) {
    final notifier = ref.read(raceReplayProvider.notifier);
    return Column(children: [
      // Lap scrubber
      Row(children: [
        Text('L${replayState.currentLap}', style: DS.telemetry(size: 11, color: DS.teal)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: DS.teal,
              inactiveTrackColor: DS.outline,
              thumbColor: DS.teal,
            ),
            child: Slider(
              value: replayState.totalLaps > 0
                  ? replayState.currentLap.toDouble().clamp(0.0, replayState.totalLaps.toDouble())
                  : 0.0,
              min: 0,
              max: replayState.totalLaps > 0 ? replayState.totalLaps.toDouble() : 1.0,
              divisions: replayState.totalLaps > 0 ? replayState.totalLaps : 1,
              onChanged: (v) => notifier.setLap(v.round()),
            ),
          ),
        ),
        Text('L${replayState.totalLaps}', style: DS.telemetry(size: 11, color: DS.textMuted)),
      ]),
      // Event marker dots on scrubber track
      if (replayState.flagEventLaps.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 32, right: 32, bottom: 2),
          child: SizedBox(
            height: 6,
            child: LayoutBuilder(builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              final total = replayState.totalLaps;
              if (total <= 0) return const SizedBox.shrink();
              return Stack(
                clipBehavior: Clip.none,
                children: replayState.flagEventLaps.map((lap) {
                  final x = (lap / total) * w;
                  final evts = replayState.lapEventMap[lap]!;
                  final notable = evts.firstWhere(
                    (e) => e.isNotable, orElse: () => evts.first);
                  return Positioned(
                    left: x.clamp(0.0, w - 4),
                    top: 1,
                    child: Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(
                        color: notable.eventColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ),
      // Controls row
      Row(children: [
        _ctrlBtn(Icons.skip_previous_rounded, () => notifier.setLap(1)),
        _ctrlBtn(Icons.replay_10_rounded, () => notifier.setLap(replayState.currentLap - 10)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => notifier.togglePlay(),
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: DS.teal, shape: BoxShape.circle),
            child: Icon(
              replayState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black, size: 26),
          ),
        ),
        const SizedBox(width: 6),
        _ctrlBtn(Icons.forward_10_rounded, () => notifier.setLap(replayState.currentLap + 10)),
        _ctrlBtn(Icons.skip_next_rounded, () => notifier.setLap(replayState.totalLaps)),
        const Spacer(),
        if (replayState.incidentLaps.isNotEmpty)
          GestureDetector(
            onTap: () => notifier.nextIncident(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: DS.orange.withValues(alpha: 0.15),
                borderRadius: DS.aeroCornerSm,
                border: Border.all(color: DS.orange.withValues(alpha: 0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, size: 14, color: DS.orange),
                const SizedBox(width: 4),
                Text('${replayState.incidentLaps.length}', style: DS.labelCaps(size: 9, color: DS.orange)),
              ]),
            ),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => notifier.cycleSpeed(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DS.surface2,
              borderRadius: DS.aeroCornerSm,
              border: Border.all(color: DS.outline),
            ),
            child: Text('${replayState.speedMultiplier}×', style: DS.labelCaps(size: 10, color: DS.textPrimary)),
          ),
        ),
      ]),
    ]);
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: DS.textMuted),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // REPLAY: Race control event banner (SC / VSC / Red flag)
  // ─────────────────────────────────────────────────────

  Widget _buildRaceEventBanner(List<RaceControlEvent> events) {
    // Sort: red flag first, then SC, VSC, then others
    final sorted = [...events]..sort((a, b) {
      int p(RaceControlEvent e) {
        if (e.isRedFlag) return 0;
        if (e.isSafetyCar) return 1;
        if (e.isVsc) return 2;
        if (e.isScEnding || e.isVscEnding) return 3;
        return 4;
      }
      return p(a).compareTo(p(b));
    });
    final primary = sorted.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primary.eventColor.withValues(alpha: 0.15),
        borderRadius: DS.aeroCornerSm,
        border: Border(left: BorderSide(color: primary.eventColor, width: 3)),
      ),
      child: Row(children: [
        Icon(primary.icon, size: 14, color: primary.eventColor),
        const SizedBox(width: 8),
        Text('LAP ${primary.lap}', style: DS.labelCaps(size: 8, color: primary.eventColor)),
        const SizedBox(width: 6),
        Container(width: 1, height: 12, color: primary.eventColor.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
        Expanded(child: Text(primary.displayLabel, style: DS.labelCaps(size: 9, color: primary.eventColor))),
        ...sorted.skip(1).take(2).map((e) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: DSWidgets.statusChip(e.displayLabel, color: e.eventColor, size: 7),
        )),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────
  // REPLAY: Overtake toast
  // ─────────────────────────────────────────────────────

  void _showOvertakeToast(String driverName, int from, int to, int lap) {
    _overtakeTimer?.cancel();
    final parts = driverName.trim().split(' ');
    final code = parts.last.length >= 3 ? parts.last.substring(0, 3).toUpperCase() : parts.last.toUpperCase();
    setState(() => _overtakeToastText = '⚡ $code  P$from → P$to  •  LAP $lap');
    _overtakeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _overtakeToastText = null);
    });
  }

  // ─────────────────────────────────────────────────────
  // REPLAY: Custom timing tower with lap time + pos-change
  // ─────────────────────────────────────────────────────

  Widget _buildReplayTimingTower(RaceReplayState replayState) {
    // Sort by pos (int) so the tower always reflects race order,
    // even if the backend list arrives in a different order.
    final drivers = [...replayState.telemetry]
      ..sort((a, b) => (int.tryParse(a.pos) ?? 99).compareTo(int.tryParse(b.pos) ?? 99));
    if (replayState.isLoading && drivers.isEmpty) {
      return Column(children: List.generate(10, (_) => const SkeletonTimingRow()));
    }
    if (drivers.isEmpty) {
      return _buildTimingFallbackTower();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            SizedBox(width: 60, child: Text('POS / DRIVER', style: DS.labelCaps(size: 8, color: DS.textMuted))),
            const Spacer(),
            Text('LAP TIME', style: DS.labelCaps(size: 8, color: DS.textMuted)),
            const SizedBox(width: 14),
            SizedBox(width: 32, child: Text('ΔPOS', textAlign: TextAlign.center, style: DS.labelCaps(size: 8, color: DS.textMuted))),
          ]),
        ),
        SizedBox(
          height: drivers.length * 52.0,
          child: Stack(
            children: drivers.asMap().entries.map((entry) {
              final index = entry.key;
              final d = entry.value;
              final driverMeta = getDriverData(d.name);
              final lastName = d.name.split(' ').lastOrNull ?? d.name;
              final code = driverMeta?.code ??
                  lastName.substring(0, lastName.length.clamp(0, 3)).toUpperCase();
              final teamColor = _hexToColor(d.color);

              // Position change
              final prevPos = _prevReplayPositions[d.name];
              final currPos = int.tryParse(d.pos) ?? 0;
              final posChange = (prevPos != null && currPos > 0) ? prevPos - currPos : 0;
              final arrowIcon = posChange > 0 ? Icons.arrow_upward_rounded : posChange < 0 ? Icons.arrow_downward_rounded : null;
              final arrowColor = posChange > 0 ? DS.green : posChange < 0 ? DS.red : DS.textMuted;

              final lapTime = d.lastLap.isNotEmpty ? d.lastLap : '—';
              final isFocused = replayState.focusedDriverName == d.name;

              return AnimatedPositioned(
                key: ValueKey(d.name),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                top: index * 52.0,
                left: 0,
                right: 0,
                height: 52.0,
                child: GestureDetector(
                  onTap: () => ref.read(raceReplayProvider.notifier).setFocusedDriver(isFocused ? null : d.name),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFocused ? teamColor.withValues(alpha: 0.1) : DS.surface1,
                      borderRadius: DS.aeroCornerSm,
                      border: Border(left: BorderSide(color: teamColor, width: 3)),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 28,
                        child: Text('P${d.pos}', style: DS.telemetry(size: 11, color: DS.textPrimary))),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 36,
                        child: Text(code, style: DS.driverCode(size: 12, color: DS.textPrimary))),
                      Expanded(
                        child: Text(d.team, style: DS.labelCaps(size: 7, color: DS.textMuted),
                          overflow: TextOverflow.ellipsis)),
                      Text(lapTime, style: DS.telemetry(size: 11, color: DS.textPrimary)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 32,
                        child: posChange == 0 || arrowIcon == null
                            ? Text('—', textAlign: TextAlign.center, style: DS.labelCaps(size: 10, color: DS.textMuted))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(arrowIcon, size: 12, color: arrowColor),
                                Text(posChange.abs().toString(), style: DS.labelCaps(size: 10, color: arrowColor)),
                              ]),
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // REPLAY: Podium card shown at race end
  // ─────────────────────────────────────────────────────

  Widget _buildPodiumCard(RaceReplayState replayState) {
    final top3 = replayState.finalClassification.take(3).toList();
    final fastestDriver = replayState.finalClassification
        .where((d) => d.isFastestLap)
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DS.surface1,
        borderRadius: DS.aeroCorner,
        border: Border.all(color: DS.teal.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 16, color: DS.teal),
          const SizedBox(width: 8),
          Text('RACE COMPLETE', style: DS.labelCaps(size: 10, color: DS.teal)),
          const Spacer(),
          Text(replayState.meetingName.toUpperCase(), style: DS.labelCaps(size: 8, color: DS.textMuted)),
        ]),
        const SizedBox(height: 10),
        ...top3.map((d) {
          final posNum = int.tryParse(d.pos) ?? 0;
          final teamColor = _hexToColor(d.color);
          final medal = posNum == 1 ? '🥇' : posNum == 2 ? '🥈' : '🥉';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(medal, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Container(width: 3, height: 20, color: teamColor),
              const SizedBox(width: 8),
              Text(d.name.split(' ').last.toUpperCase(), style: DS.driverCode(size: 13)),
              const SizedBox(width: 8),
              Expanded(child: Text(d.team, style: DS.body(size: 10, color: DS.textMuted))),
              Text(d.gap.isEmpty || d.gap == 'LEADER' ? '' : d.gap,
                  style: DS.telemetry(size: 11, color: DS.textMuted)),
            ]),
          );
        }),
        if (fastestDriver != null) ...[
          Divider(color: DS.outline, height: 12),
          Row(children: [
            const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFB038FF)),
            const SizedBox(width: 6),
            Text('FASTEST LAP', style: DS.labelCaps(size: 8, color: DS.purple)),
            const SizedBox(width: 8),
            Text(fastestDriver.name.split(' ').last.toUpperCase(),
                style: DS.driverCode(size: 11, color: DS.purple)),
            const Spacer(),
            Text(fastestDriver.lastLap, style: DS.telemetry(size: 11, color: DS.purple)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildDriverFocusPicker(RaceReplayState replayState, Color accent) {
    final drivers = replayState.telemetry;
    if (drivers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: drivers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final d = drivers[i];
          final meta = getDriverData(d.name);
          final code = meta?.code ?? d.name.split(' ').lastOrNull?.substring(0, 3).toUpperCase() ?? '???';
          Color teamColor = Colors.white;
          try {
            final hex = d.color.replaceAll('#', '');
            teamColor = Color(int.parse('FF$hex', radix: 16));
          } catch (_) {}
          final isFocused = replayState.focusedDriverName == d.name;
          return GestureDetector(
            onTap: () => ref.read(raceReplayProvider.notifier).setFocusedDriver(isFocused ? null : d.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isFocused ? teamColor.withValues(alpha: 0.2) : const Color(0xFF141419),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isFocused ? teamColor : Colors.white12, width: isFocused ? 1.5 : 1)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFocused) Icon(Icons.star_rounded, size: 10, color: teamColor),
                  if (isFocused) const SizedBox(width: 3),
                  Text(
                    code,
                    style: TextStyle( fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: isFocused ? teamColor : Colors.white70)),
                ])));
        }));
  }

  Widget _buildDriverSummaryCard(DriverReplaySummary summary, Color accent) {
    final pos = summary.finalPosition;
    final posColor = pos == 1 ? const Color(0xFFFFD700) : pos == 2 ? const Color(0xFFC0C0C0) : pos == 3 ? const Color(0xFFCD7F32) : Colors.white;
    final teamData = getTeamData(summary.team);
    final teamColor = teamData?.primaryColor ?? accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: teamColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: teamColor.withValues(alpha: 0.08), blurRadius: 16)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, size: 12, color: Colors.white54),
              const SizedBox(width: 6),
              Text('RACE RESULT — ${summary.driverName.toUpperCase()}',
                  style: const TextStyle( fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 0.8)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: posColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: posColor.withValues(alpha: 0.5))),
                child: Text('P$pos', style: TextStyle( fontSize: 13, fontWeight: FontWeight.w900, color: posColor))),
            ]),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile('FASTEST LAP', summary.fastestLap.isNotEmpty ? summary.fastestLap : '—', const Color(0xFFBB00FF)),
              const SizedBox(width: 12),
              _statTile('LAP', summary.fastestLapNum > 0 ? 'L${summary.fastestLapNum}' : '—', Colors.white54),
              const SizedBox(width: 12),
              _statTile('TEAM', summary.team, teamColor),
            ]),
        ]));
  }

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle( fontSize: 7.5, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle( fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ]));
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
                      offset: const Offset(0, 2)),
                  ]
                : null),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle( fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: isSelected ? const Color(0xFF09090C) : const Color(0xFF8F909A),
              letterSpacing: 0.8)))));
  }

  // ---------------------------------------------------------
  // 1. TIMING TOWER
  // ---------------------------------------------------------
  Widget _buildTimingTower(List<LiveTelemetry> telemetryList, bool isLoading) {
    if (isLoading && telemetryList.isEmpty) {
      return Column(
        children: List.generate(10, (_) => const SkeletonTimingRow()));
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
      orElse: () => telemetryList.first);

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
                  style: TextStyle( color: Color(0xFF5F606B),
                    fontSize: 8,
                    fontWeight: FontWeight.bold))),
              const Spacer(),
              const Text(
                'GAP / INT',
                style: TextStyle( color: Color(0xFF5F606B),
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
              const SizedBox(width: 14),
              const Text(
                'TYRE',
                style: TextStyle( color: Color(0xFF5F606B),
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              const SizedBox(
                width: 50,
                child: Text(
                  'LAST LAP',
                  textAlign: TextAlign.end,
                  style: TextStyle( color: Color(0xFF5F606B),
                    fontSize: 8,
                    fontWeight: FontWeight.bold))),
            ])),
        const SizedBox(height: 2),

        // Animated timing tower — cards slide smoothly on position changes
        _AnimatedTimingStack(
          drivers: telemetryList,
          overallFastestLapTime: overallFastestLapTime,
          selectedDriverCode: _selectedDriverCode,
          onDriverTap: (code) => setState(() => _selectedDriverCode = code)),
        const SizedBox(height: 12),

        // Pinned Onboard Telemetry Strip
        FigmaTelemetryStrip(
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
          isDnf: selectedDriver.status == 'DNF' || selectedDriver.status == 'RETIRED'),
      ]);
  }

  Widget _buildTimingFallbackTower() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.timer_outlined, color: Color(0xFF5F606B), size: 40),
            SizedBox(height: 12),
            Text(
              'NO TIMING DATA',
              style: TextStyle( fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5F606B))),
            SizedBox(height: 4),
            Text(
              'Timing data will appear during live sessions',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F606B))),
          ])));
  }

  void _showReplayRaceSelector(BuildContext context) {
    final calendarAsync = ref.read(calendarProvider);
    final pastRaces = calendarAsync.whenOrNull(
      data: (races) => races.where((r) => r.date.isBefore(DateTime.now())).toList()) ?? [];

    if (pastRaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed races available for replay.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141419),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ReplaySessionPicker(
        pastRaces: pastRaces,
        selectedMeeting: _selectedReplayMeeting,
        onSelected: (race, sessionType) {
          setState(() => _selectedReplayMeeting = race.name);
          ref.read(raceReplayProvider.notifier).selectSession(
            year: race.date.year,
            round: int.tryParse(race.round) ?? 1,
            meetingName: race.name,
            sessionType: sessionType);
          Navigator.pop(ctx);
        }));
  }

  // ---------------------------------------------------------
  // 2. TRACK MAP VIEW
  // ---------------------------------------------------------
  Widget _buildTrackMapPanel(
    List<LiveTelemetry> telemetryList,
    String meetingName,
    Color accentColor,
    bool isLive) {
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
              name: selectedMeta?.name ?? '',
              pos: '',
              speed: '',
              gear: '',
              status: '',
              drs: false,
              bestLap: '',
              lastLap: '',
              tyre: '',
              tyreLife: '',
              gap: '',
              color: '#FFFFFF',
              x: 0.5,
              y: 0.5));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF202028))),
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
                          style: TextStyle( fontSize: 9,
                            color: isLive ? const Color(0xFF8F909A) : Colors.cyanAccent,
                            fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          meetingName.toUpperCase(),
                          style: const TextStyle( fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      ])),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isLive ? const Color(0xFF00E676) : Colors.cyanAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent, width: 1)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: isLive ? const Color(0xFF00E676) : Colors.cyanAccent),
                        const SizedBox(width: 5),
                        Text(
                          isLive ? 'TRACK CLEAR' : 'REPLAY ACTIVE',
                          style: TextStyle( fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isLive ? const Color(0xFF00E676) : Colors.cyanAccent)),
                      ])),
                ]),
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
                        style: TextStyle( fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF8F909A),
                          letterSpacing: 0.5)),
                      const Spacer(),
                      Text(
                        'SHOWING: $activeCode',
                        style: TextStyle( fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: getTeamColor(selectedMeta?.team ?? ''))),
                    ]),
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
                                width: isSelected ? 1.5 : 1.0)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: teamColor)),
                                const SizedBox(width: 5),
                                Text(
                                  code,
                                  style: TextStyle( fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? Colors.white : const Color(0xFF8F909A))),
                              ])));
                      })),
                ]),
              const SizedBox(height: 14),

              // Interactive Track Canvas with Real Circuit Map
              Container(
                height: 235,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
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
                            errorBuilder: (_, __, ___) => const SizedBox())))),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: TrackPainter(
                          accentColor,
                          telemetryList,
                          meetingName,
                          selectedDriverCode: activeCode,
                          isLive: isLive))),
                  ])),
              const SizedBox(height: 14),

              // Sector & DRS Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMapLegendItem(const Color(0xFFFFD600), 'SECTOR 1'),
                  _buildMapLegendItem(const Color(0xFF00E5FF), 'SECTOR 2'),
                  _buildMapLegendItem(const Color(0xFFB388FF), 'SECTOR 3'),
                  _buildMapLegendItem(const Color(0xFF00E676), 'DRS ZONE'),
                ]),
            ])),
        const SizedBox(height: 14),

        // Bottom Telemetry Strip for Selected Driver
        FigmaTelemetryStrip(
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
          isDnf: targetTelemetry.status == 'DNF' || targetTelemetry.status == 'RETIRED'),
      ]);
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
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle( fontSize: 9,
            color: Color(0xFF8F909A),
            fontWeight: FontWeight.bold)),
      ]);
  }

  // ---------------------------------------------------------
  // 3. TEAM RADIO PANEL
  // ---------------------------------------------------------
  Widget _buildTeamRadioPanel(
    AsyncValue<List<TeamRadioItem>> radioAsync,
    Color accentColor) {
    return radioAsync.when(
      loading: () => Column(
        children: List.generate(5, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: SkeletonBox(height: 72, borderRadius: 8)))),
      error: (err, stack) => _buildFallbackRadioList(accentColor),
      data: (radios) {
        if (radios.isEmpty) {
          return _buildFallbackRadioList(accentColor);
        }
        return _buildRadioList(radios, accentColor);
      });
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
            border: Border.all(color: const Color(0xFF202028))),
          child: Row(
            children: [
              Icon(Icons.podcasts_rounded, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TEAM RADIO STREAM',
                    style: TextStyle( fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
                  Text(
                    '${radios.length} MESSAGES · LIVE SESSION',
                    style: const TextStyle( fontSize: 8.5,
                      color: Color(0xFF8F909A),
                      fontWeight: FontWeight.bold)),
                ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red)),
                child: const Text(
                  'LIVE',
                  style: TextStyle( fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.redAccent))),
            ])),
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

            return FigmaRadioCard(
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
              onTogglePlay: () => _toggleRadioPlayback(r.id, r.audioUrl));
          }),
      ]);
  }

  Widget _buildFallbackRadioList(Color accentColor) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.podcasts_rounded, color: Color(0xFF5F606B), size: 40),
            SizedBox(height: 12),
            Text(
              'NO RADIO MESSAGES',
              style: TextStyle( fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5F606B))),
            SizedBox(height: 4),
            Text(
              'Team radio will appear during live sessions',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F606B))),
          ])));
  }

  // ---------------------------------------------------------
  // 4. TYRE STRATEGY PANEL
  // ---------------------------------------------------------
  Widget _buildTyreStrategyPanel(
    AsyncValue<List<LiveTelemetry>> telemetryAsync,
    Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202028))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompoundLegendBadge('S', 'SOFT', const Color(0xFFFF1744)),
              _buildCompoundLegendBadge('M', 'MEDIUM', const Color(0xFFFFD600)),
              _buildCompoundLegendBadge('H', 'HARD', Colors.white),
              _buildCompoundLegendBadge('I', 'INTER', const Color(0xFF00E676)),
              _buildCompoundLegendBadge('W', 'WET', const Color(0xFF00B0FF)),
            ])),
        const SizedBox(height: 12),
        telemetryAsync.when(
          loading: () => Column(
            children: List.generate(10, (_) => const SkeletonTimingRow())),
          error: (_, __) => _buildTyreEmptyState(),
          data: (telemetry) {
            if (telemetry.isEmpty) return _buildTyreEmptyState();
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: telemetry.length,
              itemBuilder: (context, index) {
                final driver = telemetry[index];
                final pos = driver.pos;
                final driverMeta = getDriverData(driver.name);
                final code = driverMeta?.code ?? driver.name.split(' ').last.substring(0, 3).toUpperCase();
                Color teamColor;
                try {
                  final hex = driver.color.replaceAll('#', '');
                  teamColor = Color(int.parse('FF$hex', radix: 16));
                } catch (_) {
                  teamColor = getDriverTeamColor(driver.name);
                }
                final tyre = driver.tyre.isNotEmpty ? driver.tyre[0].toUpperCase() : '?';
                final tyreLife = driver.tyreLife;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141419),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(8)),
                    border: Border.all(color: const Color(0xFF202028))),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 20,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: teamColor,
                          borderRadius: BorderRadius.circular(1.5))),
                      SizedBox(
                        width: 22,
                        child: Text(
                          pos,
                          style: const TextStyle( fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white))),
                      SizedBox(
                        width: 36,
                        child: Text(
                          code,
                          style: const TextStyle( fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: _tyreColor(tyre).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: _tyreColor(tyre), width: 1)),
                          child: Text(
                            '$tyre · $tyreLife',
                            style: TextStyle( fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: _tyreColor(tyre)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis))),
                    ]));
              });
          }),
      ]);
  }

  Widget _buildTyreEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.tire_repair, color: Color(0xFF5F606B), size: 40),
            SizedBox(height: 12),
            Text(
              'NO TYRE DATA',
              style: TextStyle( fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5F606B))),
            SizedBox(height: 4),
            Text(
              'Tyre strategy data will appear during live sessions',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F606B))),
          ])));
  }

  Color _tyreColor(String compound) {
    switch (compound) {
      case 'S': return const Color(0xFFFF1744);
      case 'M': return const Color(0xFFFFD600);
      case 'H': return Colors.white;
      case 'I': return const Color(0xFF00E676);
      case 'W': return const Color(0xFF00B0FF);
      default: return Colors.grey;
    }
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
            border: Border.all(color: color, width: 1.3)),
          child: Center(
            child: Text(
              code,
              style: TextStyle( fontSize: 9,
                fontWeight: FontWeight.w900,
                color: color)))),
        const SizedBox(width: 4),
        Text(
          name,
          style: const TextStyle( fontSize: 9,
            color: Color(0xFF8F909A),
            fontWeight: FontWeight.bold)),
      ]);
  }
}
// Widget classes extracted to ../widgets/ — see imports above.

/// Two-step bottom sheet: pick a race, then pick a session type.
class _ReplaySessionPicker extends StatefulWidget {
  final List<RaceEvent> pastRaces;
  final String selectedMeeting;
  final void Function(RaceEvent race, String sessionType) onSelected;

  const _ReplaySessionPicker({
    required this.pastRaces,
    required this.selectedMeeting,
    required this.onSelected,
  });

  @override
  State<_ReplaySessionPicker> createState() => _ReplaySessionPickerState();
}

class _ReplaySessionPickerState extends State<_ReplaySessionPicker> {
  RaceEvent? _pickedRace;

  static const _allSessions = [
    {'type': 'race', 'label': 'RACE DAY', 'icon': Icons.emoji_events_rounded},
    {'type': 'qualifying', 'label': 'QUALIFYING', 'icon': Icons.timer_rounded},
    {'type': 'sprint', 'label': 'SPRINT', 'icon': Icons.bolt_rounded},
  ];

  List<Map<String, dynamic>> get _sessions => _pickedRace == null
      ? _allSessions.where((s) => s['type'] != 'sprint').toList()
      : _allSessions.where((s) => s['type'] != 'sprint' || (_pickedRace!.hasSprint)).toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          color: const Color(0xFF141419),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_pickedRace != null) ...[
                      GestureDetector(
                        onTap: () => setState(() => _pickedRace = null),
                        child: const Icon(Icons.chevron_left_rounded, color: Colors.cyanAccent, size: 22)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        _pickedRace == null ? 'SELECT RACE' : 'SELECT SESSION',
                        style: const TextStyle( fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, color: Colors.grey, size: 20)),
                  ])),
              const SizedBox(height: 4),
              if (_pickedRace != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Text(
                    _pickedRace!.name,
                    style: const TextStyle( fontSize: 10, color: Colors.grey))),
              const Divider(color: Color(0xFF202028)),
              Expanded(
                child: _pickedRace == null
                    ? _buildRaceList(scrollController)
                    : _buildSessionList()),
            ]));
      });
  }

  Widget _buildRaceList(ScrollController ctrl) {
    final reversed = widget.pastRaces.reversed.toList();
    return ListView.builder(
      controller: ctrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final race = reversed[i];
        final isSelected = race.name == widget.selectedMeeting;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          tileColor: isSelected ? Colors.cyanAccent.withValues(alpha: 0.08) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RD ${race.round}',
                style: const TextStyle( fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
              Text(
                getCountryFlag(race.countryCode),
                style: const TextStyle(fontSize: 16)),
            ]),
          title: Text(
            race.name.replaceAll(' Grand Prix', ' GP'),
            style: TextStyle( fontSize: 12,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              color: isSelected ? Colors.cyanAccent : Colors.white)),
          subtitle: Text(
            race.date.toIso8601String().substring(0, 10),
            style: const TextStyle( fontSize: 9, color: Colors.grey)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          onTap: () => setState(() => _pickedRace = race));
      });
  }

  Widget _buildSessionList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final s in _sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => widget.onSelected(_pickedRace!, s['type'] as String),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3))),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                      child: Icon(s['icon'] as IconData, color: Colors.cyanAccent, size: 20)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['label'] as String,
                            style: const TextStyle( fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(
                            s['type'] == 'race'
                                ? 'Lap-by-lap timing tower progression'
                                : s['type'] == 'qualifying'
                                    ? 'Q1 → Q2 → Q3 session breakdown'
                                    : 'Sprint race final results',
                            style: const TextStyle( fontSize: 9, color: Colors.grey)),
                        ])),
                    const Icon(Icons.play_circle_filled_rounded, color: Colors.cyanAccent, size: 22),
                  ])))),
      ]);
  }
}

/// Animated timing tower — each driver card gets a ValueKey so Flutter
/// smoothly animates position changes between laps instead of snapping.
class _AnimatedTimingStack extends StatelessWidget {
  final List<LiveTelemetry> drivers;
  final String overallFastestLapTime;
  final String selectedDriverCode;
  final void Function(String code) onDriverTap;

  const _AnimatedTimingStack({
    required this.drivers,
    required this.overallFastestLapTime,
    required this.selectedDriverCode,
    required this.onDriverTap,
  });

  static const double _rowH = 52.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: drivers.length * _rowH,
      child: Stack(
        children: drivers.asMap().entries.map((entry) {
          final index = entry.key;
          final d = entry.value;

          final driverMeta = getDriverData(d.name);
          final lastName = d.name.split(' ').lastOrNull ?? d.name;
          final code = driverMeta?.code ??
              lastName.substring(0, lastName.length.clamp(0, 3)).toUpperCase();
          final isSelected = code == selectedDriverCode;

          Color teamColor = Colors.white;
          try {
            final hex = d.color.replaceAll('#', '');
            teamColor = Color(int.parse('FF$hex', radix: 16));
          } catch (_) {
            teamColor = getDriverTeamColor(d.name);
          }

          final isFastest = d.isFastestLap ||
              (overallFastestLapTime.isNotEmpty &&
                  (d.bestLap == overallFastestLapTime ||
                      d.lastLap == overallFastestLapTime));

          return AnimatedPositioned(
            key: ValueKey(d.name),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            top: index * _rowH,
            left: 0,
            right: 0,
            height: _rowH,
            child: FigmaTimingRowWidget(
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
              lastLap: d.lastLap.isNotEmpty
                  ? d.lastLap
                  : (d.bestLap.isNotEmpty ? d.bestLap : '-'),
              isFastestLap: isFastest,
              drs: d.drs,
              teamColor: teamColor,
              isSelected: isSelected,
              portraitAsset: driverMeta?.portraitAsset ?? '',
              onTap: () => onDriverTap(code)));
        }).toList()));
  }
}
