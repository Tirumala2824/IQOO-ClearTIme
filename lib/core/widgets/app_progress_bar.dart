import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Smooth, rounded progress bar component.
class AppProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final String? label;
  final String? valueText;

  const AppProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.color,
    this.backgroundColor,
    this.label,
    this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = progress.clamp(0.0, 1.0);
    final effectiveColor = color ?? Theme.of(context).primaryColor;
    final effectiveBg = backgroundColor ?? AppColors.neutral200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || valueText != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Expanded(
                  child: Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (valueText != null) ...[
                if (label != null) const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    valueText!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.parentTextDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: effectiveProgress,
            minHeight: height,
            backgroundColor: effectiveBg,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
          ),
        ),
      ],
    );
  }
}
