import 'package:flutter/material.dart';
import '../../../../shared/theme/app_design_system.dart';

class RaceControlWidget extends StatefulWidget {
  final Color accent;
  const RaceControlWidget({super.key, required this.accent});

  @override
  State<RaceControlWidget> createState() => _RaceControlWidgetState();
}

class _RaceControlWidgetState extends State<RaceControlWidget> {
  String _selectedFlag = 'GREEN';

  @override
  Widget build(BuildContext context) {
    Color flagColor;
    String statusTitle;
    String statusSubtitle;

    switch (_selectedFlag) {
      case 'YELLOW':
        flagColor = const Color(0xFFFFD600);
        statusTitle = 'YELLOW FLAG';
        statusSubtitle = 'SECTOR 2 · DEBRIS AT TURN 9';
        break;
      case 'VSC':
        flagColor = const Color(0xFFFF9100);
        statusTitle = 'VIRTUAL SAFETY CAR';
        statusSubtitle = 'MAINTAIN POSITIVE DELTA · SPEED REDUCTION';
        break;
      case 'SC':
        flagColor = const Color(0xFFFF9100);
        statusTitle = 'SAFETY CAR DEPLOYED';
        statusSubtitle = 'TURN 4 INCIDENT · NO OVERTAKING';
        break;
      case 'RED':
        flagColor = const Color(0xFFFF1744);
        statusTitle = 'SESSION STOPPED';
        statusSubtitle = 'RED FLAG · RETURN TO PIT LANE';
        break;
      default:
        flagColor = const Color(0xFF00E676);
        statusTitle = 'TRACK CLEAR';
        statusSubtitle = 'GREEN FLAG · DRS ENABLED';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'RACE CONTROL',
                style: DS.driverCode(size: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('LIVE FEED', style: DS.labelCaps(size: 9, color: DS.textMuted)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: DS.surface1,
            borderRadius: DS.aeroCorner,
            border: Border.all(color: flagColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: flagColor, borderRadius: BorderRadius.circular(2)),
              ),
              Icon(Icons.warning_amber_rounded, color: flagColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusTitle, style: DS.headline(size: 11, color: flagColor)),
                    const SizedBox(height: 2),
                    Text(statusSubtitle, style: DS.labelCaps(size: 9, color: DS.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.flag_rounded, color: flagColor, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: ['GREEN', 'YELLOW', 'VSC', 'SC', 'RED'].map((f) {
            final isSelected = _selectedFlag == f;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedFlag = f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isSelected ? Colors.white : DS.outline, width: isSelected ? 1.2 : 1.0),
                  ),
                  child: Center(
                    child: Text(f, style: DS.labelCaps(size: 8.5, color: isSelected ? Colors.white : DS.textMuted)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
