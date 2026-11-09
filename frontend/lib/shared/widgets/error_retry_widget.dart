import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

/// Reusable error state with a retry button.
class ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final double height;
  final IconData icon;

  const ErrorRetryWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.height = 160,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 28),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppFonts.regular(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 13, color: Colors.white54),
                      const SizedBox(width: 5),
                      Text('RETRY', style: AppFonts.wide(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline error banner with optional retry.
class InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0808),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontFamily: 'Formula1', fontSize: 10, color: Colors.red.shade300)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text('RETRY', style: AppFonts.wide(fontSize: 8, color: Colors.red.shade400, fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Top banner shown when the backend server is unreachable.
class BackendOfflineBanner extends StatelessWidget {
  const BackendOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A0A00),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 12, color: Color(0xFFFF9800)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Backend offline — some features unavailable. Showing cached data.',
              style: AppFonts.regular(fontSize: 9.5, color: const Color(0xFFFF9800)),
            ),
          ),
        ],
      ),
    );
  }
}
