import 'package:flutter/material.dart';

import '../../../../core/providers/telemetry/providers.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import 'replay_swap_queue.dart';

/// Race-replay timing tower.
///
/// Extracted from [LiveTrackerScreen._buildReplayTimingTower] so the swap-queue
/// controller and per-driver display state live in a dedicated [StatefulWidget].
class ReplayTimingTowerWidget extends StatefulWidget {
  final RaceReplayState replayState;

  /// Maps driver name → lap on which a penalty was issued.
  /// The icon persists for the rest of the replay session.
  final Map<String, int> penaltyLaps;

  const ReplayTimingTowerWidget({
    super.key,
    required this.replayState,
    required this.penaltyLaps,
  });

  @override
  State<ReplayTimingTowerWidget> createState() =>
      _ReplayTimingTowerWidgetState();
}

class _ReplayTimingTowerWidgetState extends State<ReplayTimingTowerWidget> {
  late ReplaySwapQueue _swapQueue;

  /// Per-driver badge shown after their most recent animated swap; cleared
  /// at the start of each new lap.
  final Map<String, String> _swapLabels = {};
  int _lastLap = 0;

  @override
  void initState() {
    super.initState();
    _swapQueue = ReplaySwapQueue(
      onStep: (step) {
        if (!mounted) return;
        setState(() => _swapLabels[step.driverName] = _labelFor(step.eventType));
      },
      onDone: () {},
    );
    _lastLap = widget.replayState.currentLap;
  }

  @override
  void didUpdateWidget(ReplayTimingTowerWidget old) {
    super.didUpdateWidget(old);
    final cur = widget.replayState.currentLap;
    if (cur != _lastLap && cur > 0) {
      _swapLabels.clear();
      _lastLap = cur;
      _enqueueSwaps();
    }
  }

  void _enqueueSwaps() {
    final cur = widget.replayState.currentLap;
    final events = widget.replayState.lapEventMap[cur] ?? [];
    final steps = <SwapStep>[];
    for (final e in events) {
      if (!{'OVERTAKE', 'PIT_GAIN', 'RETIREMENT_GAIN'}.contains(e.category)) {
        continue;
      }
      // `flag` stores the gainer's driver code (set during selectSessionById parsing).
      final gainerCode = e.flag;
      if (gainerCode == null || gainerCode.isEmpty) continue;
      final gainerTel = widget.replayState.telemetry
          .where((d) => d.name == gainerCode)
          .firstOrNull;
      if (gainerTel == null) continue;
      final toPos = int.tryParse(gainerTel.pos) ?? 0;
      steps.add(SwapStep(
        driverName: gainerCode,
        fromPos: toPos + 1,
        toPos: toPos,
        eventType: e.category,
        label: e.message,
      ));
    }
    // lap slot = 3000 ms / speedMultiplier (clamped so -1 real-time mode uses 3 s base)
    final spd =
        widget.replayState.speedMultiplier > 0 ? widget.replayState.speedMultiplier : 1;
    final lapSlotMs = 3000 ~/ spd;
    _swapQueue.enqueue(steps, lapSlotMs: lapSlotMs);
  }

  String _labelFor(String eventType) {
    switch (eventType) {
      case 'PIT_GAIN':
        return 'PIT';
      case 'RETIREMENT_GAIN':
        return 'RET';
      default:
        return 'OVR';
    }
  }

