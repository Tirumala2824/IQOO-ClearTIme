import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum AppButtonVariant { primary, secondary, outlined, danger, ghost }
enum AppButtonSize { sm, md, lg }

/// Standardized, accessible button component for ClearTime.
/// Supports multiple visual variants, icon integration, loading spinners, and disabled states.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChild = theme.primaryColor == AppColors.childPrimary;
    final defaultPrimary = customColor ?? (isChild ? AppColors.childPrimary : AppColors.parentPrimary);
    final defaultSecondary = isChild ? AppColors.childSecondary : AppColors.parentSecondary;

    final double height;
    final EdgeInsets padding;
    final double fontSize;
    final double iconSize;

    switch (size) {
      case AppButtonSize.sm:
        height = 38.0;
        padding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0);
        fontSize = 13.0;
        iconSize = 16.0;
        break;
      case AppButtonSize.md:
        height = 48.0;
        padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0);
        fontSize = 15.0;
        iconSize = 18.0;
        break;
      case AppButtonSize.lg:
        height = 54.0;
        padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
        fontSize = 16.0;
        iconSize = 20.0;
        break;
    }

    Widget childContent;
    if (isLoading) {
      final spinnerColor = (variant == AppButtonVariant.primary ||
              variant == AppButtonVariant.secondary ||
              variant == AppButtonVariant.danger)
          ? Colors.white
          : defaultPrimary;
      childContent = Center(
        child: SizedBox(
          width: iconSize + 2,
          height: iconSize + 2,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
          ),
        ),
      );
    } else if (icon != null) {
      childContent = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    } else {
      childContent = Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    ButtonStyle style;
    switch (variant) {
      case AppButtonVariant.primary:
        style = ElevatedButton.styleFrom(
          backgroundColor: defaultPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        );
        break;
      case AppButtonVariant.secondary:
        style = ElevatedButton.styleFrom(
          backgroundColor: defaultSecondary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        );
        break;
      case AppButtonVariant.outlined:
        style = OutlinedButton.styleFrom(
          foregroundColor: defaultPrimary,
          side: BorderSide(color: defaultPrimary.withAlpha((0.5 * 255).round()), width: 1.5),
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        );
        break;
      case AppButtonVariant.danger:
        style = ElevatedButton.styleFrom(
          backgroundColor: AppColors.errorRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        );
        break;
      case AppButtonVariant.ghost:
        style = TextButton.styleFrom(
          foregroundColor: defaultPrimary,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        );
        break;
    }

    Widget button;
    final effectiveOnPressed = isLoading ? null : onPressed;

    if (variant == AppButtonVariant.outlined) {
      button = OutlinedButton(
        style: style,
        onPressed: effectiveOnPressed,
        child: childContent,
      );
    } else if (variant == AppButtonVariant.ghost) {
      button = TextButton(
        style: style,
        onPressed: effectiveOnPressed,
        child: childContent,
      );
    } else {
      button = ElevatedButton(
        style: style,
        onPressed: effectiveOnPressed,
        child: childContent,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height,
        minWidth: isFullWidth ? double.infinity : 0,
      ),
      child: isFullWidth ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
