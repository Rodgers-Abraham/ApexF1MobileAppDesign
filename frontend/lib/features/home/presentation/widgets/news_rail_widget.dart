import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/widgets/skeleton_widget.dart';

class NewsRailWidget extends ConsumerWidget {
  final Color accent;
  const NewsRailWidget({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(liveNewsFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'PADDOCK FEED',
                style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('LATEST ARTICLES', style: AppFonts.number(fontSize: 9, color: Colors.grey[500]!, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (context) {
            final articles = newsAsync.valueOrNull ?? [];
            if (newsAsync.isLoading && articles.isEmpty) {
              return const SkeletonCardRow(count: 3, cardWidth: 280, cardHeight: 235);
            }
            if (articles.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF141419), borderRadius: BorderRadius.circular(10)),
                child: Text('No recent paddock articles available.', style: AppFonts.regular(fontSize: 11, color: Colors.grey)),
              );
            }

            return SizedBox(
              height: 235,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: articles.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = articles[index];
                  return Container(
                    width: 280,
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
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          if (item.url.isEmpty) return;
                          final uri = Uri.tryParse(item.url);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (item.imageUrl.isNotEmpty)
                                    Image.network(
                                      item.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFF202028),
                                        child: const Center(child: Icon(Icons.sports_motorsports, color: Colors.grey, size: 30)),
                                      ),
                                    )
                                  else
                                    Container(
                                      color: const Color(0xFF202028),
                                      child: const Center(child: Icon(Icons.sports_motorsports, color: Colors.grey, size: 30)),
                                    ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                                          stops: const [0.4, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                                      child: Text(
                                        item.category.isNotEmpty ? item.category.toUpperCase() : 'OFFICIAL',
                                        style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 7.5, fontWeight: FontWeight.w900, color: Color(0xFF0B0B0E)),
                                      ),
                                    ),
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
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: 'Formula1', fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white, height: 1.25),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.timeAgo.isNotEmpty ? item.timeAgo : "RECENT"} · ${item.source.toUpperCase()}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.number(fontSize: 8, color: const Color(0xFF8F909A), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_outward_rounded, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
