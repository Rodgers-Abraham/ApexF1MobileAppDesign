import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/skeleton_widget.dart';

class RacePulseWidget extends ConsumerWidget {
  final Color accent;
  const RacePulseWidget({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(liveTelemetryFeedProvider);

    final leader = telemetryAsync.valueOrNull?.isNotEmpty == true
        ? telemetryAsync.value!.first
        : null;
    final fastestLapDriver = telemetryAsync.valueOrNull
        ?.where((t) => t.isFastestLap)
        .toList();
    final fastestLap = (fastestLapDriver != null && fastestLapDriver.isNotEmpty)
        ? fastestLapDriver.first
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'RACE PULSE',
                style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              leader != null ? 'LIVE DATA' : 'AWAITING DATA',
              style: DS.labelCaps(size: 9, color: DS.textMuted),
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
              child: telemetryAsync.when(
                loading: () => const SkeletonBox(height: 40, borderRadius: 8),
                error: (_, __) => const Text('Live telemetry unavailable', style: TextStyle(color: Colors.grey, fontSize: 12)),
                data: (_) => Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LEADER', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 7.5, color: Color(0xFF8F909A), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(width: 3, height: 12, color: leader != null ? _parseHex(leader.color) : Colors.grey),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  leader?.name.split(' ').last.toUpperCase() ?? '---',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DS.headlineMd(size: 13, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            leader != null ? '${leader.team.toUpperCase()} · ${leader.tyre} ${leader.tyreLife}' : '---',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DS.labelCaps(size: 8.5, color: DS.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FASTEST LAP', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 7.5, color: Color(0xFF8F909A), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(
                            fastestLap?.bestLap ?? '---',
                            style: DS.telemetry(size: 13, color: const Color(0xFFB388FF)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fastestLap != null ? '${fastestLap.name.split(' ').last.toUpperCase()} · ${fastestLap.team}' : '---',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DS.labelCaps(size: 8.5, color: DS.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
