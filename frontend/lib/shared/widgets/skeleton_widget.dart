import 'dart:math';
import 'package:flutter/material.dart';

/// A single shimmer skeleton block. Animates a gradient sweep left-to-right.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 4,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200))..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                max(0.0, _animation.value - 0.3),
                _animation.value,
                min(1.0, _animation.value + 0.3),
              ],
              colors: const [
                Color(0xFF1A1A22),
                Color(0xFF2A2A35),
                Color(0xFF1A1A22),
              ])));
      });
  }
}

/// Skeleton card for a standings row (driver or constructor).
class SkeletonStandingsRow extends StatelessWidget {
  const SkeletonStandingsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const SkeletonBox(width: 28, height: 28, borderRadius: 6),
          const SizedBox(width: 10),
          const SkeletonBox(width: 36, height: 36, borderRadius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 12),
                const SizedBox(height: 5),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.3, height: 10),
              ])),
          const SizedBox(width: 10),
          const SkeletonBox(width: 44, height: 20, borderRadius: 4),
        ]));
  }
}

/// Skeleton list of N standings rows.
class SkeletonStandingsList extends StatelessWidget {
  final int count;
  const SkeletonStandingsList({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonStandingsRow());
  }
}

/// Skeleton for the GP hero card in the pitwall.
class SkeletonHeroCard extends StatelessWidget {
  const SkeletonHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18)),
        border: Border.all(color: const Color(0xFF292932))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 160, height: 11),
          const SizedBox(height: 8),
          const SkeletonBox(width: 200, height: 28),
          const SizedBox(height: 6),
          const SkeletonBox(width: 130, height: 22),
          const SizedBox(height: 20),
          // Countdown row
          Row(children: List.generate(4, (i) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: const SkeletonBox(height: 44))))),
          const SizedBox(height: 16),
          const SkeletonBox(height: 100),
        ]));
  }
}

/// Skeleton for news/recap cards in a horizontal list.
class SkeletonCardRow extends StatelessWidget {
  final int count;
  final double cardWidth;
  final double cardHeight;

  const SkeletonCardRow({
    super.key,
    this.count = 3,
    this.cardWidth = 280,
    this.cardHeight = 235,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => SkeletonBox(
          width: cardWidth,
          height: cardHeight,
          borderRadius: 14)));
  }
}

/// Skeleton for a timing tower row (position + driver code + gap).
class SkeletonTimingRow extends StatelessWidget {
  const SkeletonTimingRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8)),
        border: Border.all(color: const Color(0xFF272732))),
      child: const Row(
        children: [
          SkeletonBox(width: 24, height: 24, borderRadius: 4),
          SizedBox(width: 10),
          SkeletonBox(width: 36, height: 14, borderRadius: 4),
          SizedBox(width: 8),
          SkeletonBox(width: 48, height: 10, borderRadius: 4),
          Spacer(),
          SkeletonBox(width: 60, height: 14, borderRadius: 4),
          SizedBox(width: 8),
          SkeletonBox(width: 40, height: 12, borderRadius: 4),
        ]));
  }
}

/// Skeleton for a chat/AI response bubble.
class SkeletonChatBubble extends StatelessWidget {
  const SkeletonChatBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 28, height: 28, borderRadius: 6),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F23),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8)),
                border: Border.all(color: const Color(0xFF272732))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(height: 10, borderRadius: 3),
                  const SizedBox(height: 8),
                  const SkeletonBox(height: 10, borderRadius: 3),
                  const SizedBox(height: 6),
                  SkeletonBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 10,
                    borderRadius: 3),
                ]))),
        ]));
  }
}

/// Skeleton for a driver portrait chip (used in the settings driver picker).
class SkeletonDriverChip extends StatelessWidget {
  const SkeletonDriverChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonBox(width: 56, height: 56, borderRadius: 28),
          SizedBox(height: 6),
          SkeletonBox(width: 40, height: 10, borderRadius: 3),
        ]));
  }
}

/// Skeleton for a team logo pill (used in the settings team picker).
class SkeletonTeamPill extends StatelessWidget {
  const SkeletonTeamPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: const SkeletonBox(width: 72, height: 52, borderRadius: 8));
  }
}
