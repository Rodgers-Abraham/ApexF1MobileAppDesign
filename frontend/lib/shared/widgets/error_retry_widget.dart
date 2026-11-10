import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';

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
            Icon(icon, color: DS.textMuted, size: 28),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: DS.body(size: 11, color: DS.textMuted),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: DS.surface2,
                    borderRadius: DS.aeroCornerSm,
                    border: Border.all(color: DS.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 13, color: DS.textMuted),
                      const SizedBox(width: 5),
                      Text('RETRY', style: DS.labelCaps(size: 9, color: DS.textMuted)),
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
        color: DS.red.withValues(alpha: 0.08),
        borderRadius: DS.aeroCornerSm,
        border: Border.all(color: DS.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: DS.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: DS.body(size: 10, color: DS.red)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text('RETRY', style: DS.labelCaps(size: 8, color: DS.red)),
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
      color: DS.orange.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 12, color: DS.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Backend offline — some features unavailable. Showing cached data.',
              style: DS.labelCaps(size: 9, color: DS.orange),
            ),
          ),
        ],
      ),
    );
  }
}