  @override
  void dispose() {
    _swapQueue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drivers = [...widget.replayState.telemetry]
      ..sort((a, b) =>
          (int.tryParse(a.pos) ?? 99).compareTo(int.tryParse(b.pos) ?? 99));

    if (widget.replayState.isLoading && drivers.isEmpty) {
      return Column(
          children: List.generate(10, (_) => const SkeletonTimingRow()));
    }
    if (drivers.isEmpty) {
      return Center(
        child: Text('NO TIMING DATA',
            style: DS.labelCaps(size: 10, color: DS.textMuted)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            SizedBox(
                width: 60,
                child: Text('POS / DRIVER',
                    style: DS.labelCaps(size: 8, color: DS.textMuted))),
            const Spacer(),
            Text('LAP TIME', style: DS.labelCaps(size: 8, color: DS.textMuted)),
            const SizedBox(width: 10),
            SizedBox(
                width: 48,
                child: Text('MOVE',
                    textAlign: TextAlign.center,
                    style: DS.labelCaps(size: 8, color: DS.textMuted))),
          ]),
        ),
        SizedBox(
          height: drivers.length * 52.0,
          child: Stack(
            children: drivers.asMap().entries.map((entry) {
              final index = entry.key;
              final d = entry.value;
              final teamColor = _hexToColor(d.color);
              final isActive = d.status == 'RACING' ||
                  d.status == 'ON TRACK' ||
                  d.status.isEmpty;
              final isDns = d.status == 'DNS';
              final dnfLabel = isDns
                  ? 'DNS'
                  : (isActive
                      ? null
                      : (d.dnfReason.isNotEmpty ? d.dnfReason : d.status));
              final lapTimeColor = d.isFastestThisLap
                  ? DS.purple
                  : (isActive ? DS.textPrimary : DS.textMuted);
              final lapTime = d.lastLap.isNotEmpty ? d.lastLap : '—';
              final swapLabel = _swapLabels[d.name];
              final hasPenalty = widget.penaltyLaps.containsKey(d.name);

              return AnimatedPositioned(
                key: Key('replay_timing_row_${d.name}'),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                top: index * 52.0,
                left: 0,
                right: 0,
                height: 52.0,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? DS.surface1 : DS.surface0,
                    borderRadius: DS.aeroCornerSm,
                    border: Border(
                        left: BorderSide(
                      color: isActive
                          ? teamColor
                          : teamColor.withValues(alpha: 0.25),
                      width: 3,
                    )),
                  ),
                  child: Row(children: [
                    SizedBox(
                        width: 28,
                        child: Text(
                          isDns ? '—' : 'P${d.pos}',
                          style: DS.telemetry(
                              size: 11,
                              color: isActive ? DS.textPrimary : DS.textMuted),
                        )),
                    const SizedBox(width: 6),
                    SizedBox(
                        width: 36,
                        child: Text(
                          d.name,
                          style: DS.driverCode(
                              size: 12,
                              color: isActive ? DS.textPrimary : DS.textMuted),
                        )),
                    // Penalty icon
                    if (hasPenalty) ...[
                      const SizedBox(width: 3),
                      Icon(
                        key: Key('replay_penalty_icon_${d.name}'),
                        Icons.flag_rounded,
                        size: 11,
                        color: DS.yellow,
                      ),
                    ],
                    // DNF/DNS badge
                    if (dnfLabel != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        key: Key('replay_dnf_badge_${d.name}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDns
                              ? DS.surface3
                              : DS.red.withValues(alpha: 0.15),
                          borderRadius: DS.aeroCornerSm,
                        ),
                        child: Text(
                          dnfLabel.length > 8
                              ? '${dnfLabel.substring(0, 8)}…'
                              : dnfLabel,
                          style: DS.labelCaps(
                              size: 7,
                              color: isDns ? DS.textMuted : DS.red),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      isActive ? lapTime : '—',
                      style: DS.telemetry(size: 11, color: lapTimeColor),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 48,
                      child: swapLabel != null
                          ? _SwapBadge(label: swapLabel)
                          : const SizedBox.shrink(),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return DS.textMuted;
  }
}

class _SwapBadge extends StatelessWidget {
  final String label;
  const _SwapBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    switch (label) {
      case 'PIT':
        bg = DS.teal.withValues(alpha: 0.2);
        break;
      case 'RET':
        bg = DS.textMuted.withValues(alpha: 0.2);
        break;
      default:
        bg = DS.green.withValues(alpha: 0.15);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: DS.aeroCornerSm),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_upward_rounded, size: 9, color: DS.green),
        const SizedBox(width: 2),
        Text(label, style: DS.labelCaps(size: 7, color: DS.textPrimary)),
      ]),
    );
  }
}
