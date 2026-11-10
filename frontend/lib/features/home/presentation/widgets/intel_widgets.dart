import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/widgets/skeleton_widget.dart';

class CompactStandingsWidget extends ConsumerWidget {
  final Color accent;
  const CompactStandingsWidget({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(liveDriverStandingsProvider);
    final constructorsAsync = ref.watch(liveConstructorStandingsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('DRIVERS', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[700]),
              ]),
              const SizedBox(height: 12),
              driversAsync.when(
                loading: () => const LoadingDots(),
                error: (_, __) => const Text('Unable to load standings', style: TextStyle(color: Colors.grey, fontSize: 12)),
                data: (drivers) => Column(
                  children: drivers.take(5).toList().asMap().entries.map((e) {
                    final d = e.value;
                    final idx = e.key;
                    const colors = [Color(0xFFFFC107), Color(0xFFC0C0C0), Color(0xFFCD7F32), Colors.white, Colors.white];
                    return StandingRow(pos: d.pos, name: d.name, team: d.team, points: d.pts, color: idx < 3 ? colors[idx] : Colors.white, isTop3: idx < 3);
                  }).toList())),
            ])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('CONSTRUCTORS', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[700]),
              ]),
              const SizedBox(height: 12),
              constructorsAsync.when(
                loading: () => const LoadingDots(),
                error: (_, __) => const Text('Unable to load standings', style: TextStyle(color: Colors.grey, fontSize: 12)),
                data: (constructors) => Column(
                  children: constructors.take(5).toList().asMap().entries.map((e) {
                    final c = e.value;
                    final idx = e.key;
                    const colors = [Color(0xFFFFC107), Color(0xFFC0C0C0), Color(0xFFCD7F32), Colors.white, Colors.white];
                    return StandingRow(pos: c.pos, name: c.name, team: '', points: c.pts, color: idx < 3 ? colors[idx] : Colors.white, isTop3: idx < 3, showTeam: false);
                  }).toList())),
            ])),
      ]);
  }
}

class StandingRow extends StatelessWidget {
  final String pos;
  final String name;
  final String team;
  final String points;
  final Color color;
  final bool isTop3;
  final bool showTeam;
  const StandingRow({super.key, required this.pos, required this.name, required this.team, required this.points, required this.color, this.isTop3 = false, this.showTeam = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: isTop3 ? color.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text(pos, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: color.withOpacity(isTop3 ? 0.6 : 0.9))))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                if (showTeam) Text(team, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ])),
          Text('${points}pts', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ]));
  }
}

class CompactLiveTimingWidget extends ConsumerWidget {
  const CompactLiveTimingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(liveTelemetryFeedProvider);

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: telemetry.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: LoadingDots()),
        error: (_, __) => const Padding(padding: EdgeInsets.all(24), child: Text('Live timing unavailable', style: TextStyle(color: Colors.grey, fontSize: 12))),
        data: (drivers) => Column(
          children: drivers.take(10).map((t) {
            Color teamColor = Colors.blue;
            try {
              final hex = t.color.replaceAll('#', '');
              teamColor = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {}

            final isDnf = t.status == 'DNF' || t.status == 'RETIRED';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          child: Text(t.pos, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: isDnf ? Colors.redAccent : Colors.white))),
                        if (!isDnf)
                          if (t.positionsGained > 0)
                            Text('▲${t.positionsGained}', style: const TextStyle(color: Color(0xFF00E676), fontSize: 8.5, fontWeight: FontWeight.bold))
                          else if (t.positionsGained < 0)
                            Text('▼${t.positionsGained.abs()}', style: const TextStyle(color: Color(0xFFFF5252), fontSize: 8.5, fontWeight: FontWeight.bold))
                          else
                            const Text('-', style: TextStyle(color: Colors.grey, fontSize: 9)),
                      ])),
                  Container(width: 3, height: 18, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: teamColor, borderRadius: BorderRadius.circular(1.5))),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: Text(t.name, style: TextStyle(fontSize: 12, color: isDnf ? Colors.grey : Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (isDnf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                            child: const Text('DNF', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold))),
                        ],
                      ])),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.gap, style: TextStyle(fontSize: 11, color: t.gap == 'LEADER' ? Colors.green : (isDnf ? Colors.grey : Colors.grey[400]), fontWeight: FontWeight.w600)),
                      if (t.gap != 'LEADER' && t.interval.isNotEmpty && !isDnf)
                        Text('+${t.interval}', style: TextStyle(fontSize: 8.5, color: Colors.grey[600])),
                    ]),
                  const SizedBox(width: 12),
                  TyreBadge(tyre: t.tyre),
                ]));
          }).toList())));
  }
}

class TyreBadge extends StatelessWidget {
  final String tyre;
  const TyreBadge({super.key, required this.tyre});
  @override
  Widget build(BuildContext context) {
    Color c = Colors.grey;
    if (tyre == 'S') c = Colors.red;
    if (tyre == 'M') c = const Color(0xFFFFB300);
    if (tyre == 'H') c = Colors.white;
    if (tyre == 'W') c = Colors.blue;
    if (tyre == 'I') c = Colors.cyan;
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(color: c.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: c, width: 1.5)),
      child: Center(child: Text(tyre, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold))));
  }
}

