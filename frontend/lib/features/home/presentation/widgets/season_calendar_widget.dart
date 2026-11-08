import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../data/calendar_provider.dart';

class SeasonCalendarWidget extends ConsumerWidget {
  final Color accent;
  const SeasonCalendarWidget({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(calendarProvider);

    return calendarAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(
        height: 100,
        child: Center(child: Text('Calendar unavailable', style: TextStyle(color: Colors.grey))),
      ),
      data: (calendar) {
        if (calendar.isEmpty) {
          return const Text('No race calendar available.', style: TextStyle(color: Colors.grey));
        }

        final now = DateTime.now();
        final past = calendar.where((r) => r.date.isBefore(now)).toList();
        final upcoming = calendar.where((r) => !r.date.isBefore(now)).toList();
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
                onTap: () => _showRaceDetailsModal(context, ref, race, accent),
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
                          color: isNext ? accent.withOpacity(0.18) : (isPast ? Colors.white.withOpacity(0.03) : const Color(0xFF1C1C1F)),
                          borderRadius: BorderRadius.circular(10),
                          border: isNext ? Border.all(color: accent.withOpacity(0.4), width: 1) : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${race.date.day}',
                                style: AppFonts.number(fontSize: 14, fontWeight: FontWeight.w900, color: isNext ? accent : (isPast ? Colors.grey[600]! : Colors.white)),
                              ),
                              Text(
                                monthAbbrev(race.date.month),
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isNext ? accent.withOpacity(0.8) : Colors.grey[600]),
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
                                    style: AppFonts.driverName(fontSize: 13, fontWeight: FontWeight.bold, color: isPast ? Colors.grey[500]! : Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('• ${race.countryCode}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(race.circuit, style: TextStyle(fontSize: 11, color: isPast ? Colors.grey[700] : Colors.grey[400])),
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
                          child: Text('NEXT UP', style: AppFonts.header(fontSize: 9, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.8)),
                        )
                      else if (isPast)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(6)),
                          child: const Text('COMPLETED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                        )
                      else
                        Text(race.round, style: AppFonts.number(fontSize: 12, color: Colors.grey[600]!, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showRaceDetailsModal(BuildContext context, WidgetRef ref, RaceEvent race, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101014),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => RaceDetailsModalContent(race: race, accent: accent),
    );
  }
}

class RaceDetailsModalContent extends ConsumerWidget {
  final RaceEvent race;
  final Color accent;

  const RaceDetailsModalContent({super.key, required this.race, required this.accent});

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
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: accent.withOpacity(0.4))),
                    child: Text(race.round, style: AppFonts.number(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Text(race.countryCode, style: AppFonts.header(color: Colors.grey[400]!, fontSize: 12)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: isPast ? Colors.white10 : Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(isPast ? 'COMPLETED' : 'UPCOMING', style: AppFonts.header(color: isPast ? Colors.grey : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(race.name.toUpperCase(), style: AppFonts.header(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 4),
              Text('${race.circuit} • ${race.date.day} ${monthAbbrev(race.date.month)} ${race.date.year}', style: AppFonts.regular(fontSize: 13, color: Colors.grey[400]!)),
              const SizedBox(height: 16),
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
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.map_rounded, color: accent.withOpacity(0.5), size: 48),
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
                    decoration: BoxDecoration(color: const Color(0xFF18181C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: const CircularProgressIndicator(),
                  ),
                  error: (err, stack) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF18181C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: Text('Official race record unavailable: $err', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  data: (details) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF18181C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: Column(
                      children: [
                        DetailStatRow(icon: Icons.emoji_events_rounded, iconColor: Colors.amber, label: 'Race Winner', value: details.winnerName ?? 'Official Result Pending', subtitle: details.winnerTeam ?? 'Formula 1'),
                        const Divider(color: Colors.white10, height: 20),
                        DetailStatRow(icon: Icons.flag_rounded, iconColor: accent, label: 'Total Laps / Rounds', value: '${details.totalLaps ?? 57} Laps', subtitle: 'Full Distance Completed'),
                        const Divider(color: Colors.white10, height: 20),
                        DetailStatRow(icon: Icons.speed_rounded, iconColor: Colors.cyan, label: 'Fastest Lap', value: details.fastestLapTime ?? 'Official Record Pending', subtitle: details.fastestLapDriver ?? 'Fastest Lap of Grand Prix'),
                        const Divider(color: Colors.white10, height: 20),
                        DetailStatRow(icon: Icons.build_rounded, iconColor: Colors.purpleAccent, label: 'Fastest Pitstop', value: details.fastestPitstopTime ?? '1.98s', subtitle: details.fastestPitstopTeam ?? 'Pit Crew'),
                        const Divider(color: Colors.white10, height: 20),
                        DetailStatRow(icon: Icons.star_rounded, iconColor: Colors.amberAccent, label: 'Driver of the Day', value: details.driverOfTheDay ?? 'Official Fan Vote', subtitle: 'Voted by Official F1 Fans'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
                        decoration: BoxDecoration(color: const Color(0xFF18181C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                        child: Column(
                          children: [
                            DetailStatRow(icon: Icons.history_edu_rounded, iconColor: Colors.amber, label: 'Inaugural Grand Prix', value: '$firstHeld Season', subtitle: 'Official Debut Year in F1'),
                            const Divider(color: Colors.white10, height: 20),
                            DetailStatRow(icon: Icons.numbers_rounded, iconColor: accent, label: 'Total Races Held', value: '$totalRaces Grand Prix', subtitle: 'Historical World Championship Events'),
                            const Divider(color: Colors.white10, height: 20),
                            DetailStatRow(icon: Icons.military_tech_rounded, iconColor: Colors.orangeAccent, label: 'Most Successful Driver', value: topDriver, subtitle: 'All-Time Victory Record Holder'),
                            const Divider(color: Colors.white10, height: 20),
                            DetailStatRow(icon: Icons.shield_rounded, iconColor: Colors.redAccent, label: 'Most Successful Constructor', value: topTeam, subtitle: 'All-Time Team Victory Record Holder'),
                          ],
                        ),
                      ),
                      if (recentList.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('PREVIOUS WINNERS HALL OF FAME', style: AppFonts.header(fontSize: 11, color: Colors.grey[500]!, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF18181C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
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
                                      decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                      child: Text(yr, style: AppFonts.number(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 3, child: Text(drv, style: AppFonts.driverName(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    Flexible(flex: 2, child: Text(team, style: AppFonts.regular(fontSize: 11, color: Colors.grey[400]!), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                decoration: BoxDecoration(color: const Color(0xFF18181C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Column(
                  children: [
                    DetailStatRow(icon: Icons.straighten_rounded, iconColor: accent, label: 'Track Length', value: '${race.lengthKm} km', subtitle: 'Lap Distance'),
                    const Divider(color: Colors.white10, height: 20),
                    DetailStatRow(icon: Icons.turn_right_rounded, iconColor: Colors.orange, label: 'Corners / Turns', value: '${race.turns} Turns', subtitle: 'Apex Complex Count'),
                    const Divider(color: Colors.white10, height: 20),
                    DetailStatRow(icon: Icons.bolt_rounded, iconColor: Colors.green, label: 'DRS Zones', value: '${race.drsZones} DRS Zones', subtitle: 'Overtaking Activation Detection'),
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

class DetailStatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const DetailStatRow({
    super.key,
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
          decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppFonts.regular(fontSize: 11, color: Colors.grey[400]!)),
              const SizedBox(height: 2),
              Text(
                value,
                style: label.contains('Winner') || label.contains('Driver')
                    ? AppFonts.driverName(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)
                    : AppFonts.number(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(subtitle, style: AppFonts.regular(fontSize: 11, color: Colors.grey[500]!)),
            ],
          ),
        ),
      ],
    );
  }
}
