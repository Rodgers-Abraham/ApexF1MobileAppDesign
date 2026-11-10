import 'package:flutter/material.dart';
import '../../../../core/providers/telemetry_provider.dart';

class FigmaSessionFlagBanner extends StatelessWidget {
  final RaceFlagStatus? status;

  const FigmaSessionFlagBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();

    Color bannerColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    if (status!.isRedFlag) {
      bannerColor = const Color(0xFFFF1744);
      textColor = Colors.white;
      icon = Icons.flag_rounded;
      title = 'RED FLAG — SESSION SUSPENDED';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Track blocked / hazardous condition. Return to pitlane.';
    } else if (status!.isSafetyCar) {
      bannerColor = const Color(0xFFFF9100);
      textColor = Colors.black;
      icon = Icons.warning_rounded;
      title = 'SAFETY CAR DEPLOYED (FULL SC)';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Reduce speed, maintain delta, no overtaking.';
    } else if (status!.isVsc) {
      bannerColor = const Color(0xFFFF9100);
      textColor = Colors.black;
      icon = Icons.speed_rounded;
      title = 'VIRTUAL SAFETY CAR (VSC)';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Observe positive delta. Pit lane speed limit applies.';
    } else if (status!.isYellowFlag) {
      bannerColor = const Color(0xFFFFD600);
      textColor = Colors.black;
      icon = Icons.flag_rounded;
      title = status!.flag == 'DOUBLE_YELLOW' ? 'DOUBLE YELLOW FLAG — HAZARD' : 'YELLOW FLAG — CAUTION';
      subtitle = status!.message.isNotEmpty ? status!.message : 'Caution in sector.';
    } else {
      bannerColor = const Color(0xFF00E676);
      textColor = Colors.black;
      icon = Icons.check_circle_rounded;
      title = 'TRACK CLEAR — GREEN FLAG';
      subtitle = 'DRS Enabled • Full Racing Conditions';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bannerColor.withValues(alpha: 0.7), width: 1.2)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: bannerColor, shape: BoxShape.circle),
            child: Icon(icon, color: textColor, size: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle( fontSize: 10, fontWeight: FontWeight.w900, color: bannerColor, letterSpacing: 0.5)),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
        ]));
  }
}
