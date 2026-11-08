import 'package:flutter/material.dart';

class FigmaTimingRowWidget extends StatelessWidget {
  final String pos;
  final String code;
  final String name;
  final String team;
  final int driverNumber;
  final String gap;
  final String interval;
  final int positionsGained;
  final String status;
  final String dnfReason;
  final String tyre;
  final String tyreLife;
  final int pitStops;
  final String lastLap;
  final bool isFastestLap;
  final bool drs;
  final Color teamColor;
  final bool isSelected;
  final String portraitAsset;
  final VoidCallback onTap;

  const FigmaTimingRowWidget({
    super.key,
    required this.pos,
    required this.code,
    required this.name,
    required this.team,
    required this.driverNumber,
    required this.gap,
    required this.interval,
    required this.positionsGained,
    required this.status,
    required this.dnfReason,
    required this.tyre,
    required this.tyreLife,
    required this.pitStops,
    required this.lastLap,
    required this.isFastestLap,
    required this.drs,
    required this.teamColor,
    required this.isSelected,
    required this.portraitAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDnf = status == 'DNF' || status == 'RETIRED';
    final isPit = status == 'PIT';

    Color tyreColor = Colors.white;
    if (tyre == 'S') tyreColor = const Color(0xFFFF1744);
    if (tyre == 'M') tyreColor = const Color(0xFFFFD600);
    if (tyre == 'H') tyreColor = Colors.white;
    if (tyre == 'I') tyreColor = const Color(0xFF00E676);
    if (tyre == 'W') tyreColor = const Color(0xFF00B0FF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isDnf
              ? const Color(0xFF1E1012)
              : isSelected
                  ? Color.lerp(teamColor.withValues(alpha: 0.12), const Color(0xFF141419), 0.7)
                  : const Color(0xFF141419),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(7),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(7),
          ),
          border: Border.all(
            color: isSelected ? teamColor.withValues(alpha: 0.7) : const Color(0xFF202028),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3.0,
              height: 20,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(color: teamColor, borderRadius: BorderRadius.circular(1.5)),
            ),
            SizedBox(
              width: 24,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(pos, style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 11, fontWeight: FontWeight.w900, color: isDnf ? const Color(0xFFFF5252) : Colors.white)),
                  ),
                  const SizedBox(height: 1),
                  if (!isDnf)
                    if (positionsGained > 0)
                      FittedBox(fit: BoxFit.scaleDown, child: Text('▲$positionsGained', style: const TextStyle(fontFamily: 'Formula1', color: Color(0xFF00E676), fontSize: 7, fontWeight: FontWeight.bold)))
                    else if (positionsGained < 0)
                      FittedBox(fit: BoxFit.scaleDown, child: Text('▼${positionsGained.abs()}', style: const TextStyle(fontFamily: 'Formula1', color: Color(0xFFFF5252), fontSize: 7, fontWeight: FontWeight.bold)))
                    else
                      const Text('—', style: TextStyle(color: Colors.grey, fontSize: 7)),
                ],
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222228),
                border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: portraitAsset.isNotEmpty
                  ? Image.asset(portraitAsset, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (context, error, stackTrace) => Center(child: Text(code, style: TextStyle(fontFamily: 'Formula1', fontSize: 8, fontWeight: FontWeight.w900, color: teamColor))))
                  : Center(child: Text(code, style: TextStyle(fontFamily: 'Formula1', fontSize: 8, fontWeight: FontWeight.w900, color: teamColor))),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Text(code, style: const TextStyle(fontFamily: 'Formula1', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(width: 3),
                    Text('#$driverNumber', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 7.5, color: teamColor, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 1),
                  Text(team, style: const TextStyle(fontFamily: 'Formula1', fontSize: 8, color: Color(0xFF8F909A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDnf)
                    const FittedBox(fit: BoxFit.scaleDown, child: Text('OUT', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFF1744))))
                  else if (isPit)
                    const FittedBox(fit: BoxFit.scaleDown, child: Text('IN PIT', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFF9100))))
                  else
                    FittedBox(fit: BoxFit.scaleDown, child: Text(gap, style: TextStyle(fontFamily: 'Formula1', fontSize: 9.5, fontWeight: FontWeight.w900, color: gap == 'LEADER' ? const Color(0xFF00E676) : Colors.white), maxLines: 1)),
                  const SizedBox(height: 1),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(isDnf ? (dnfReason.isNotEmpty ? dnfReason : 'CRASH') : isPit ? 'STOP $pitStops' : 'INT $interval', style: const TextStyle(fontFamily: 'Formula1', fontSize: 7.5, color: Color(0xFF8F909A)), maxLines: 1)),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (drs && !isDnf) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.5), border: Border.all(color: const Color(0xFF00E676), width: 0.8)),
                    child: const Text('DRS', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 6, fontWeight: FontWeight.w900, color: Color(0xFF00E676))),
                  ),
                  const SizedBox(width: 3),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                  decoration: BoxDecoration(color: tyreColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2.5), border: Border.all(color: tyreColor, width: 0.9)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tyre, style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 8, fontWeight: FontWeight.w900, color: tyreColor)),
                      const SizedBox(width: 2),
                      Text(tyreLife.replaceAll(' laps', '').replaceAll('L', ''), style: TextStyle(fontFamily: 'Formula1', fontSize: 7, fontWeight: FontWeight.bold, color: tyreColor.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 5),
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(lastLap, style: TextStyle(fontFamily: 'Formula1', fontSize: 9, fontWeight: FontWeight.w900, color: isFastestLap ? const Color(0xFFB388FF) : Colors.white), maxLines: 1)),
                  const SizedBox(height: 1),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(isFastestLap ? 'FASTEST' : 'LAST LAP', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 6, fontWeight: FontWeight.bold, color: isFastestLap ? const Color(0xFFB388FF) : const Color(0xFF5F606B)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
