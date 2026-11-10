import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_design_system.dart';

/// Shared Stitch-design app bar used across all main screens.
class DSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;
  final bool isLive;
  final String? liveLabel;
  final String? latencyMs;
  final List<Widget>? extraActions;

  const DSAppBar({
    super.key,
    required this.subtitle,
    this.isLive = false,
    this.liveLabel,
    this.latencyMs,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: DS.surface0,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 12,
      title: Row(
        children: [
          // Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏁', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('APEX', style: DS.driverCode(size: 13, color: DS.textPrimary)),
              const SizedBox(width: 3),
              DSWidgets.redBadge('F1', size: 9),
            ],
          ),
          const SizedBox(width: 8),
          // Vertical divider
          Container(width: 1, height: 20, color: DS.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle.toUpperCase(),
              style: DS.labelCaps(size: 8, color: DS.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (isLive || liveLabel != null) ...[
          _LiveBadge(label: liveLabel ?? 'LIVE'),
          const SizedBox(width: 6),
        ],
        if (latencyMs != null) ...[
          _LatencyChip(ms: latencyMs!),
          const SizedBox(width: 6),
        ],
        ...?extraActions,
        GestureDetector(
          onTap: () => GoRouter.of(context).go('/settings'),
          child: const _AvatarChip(),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final String label;
  const _LiveBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: DS.red.withValues(alpha: 0.15),
        borderRadius: DS.aeroCornerSm,
        border: Border.all(color: DS.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: DS.red, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: DS.labelCaps(size: 8, color: DS.red)),
        ],
      ),
    );
  }
}

class _LatencyChip extends StatelessWidget {
  final String ms;
  const _LatencyChip({required this.ms});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: DS.surface2,
        borderRadius: DS.aeroCornerSm,
        border: Border.all(color: DS.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi, size: 9, color: DS.teal),
          const SizedBox(width: 3),
          Text('${ms}ms', style: DS.labelCaps(size: 8, color: DS.teal)),
        ],
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: DS.surface3,
        shape: BoxShape.circle,
        border: Border.all(color: DS.outline),
      ),
      child: Icon(Icons.person, size: 16, color: DS.textMuted),
    );
  }
}

/// Full-width live ticker strip with scrolling track status text.
class DSTickerStrip extends StatefulWidget {
  final String text;
  final Color? dotColor;
  const DSTickerStrip({super.key, required this.text, this.dotColor});

  @override
  State<DSTickerStrip> createState() => _DSTickerStripState();
}

class _DSTickerStripState extends State<DSTickerStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _anim = Tween<Offset>(begin: const Offset(0, 0), end: const Offset(-1, 0))
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DS.surface0,
      height: 26,
      child: ClipRect(
        child: Stack(
          children: [
            // Left dot
            Positioned(
              left: 10,
              top: 0, bottom: 0,
              child: Center(
                child: Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    color: widget.dotColor ?? DS.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: SlideTransition(
                position: _anim,
                child: Text(
                  '${widget.text}    ${widget.text}',
                  style: DS.labelCaps(size: 8, color: DS.textMuted),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
