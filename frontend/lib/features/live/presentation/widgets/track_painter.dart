import 'package:flutter/material.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../data/track_database.dart';

class TrackPainter extends CustomPainter {
  final Color accentColor;
  final List<LiveTelemetry> drivers;
  final String meetingName;
  final String selectedDriverCode;
  final bool isLive;

  TrackPainter(
    this.accentColor,
    this.drivers,
    this.meetingName, {
    required this.selectedDriverCode,
    this.isLive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final circuit = findCircuitByName(meetingName) ?? circuitSingapore;
    final points = circuit.trackPoints.isNotEmpty ? circuit.trackPoints : circuitSingapore.trackPoints;

    if (points.isNotEmpty) {
      final sf = Offset(points.first.dx * size.width, points.first.dy * size.height);
      _drawBadge(canvas, sf, 'S/F', Colors.white, Colors.black);

      if (points.length >= 7) {
        final s1 = Offset(points[2].dx * size.width, points[2].dy * size.height);
        _drawBadge(canvas, s1, 'S1', const Color(0xFFFFD600), Colors.black);

        final s2 = Offset(points[5].dx * size.width, points[5].dy * size.height);
        _drawBadge(canvas, s2, 'S2', const Color(0xFF00E5FF), Colors.black);

        final s3 = Offset(points[points.length - 2].dx * size.width, points[points.length - 2].dy * size.height);
        _drawBadge(canvas, s3, 'S3', const Color(0xFFB388FF), Colors.black);
      }

      if (points.length >= 9) {
        final drs = Offset(points[points.length - 4].dx * size.width, points[points.length - 4].dy * size.height);
        _drawBadge(canvas, drs, 'DRS', const Color(0xFF00E676), Colors.black);
      }

      LiveTelemetry? targetDriver;
      int driverIndex = 0;
      for (int i = 0; i < drivers.length; i++) {
        final d = drivers[i];
        final code = (getDriverData(d.name)?.code ?? d.name.split(' ').last.substring(0, 3)).toUpperCase();
        if (code == selectedDriverCode || d.name.toUpperCase().contains(selectedDriverCode.toUpperCase())) {
          targetDriver = d;
          driverIndex = i;
          break;
        }
      }

      final meta = getDriverData(selectedDriverCode);
      Color teamColor = getTeamColor(meta?.team ?? '');
      if (targetDriver != null) {
        try {
          final hex = targetDriver.color.replaceAll('#', '');
          teamColor = Color(int.parse('FF$hex', radix: 16));
        } catch (_) {}
      }

      final posStr = targetDriver?.pos.isNotEmpty == true ? targetDriver!.pos : '${driverIndex + 1}';
      final ptIndex = ((driverIndex * 3) + 2) % points.length;
      final carPoint = Offset(points[ptIndex].dx * size.width, points[ptIndex].dy * size.height);

      _drawSingleFocusedDriver(canvas, carPoint, 'P$posStr $selectedDriverCode', teamColor);
    }
  }

  void _drawBadge(Canvas canvas, Offset pos, String text, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle( fontSize: 7, fontWeight: FontWeight.w900, color: fg)),
      textDirection: TextDirection.ltr)..layout();

    final rrect = RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: tp.width + 8, height: tp.height + 4), const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = bg);
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawSingleFocusedDriver(Canvas canvas, Offset pos, String text, Color color) {
    canvas.drawCircle(pos, 16, Paint()..color = color.withValues(alpha: 0.22)..style = PaintingStyle.fill);
    canvas.drawCircle(pos, 9, Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    canvas.drawCircle(pos, 4.5, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(pos, 4.5, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0);

    final isNearTop = pos.dy < 45;
    final pillOffset = Offset(0, isNearTop ? 22 : -22);
    final badgeCenter = pos + pillOffset;

    canvas.drawLine(pos + Offset(0, isNearTop ? 6 : -6), badgeCenter + Offset(0, isNearTop ? -10 : 10), Paint()..color = color.withValues(alpha: 0.8)..strokeWidth = 1.2);

    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle( fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white)),
      textDirection: TextDirection.ltr)..layout();

    final rrect = RRect.fromRectAndRadius(Rect.fromCenter(center: badgeCenter, width: tp.width + 16, height: tp.height + 7), const Radius.circular(5));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF141419));
    canvas.drawRRect(rrect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4);

    final leftBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeCenter.dx - (tp.width + 16) / 2, badgeCenter.dy - (tp.height + 7) / 2, 3.5, tp.height + 7),
      const Radius.circular(1.5));
    canvas.drawRRect(leftBar, Paint()..color = color);
    tp.paint(canvas, badgeCenter - Offset(tp.width / 2 - 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant TrackPainter oldDelegate) =>
      oldDelegate.selectedDriverCode != selectedDriverCode || oldDelegate.drivers != drivers;
}
