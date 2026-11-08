import 'package:flutter/material.dart';
import '../../../../shared/constants/f1_data.dart';

class FigmaTelemetryStrip extends StatelessWidget {
  final String driverName;
  final String driverCode;
  final String speedKph;
  final String gear;
  final String throttlePct;
  final String ersPct;
  final bool isDnf;

  const FigmaTelemetryStrip({
    super.key,
    required this.driverName,
    required this.driverCode,
    required this.speedKph,
    required this.gear,
    required this.throttlePct,
    required this.ersPct,
    this.isDnf = false,
  });

  @override
  Widget build(BuildContext context) {
    final driverMeta = getDriverData(driverCode);
    final teamColor = getTeamColor(driverMeta?.team ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202028)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF222228),
              border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: driverMeta != null && driverMeta.portraitAsset.isNotEmpty
                ? Image.asset(
                    driverMeta.portraitAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(driverCode, style: TextStyle(fontFamily: 'Formula1', fontSize: 8, fontWeight: FontWeight.w900, color: teamColor)),
                    ),
                  )
                : Center(child: Text(driverCode, style: TextStyle(fontFamily: 'Formula1', fontSize: 8, fontWeight: FontWeight.w900, color: teamColor))),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ONBOARD', style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 7, color: Color(0xFF8F909A), fontWeight: FontWeight.bold)),
              Text(driverCode, style: const TextStyle(fontFamily: 'Formula1', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCol(isDnf ? '0' : speedKph, 'KM/H', const Color(0xFF00E676)),
                _buildStatCol(isDnf ? 'N' : gear, 'GEAR', Colors.white),
                _buildStatCol(isDnf ? '0%' : '$throttlePct%', 'THR %', const Color(0xFFFFD600)),
                _buildStatCol('$ersPct%', 'ERS %', const Color(0xFF00E5FF)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String value, String label, Color valueColor) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontFamily: 'Formula1Wide', fontSize: 11, fontWeight: FontWeight.w900, color: valueColor))),
          const SizedBox(height: 1),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontFamily: 'Formula1', fontSize: 7, color: Color(0xFF8F909A), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
