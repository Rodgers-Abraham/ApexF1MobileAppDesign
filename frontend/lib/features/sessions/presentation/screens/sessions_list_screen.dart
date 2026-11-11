import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../data/sessions_provider.dart';

/// Shared state: which session ID is currently selected for replay
final selectedReplaySessionProvider = StateProvider<String?>((ref) => null);

class SessionsListScreen extends ConsumerWidget {
  const SessionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: DSAppBar(subtitle: 'SESSION REPLAY'),
      body: sessionsAsync.when(
        loading: () => const SkeletonStandingsList(count: 8),
        error: (err, _) => ErrorRetryWidget(
          message: 'Could not load sessions.\nCheck your connection.',
          icon: Icons.timer_outlined,
          onRetry: () => ref.invalidate(allSessionsProvider),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 48, color: DS.textMuted),
                  const SizedBox(height: 12),
                  Text('NO SESSIONS AVAILABLE',
                      style: DS.labelCaps(size: 11, color: DS.textMuted)),
                  const SizedBox(height: 4),
                  Text('Sessions appear ~30 min after each race',
                      style: DS.body(size: 12)),
                ],
              ),
            );
          }

          final byYear = <int, List<EventSessions>>{};
          for (final e in events) {
            byYear.putIfAbsent(e.year, () => []).add(e);
          }
          final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

          // Build a flat list of items: year header + event cards
          final items = <_ListItem>[];
          for (final year in years) {
            items.add(_YearHeaderItem(year: year, count: byYear[year]!.length));
            for (final ev in byYear[year]!) {
              items.add(_EventItem(ev: ev));
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: items.length,
            itemBuilder: (ctx, index) {
              final item = items[index];
              if (item is _YearHeaderItem) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 6),
                  child: Row(children: [
                    Container(width: 3, height: 16, color: DS.red),
                    const SizedBox(width: 8),
                    Text('${item.year}', style: DS.headline(size: 16)),
                    const Spacer(),
                    DSWidgets.statusChip('${item.count} EVENTS',
                        color: DS.textMuted, size: 7),
                  ]),
                );
              }
              final evItem = item as _EventItem;
              return _buildEventCard(context, ref, evItem.ev);
            },
          );
        },
      ),
    );
  }

  Widget _buildEventCard(
      BuildContext context, WidgetRef ref, EventSessions ev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DS.surface1,
        borderRadius: DS.aeroCorner,
        border: Border.all(color: DS.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                ev.eventName.toUpperCase(),
                style: DS.driverCode(size: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (ev.country.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(ev.country,
                  style: DS.labelCaps(size: 8, color: DS.textMuted)),
            ],
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ev.sessions.map((sess) {
              final label = EventSessions.sessionTypeLabel(sess.sessionType);
              final color = _chipColor(sess.sessionType);
              return GestureDetector(
                onTap: () => _openSession(context, ref, sess),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: DS.aeroCornerSm,
                    border:
                        Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(label,
                      style: DS.labelCaps(size: 9, color: color)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _chipColor(String sessionType) {
    switch (sessionType) {
      case 'Race':
        return DS.red;
      case 'Sprint':
        return DS.orange;
      case 'Q':
      case 'SQ':
        return DS.yellow;
      default:
        return DS.teal;
    }
  }

  void _openSession(
      BuildContext context, WidgetRef ref, SessionEntry sess) {
    ref.read(selectedReplaySessionProvider.notifier).state = sess.id;
    context.go('/live');
  }
}

// Internal list item types to avoid nested counting bugs
abstract class _ListItem {}

class _YearHeaderItem extends _ListItem {
  final int year;
  final int count;
  _YearHeaderItem({required this.year, required this.count});
}

class _EventItem extends _ListItem {
  final EventSessions ev;
  _EventItem({required this.ev});
}
