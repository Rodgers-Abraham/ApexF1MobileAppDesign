import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/constants/countries.dart';
import '../../data/calendar_provider.dart';

class GPHeroWidget extends ConsumerStatefulWidget {
  final Color accent;
  const GPHeroWidget({super.key, required this.accent});

  @override
  ConsumerState<GPHeroWidget> createState() => _GPHeroWidgetState();
}

class _GPHeroWidgetState extends ConsumerState<GPHeroWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
    final calendarAsync = ref.watch(calendarProvider);
    final nextRace = ref.watch(nextRaceProvider);
    final nextSessionData = ref.watch(nextSessionProvider);
    final sessionStatus = ref.watch(sessionLiveStatusProvider).value;
    final isLiveNow = sessionStatus?.isLive ?? false;
    final userCountryName = ref.watch(authProvider).country;
    final userTz = userCountryName != null ? findCountry(userCountryName) : null;

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
        if (calendar.isEmpty || nextRace == null) {
          return const SizedBox(
            height: 100,
            child: Center(child: Text('No upcoming races', style: TextStyle(color: Colors.grey))),
          );
        }

        final now = DateTime.now();

        // Next session (any session type)
        final nextSession = nextSessionData?.session;
        final nextSessionRace = nextSessionData?.race;
        final sessionIsNotRace = nextSession != null && !nextSession.isRace;
        final sessionDiff = nextSession != null && nextSession.dateTime.isAfter(now)
            ? nextSession.dateTime.difference(now)
            : null;

        // Race countdown
        final diff = nextRace.date.isAfter(now) ? nextRace.date.difference(now) : Duration.zero;
        final d = diff.inDays;
        final h = diff.inHours % 24;
        final m = diff.inMinutes % 60;
        final s = diff.inSeconds % 60;

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
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 4,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF1744),
                    boxShadow: [
                      BoxShadow(color: Color(0xFFFF1744), blurRadius: 12, spreadRadius: 1),
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
                                  boxShadow: [BoxShadow(color: Color(0xFF00E676), blurRadius: 8, spreadRadius: 2)],
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
                                      '${sessionStatus?.meetingName ?? nextRace.name} · ${nextRace.circuit}',
                                      style: const TextStyle(fontFamily: 'Formula1', fontSize: 9, color: Colors.white),
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('PITWALL', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black)),
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
                                style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF8F909A), letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                nextRace.name.split(' ').first.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.wide(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              const Text(
                                'GRAND PRIX',
                                style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Color(0xFFFF1744)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF101014),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF202028)),
                          ),
                          child: Center(child: Text(getCountryFlag(nextRace.countryCode), style: const TextStyle(fontSize: 20))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Next session strip (shown when next session isn't the race itself)
                    if (sessionIsNotRace && sessionDiff != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A22),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2E2E3A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                nextSession.name.toUpperCase(),
                                style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 8, fontWeight: FontWeight.w900, color: Colors.cyanAccent),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (nextSessionRace?.name != nextRace.name)
                              Expanded(
                                child: Text(
                                  nextSessionRace?.name.replaceAll(' Grand Prix', ' GP') ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Formula1', fontSize: 9.5, color: Colors.white70),
                                ),
                              )
                            else
                              const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatSessionCountdown(sessionDiff),
                                  style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.cyanAccent),
                                ),
                                if (userTz != null)
                                  Text(
                                    fmtLocalTime(nextSession.dateTime.toUtc(), userTz),
                                    style: const TextStyle(fontFamily: 'Formula1', fontSize: 8, color: Colors.white54),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Race countdown header label
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'RACE STARTS IN',
                        style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF8F909A), letterSpacing: 0.8),
                      ),
                    ),
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
                                Text('CIRCUIT ${nextRace.round}', style: AppFonts.number(fontSize: 8.5, color: const Color(0xFF8F909A), fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(nextRace.circuit.toUpperCase(), textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppFonts.wide(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white)),
                                const SizedBox(height: 2),
                                Text('${nextRace.countryCode} · 2026', style: AppFonts.number(fontSize: 8.5, color: const Color(0xFF8F909A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    Row(
                      children: [
                        const Icon(Icons.cloud_outlined, color: Color(0xFFFFD600), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PARTLY CLOUDY', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.number(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('RAIN 10%', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.number(fontSize: 7.5, color: const Color(0xFF8F909A))),
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
      },
    );
  }

  String _formatSessionCountdown(Duration d) {
    if (d.inDays > 0) return '${d.inDays}D ${d.inHours % 24}H';
    if (d.inHours > 0) return '${d.inHours}H ${d.inMinutes % 60}M';
    return '${d.inMinutes}M ${d.inSeconds % 60}S';
  }

  Widget _buildCountdownCell(String value, String label, bool hasRightBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: hasRightBorder ? const Border(right: BorderSide(color: Color(0xFF202028), width: 1)) : null,
        ),
        child: Column(
          children: [
            Text(value, style: AppFonts.number(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF8F909A), letterSpacing: 0.8)),
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
          border: hasRightBorder ? const Border(right: BorderSide(color: Color(0xFF202028), width: 1)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppFonts.number(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
            Text(label, style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF8F909A))),
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
        Text(value, style: AppFonts.number(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 6.5, color: Color(0xFF8F909A))),
      ],
    );
  }
}
