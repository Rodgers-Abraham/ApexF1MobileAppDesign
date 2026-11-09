import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../data/recaps_provider.dart';
import '../../data/calendar_provider.dart';

class RaceRecapsWidget extends ConsumerWidget {
  final Color accent;
  const RaceRecapsWidget({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recapsAsync = ref.watch(recapsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RACE RECAPS',
              style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
            ),
            Text('2026 SEASON', style: AppFonts.number(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        recapsAsync.when(
          loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Colors.red))),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF141419), borderRadius: BorderRadius.circular(10)),
            child: Text('Recaps unavailable.', style: AppFonts.regular(fontSize: 11, color: Colors.grey)),
          ),
          data: (recaps) {
            if (recaps.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF141419), borderRadius: BorderRadius.circular(10)),
                child: Text('No completed races yet this season.', style: AppFonts.regular(fontSize: 11, color: Colors.grey)),
              );
            }
            return SizedBox(
              height: 195,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recaps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _RecapCard(recap: recaps[index], accent: accent),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  final RaceRecap recap;
  final Color accent;
  const _RecapCard({required this.recap, required this.accent});

  @override
  Widget build(BuildContext context) {
    final teamData = recap.winnerTeam.isNotEmpty ? getTeamData(recap.winnerTeam) : null;
    final teamColor = teamData?.primaryColor ?? accent;
    final flag = getCountryFlag(recap.country);

    return Container(
      width: 190,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: teamColor.withValues(alpha: 0.4), width: 1)),
            ),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'RD ${recap.round}',
                    style: AppFonts.number(fontSize: 9, fontWeight: FontWeight.w900, color: teamColor),
                  ),
                ),
                Text(
                  recap.date.length >= 7 ? recap.date.substring(5, 7) + '/' + recap.date.substring(0, 4) : recap.date,
                  style: AppFonts.number(fontSize: 8, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recap.raceName.replaceAll(' Grand Prix', ' GP'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 6),
                if (recap.winnerDriver.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, size: 11, color: Color(0xFFFFD700)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          recap.winnerDriver,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.regular(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(recap.winnerTeam, style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 8, color: teamColor)),
                ] else
                  Text('Results pending', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 10),
                // YouTube links
                Row(
                  children: [
                    _YtButton(label: 'RACE', url: recap.youtubeSearchUrl, color: const Color(0xFFFF0000)),
                    const SizedBox(width: 6),
                    _YtButton(label: 'QUALI', url: recap.qualiYoutubeUrl, color: Colors.grey.shade700),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YtButton extends StatelessWidget {
  final String label;
  final String url;
  final Color color;
  const _YtButton({required this.label, required this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_filled_rounded, size: 10, color: color),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 7.5, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
