import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apex F1 Design System — Stitch/Precision Telemetry edition.
/// Surfaces, colors, typography, and shape helpers aligned with DESIGN.md.
class DS {
  DS._();

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF131317);
  static const Color surface0 = Color(0xFF0E0E12);
  static const Color surface1 = Color(0xFF1B1B1F);
  static const Color surface2 = Color(0xFF1F1F23);
  static const Color surface3 = Color(0xFF2A292E);
  static const Color surface4 = Color(0xFF353439);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE4E1E7);
  static const Color textVariant = Color(0xFFE9BCB5);
  static const Color textMuted = Color(0xFFAF8781);

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color red = Color(0xFFE10600);
  static const Color redText = Color(0xFFFFF2F0);
  static const Color orange = Color(0xFFFF8000);
  static const Color teal = Color(0xFF29DEC9);
  static const Color tealDark = Color(0xFF007E72);

  // ── Timing semantics ───────────────────────────────────────────────────────
  static const Color purple = Color(0xFFB038FF);
  static const Color green = Color(0xFF00E064);
  static const Color yellow = Color(0xFFFFD000);

  // ── Border ─────────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF272732);
  static const Color outlineVariant = Color(0xFF5E3F3A);

  // ── Shapes ─────────────────────────────────────────────────────────────────
  /// Aero-cut asymmetric corner: TL+BR rounded, TR+BL sharp.
  static const BorderRadius aeroCornerSm = BorderRadius.only(
    topLeft: Radius.circular(4),
    bottomRight: Radius.circular(4),
  );
  static const BorderRadius aeroCorner = BorderRadius.only(
    topLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius aeroCornerLg = BorderRadius.only(
    topLeft: Radius.circular(12),
    bottomRight: Radius.circular(12),
  );

  // ── Typography ─────────────────────────────────────────────────────────────
  static TextStyle display({double size = 28, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * -0.02,
        color: color ?? textPrimary,
      );

  static TextStyle headline({double size = 18, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.01,
        color: color ?? textPrimary,
      );

  static TextStyle headlineMd({double size = 15, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.01,
        color: color ?? textPrimary,
      );

  static TextStyle driverCode({double size = 14, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.06,
        color: color ?? textPrimary,
      );

  static TextStyle telemetry({double size = 13, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: color ?? textPrimary,
      );

  static TextStyle telemetryLg({double size = 18, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * -0.02,
        color: color ?? textPrimary,
      );

  static TextStyle labelCaps({double size = 9, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.08,
        color: color ?? textMuted,
      );

  static TextStyle body({double size = 13, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: size * 0.01,
        color: color ?? textVariant,
      );

  static TextStyle bodySm({double size = 11, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: size * 0.01,
        color: color ?? textVariant,
      );
}

/// Reusable DS widget helpers.
class DSWidgets {
  DSWidgets._();

  /// Card with 3px left accent bar, aero corners, surface2 background.
  static Widget leftAccentCard({
    required Color accent,
    required Widget child,
    BorderRadius? radius,
    Color? bgColor,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? DS.surface2,
        borderRadius: radius ?? DS.aeroCorner,
        border: Border.all(color: DS.outline, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.zero,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: padding ?? const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  /// Small all-caps JetBrains Mono label.
  static Widget labelCapsText(String text, {Color? color, double size = 9}) =>
      Text(text.toUpperCase(), style: DS.labelCaps(size: size, color: color));

  /// Red badge (e.g. "F1" pill).
  static Widget redBadge(String text, {double size = 9}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: DS.red,
          borderRadius: DS.aeroCornerSm,
        ),
        child: Text(
          text,
          style: DS.labelCaps(size: size, color: DS.redText),
        ),
      );

  /// Status chip with optional color.
  static Widget statusChip(String text, {Color? color, double size = 9}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (color ?? DS.teal).withValues(alpha: 0.15),
          borderRadius: DS.aeroCornerSm,
          border: Border.all(
            color: (color ?? DS.teal).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: DS.labelCaps(size: size, color: color ?? DS.teal),
        ),
      );

  /// Custom input field with mono label, aero corners, underline baseline.
  static Widget inputField({
    required String label,
    String? rightLabel,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixWidget,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Color? underlineColor,
    void Function(String)? onChanged,
  }) {
    return _DSInputField(
      label: label,
      rightLabel: rightLabel,
      controller: controller,
      isPassword: isPassword,
      obscureText: obscureText,
      onToggleObscure: onToggleObscure,
      hint: hint,
      prefixIcon: prefixIcon,
      suffixWidget: suffixWidget,
      keyboardType: keyboardType,
      validator: validator,
      underlineColor: underlineColor ?? DS.red,
      onChanged: onChanged,
    );
  }
}

class _DSInputField extends StatelessWidget {
  final String label;
  final String? rightLabel;
  final TextEditingController controller;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Color underlineColor;
  final void Function(String)? onChanged;

  const _DSInputField({
    required this.label,
    this.rightLabel,
    required this.controller,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.hint,
    this.prefixIcon,
    this.suffixWidget,
    this.keyboardType,
    this.validator,
    required this.underlineColor,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(), style: DS.labelCaps(size: 9)),
            if (rightLabel != null)
              Text(rightLabel!,
                  style: DS.telemetry(size: 9, color: DS.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: DS.surface2,
            borderRadius: DS.aeroCorner,
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && obscureText,
            keyboardType: keyboardType,
            validator: validator,
            onChanged: onChanged,
            style: DS.telemetry(size: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: DS.telemetry(size: 13, color: DS.textMuted),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: DS.textMuted, size: 18)
                  : null,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: DS.textMuted,
                        size: 18,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : suffixWidget,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              errorStyle: DS.bodySm(size: 10, color: DS.red),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: DS.surface4,
            borderRadius: BorderRadius.circular(1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.3,
            child: Container(
              decoration: BoxDecoration(
                color: underlineColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