class PaddockIntelWidget extends ConsumerWidget {
  final Color accent;
  const PaddockIntelWidget({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(liveNewsFeedProvider);

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: newsAsync.when(
        loading: () => const SkeletonCardRow(count: 2, cardWidth: 280, cardHeight: 180),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Live paddock news stream temporarily unavailable', style: TextStyle(color: Colors.grey[500], fontSize: 12))),
        data: (articles) {
          final displayArticles = articles.take(5).toList();
          if (displayArticles.isEmpty) {
            return const Padding(padding: EdgeInsets.all(16.0), child: Text('No recent paddock intelligence reports.', style: TextStyle(color: Colors.grey, fontSize: 12)));
          }

          return Column(
            children: displayArticles.map((item) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (item.url.isEmpty) return;
                    final uri = Uri.tryParse(item.url);
                    if (uri != null) {
                      try {
                        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                        if (!launched && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open article in browser')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open article: $e')));
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.imageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.imageUrl,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 68, height: 68,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.article_rounded, color: accent, size: 24)))),
                          const SizedBox(width: 12),
                        ] else ...[
                          Container(width: 3, height: 40, decoration: BoxDecoration(color: accent.withOpacity(0.6), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: accent.withOpacity(0.25))),
                                    child: Text(item.source.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: accent, letterSpacing: 0.5))),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item.publishedAt.isNotEmpty ? item.publishedAt : 'Live Feed', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[600]))),
                                  Icon(Icons.open_in_new_rounded, size: 12, color: Colors.grey[600]),
                                ]),
                            ])),
                      ]))));
            }).toList());
        }));
  }
}

class TrackConditionsWidget extends ConsumerWidget {
  final Color accent;
  const TrackConditionsWidget({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditionsAsync = ref.watch(trackConditionsProvider);

    return conditionsAsync.when(
      loading: () => const SkeletonBox(height: 120, borderRadius: 16),
      error: (err, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)),
        child: Text('Track telemetry sensor stream unavailable', style: TextStyle(color: Colors.grey[500], fontSize: 12))),
      data: (cond) {
        final conditionItems = [
          {'icon': Icons.thermostat, 'label': 'Track Temp', 'value': cond.trackTemperature},
          {'icon': Icons.cloud_queue, 'label': 'Air Temp', 'value': cond.airTemperature},
          {'icon': Icons.water_drop_outlined, 'label': 'Humidity', 'value': cond.humidity},
          {'icon': Icons.wind_power_outlined, 'label': 'Wind', 'value': cond.windSpeed},
        ];
        final isDry = cond.trackStatus.toUpperCase() == 'DRY';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: conditionItems.map((c) {
                  return Expanded(
                    child: Column(
                      children: [
                        Icon(c['icon'] as IconData, color: Colors.grey[500], size: 20),
                        const SizedBox(height: 6),
                        Text(c['value'] as String, style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(c['label'] as String, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ]));
                }).toList()),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: isDry ? Colors.green : Colors.blue, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cond.summary, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
                    Icon(cond.rainfall ? Icons.umbrella : Icons.wb_sunny_outlined, size: 16, color: isDry ? Colors.amber : Colors.cyan),
                  ])),
            ]));
      });
  }
}

class TireStrategyWidget extends ConsumerWidget {
  final Color accent;
  const TireStrategyWidget({super.key, required this.accent});

  Color _parseHex(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tireAsync = ref.watch(tireStrategyProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: tireAsync.when(
        loading: () => const SkeletonCardRow(count: 2, cardWidth: 240, cardHeight: 140),
        error: (err, stack) => Text('Tire stint strategy data unavailable', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        data: (data) {
          final items = data.strategies;
          if (items.isEmpty) {
            return const Text('No tire stint telemetry recorded for latest session.', style: TextStyle(color: Colors.grey, fontSize: 12));
          }
          final maxObservedLaps = items.map((i) => i.laps).fold(1, (a, b) => a > b ? a : b);

          return Column(
            children: items.map((s) {
              final color = _parseHex(s.color, Colors.white);
              final widthFrac = (s.laps / (maxObservedLaps > 0 ? maxObservedLaps : 57)).clamp(0.15, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(s.compound, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.8))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(4)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widthFrac,
                          child: Container(decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(4)))))),
                    const SizedBox(width: 10),
                    Text('${s.laps} L max', style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 6),
                    Text('(${s.stintsCount} stints)', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ]));
            }).toList());
        }));
  }
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});
  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: [0, 1, 2].map((i) {
        return AnimatedBuilder(animation: _controller, builder: (_, __) {
          final value = (math.sin((_controller.value * 2 * math.pi) + i * 0.8) + 1) / 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6, height: 6,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3 + value * 0.7), shape: BoxShape.circle));
        });
      }).toList()));
  }
}
