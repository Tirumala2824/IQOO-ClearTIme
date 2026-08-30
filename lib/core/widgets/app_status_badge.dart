import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum AppStatusType { success, warning, error, info, neutral, primary }

/// Standardized status badge displaying icon + label + semantic background.
/// Follows accessibility guidelines (never relies on color alone).
class AppStatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AppStatusType type;
  final Color? customColor;
  final Color? customTextColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.type = AppStatusType.neutral,
    this.customColor,
    this.customTextColor,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
  });

  factory AppStatusBadge.success({required String label, IconData? icon}) {
    return AppStatusBadge(
      label: label,
      icon: icon ?? Icons.check_circle_rounded,
      type: AppStatusType.success,
    );
  }

  factory AppStatusBadge.warning({required String label, IconData? icon}) {
    return AppStatusBadge(
      label: label,
      icon: icon ?? Icons.hourglass_top_rounded,
      type: AppStatusType.warning,
    );
  }

  factory AppStatusBadge.error({required String label, IconData? icon}) {
    return AppStatusBadge(
      label: label,
      icon: icon ?? Icons.error_outline_rounded,
      type: AppStatusType.error,
    );
  }

  factory AppStatusBadge.info({required String label, IconData? icon}) {
    return AppStatusBadge(
      label: label,
      icon: icon ?? Icons.info_outline_rounded,
      type: AppStatusType.info,
    );
  }

  factory AppStatusBadge.primary({required String label, IconData? icon}) {
    return AppStatusBadge(
      label: label,
      icon: icon ?? Icons.bookmark_rounded,
      type: AppStatusType.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData defaultIcon;

    switch (type) {
      case AppStatusType.success:
        bg = AppColors.successGreen.withAlpha((0.12 * 255).round());
        fg = AppColors.successGreen;
        defaultIcon = Icons.check_circle_rounded;
        break;
      case AppStatusType.warning:
        bg = AppColors.warningOrange.withAlpha((0.12 * 255).round());
        fg = AppColors.warningOrange;
        defaultIcon = Icons.hourglass_top_rounded;
        break;
      case AppStatusType.error:
        bg = AppColors.errorRed.withAlpha((0.12 * 255).round());
        fg = AppColors.errorRed;
        defaultIcon = Icons.cancel_rounded;
        break;
      case AppStatusType.info:
        bg = AppColors.infoBlue.withAlpha((0.12 * 255).round());
        fg = AppColors.infoBlue;
        defaultIcon = Icons.info_outline_rounded;
        break;
      case AppStatusType.primary:
        bg = Theme.of(context).primaryColor.withAlpha((0.12 * 255).round());
        fg = Theme.of(context).primaryColor;
        defaultIcon = Icons.label_rounded;
        break;
      case AppStatusType.neutral:
        bg = AppColors.neutral100;
        fg = AppColors.neutral600;
        defaultIcon = Icons.circle;
        break;
    }

    final effectiveFg = customTextColor ?? fg;
    final effectiveBg = customColor ?? bg;
    final effectiveIcon = icon ?? defaultIcon;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(effectiveIcon, size: fontSize + 2, color: effectiveFg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: effectiveFg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
