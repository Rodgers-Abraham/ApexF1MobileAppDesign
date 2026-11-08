import 'dart:math';
import 'package:flutter/material.dart';

class FigmaRadioCard extends StatelessWidget {
  final String id;
  final String driverName;
  final String teamName;
  final String timestamp;
  final String transcript;
  final Color teamColor;
  final String portraitAsset;
  final bool isPlaying;
  final double progressRatio;
  final String elapsedStr;
  final Animation<double> anim;
  final VoidCallback onTogglePlay;

  const FigmaRadioCard({
    super.key,
    required this.id,
    required this.driverName,
    required this.teamName,
    required this.timestamp,
    required this.transcript,
    required this.teamColor,
    required this.portraitAsset,
    required this.isPlaying,
    required this.progressRatio,
    required this.elapsedStr,
    required this.anim,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPlaying ? teamColor.withValues(alpha: 0.6) : const Color(0xFF202028)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3.5, height: 28, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: teamColor, borderRadius: BorderRadius.circular(1.5))),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF222228), border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1.2)),
                clipBehavior: Clip.antiAlias,
                child: portraitAsset.isNotEmpty
                    ? Image.asset(portraitAsset, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (context, error, stackTrace) => const SizedBox())
                    : const SizedBox(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(timestamp.toUpperCase(), style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 8, color: Color(0xFF8F909A), fontWeight: FontWeight.bold)),
                    Text(driverName, style: const TextStyle(fontFamily: 'Formula1', fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text(teamName, style: TextStyle(fontFamily: 'Formula1', fontSize: 8.5, color: teamColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTogglePlay,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: isPlaying ? teamColor : Colors.white12, shape: BoxShape.circle),
                  child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: isPlaying ? Colors.black : Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: anim,
            builder: (context, child) {
              return Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(36, (index) {
                    final baseHeight = 6.0 + ((index * 13) % 20);
                    final oscillation = isPlaying ? sin(anim.value * pi + index * 0.3) * 6 : 0;
                    final h = (baseHeight + oscillation).clamp(4.0, 26.0);
                    final isPassed = isPlaying && (index / 36.0) <= progressRatio;

                    return Container(
                      width: 2.5,
                      height: h,
                      decoration: BoxDecoration(
                        color: isPassed ? teamColor : (isPlaying ? teamColor.withValues(alpha: 0.4) : Colors.white24),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(6)),
            child: Text('"$transcript"', style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontStyle: FontStyle.italic, height: 1.3)),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(elapsedStr, style: const TextStyle(fontFamily: 'Formula1Wide', fontSize: 8, color: Color(0xFF8F909A), fontWeight: FontWeight.bold)),
              if (isPlaying) Text('AUDIO PLAYING', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 7.5, fontWeight: FontWeight.w900, color: teamColor)),
            ],
          ),
        ],
      ),
    );
  }
}
