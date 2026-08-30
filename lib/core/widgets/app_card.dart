import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum AppCardVariant { elevated, outlined, flat }

/// Consistent, accessible surface card widget for ClearTime.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final AppCardVariant variant;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin = const EdgeInsets.only(bottom: 12.0),
    this.onTap,
    this.variant = AppCardVariant.outlined,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = BorderRadius.circular(borderRadius ?? AppRadius.lg);
    final effectiveBg = backgroundColor ?? Colors.white;
    final effectiveBorderColor = borderColor ?? AppColors.neutralBorder;

    List<BoxShadow>? shadows;
    if (variant == AppCardVariant.elevated) {
      shadows = [
        BoxShadow(
          color: Colors.black.withAlpha((0.04 * 255).round()),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }

    final decoration = BoxDecoration(
      color: effectiveBg,
      borderRadius: effectiveBorderRadius,
      border: variant == AppCardVariant.flat
          ? null
          : Border.all(
              color: effectiveBorderColor,
              width: borderWidth ?? 1.0,
            ),
      boxShadow: shadows,
    );

    Widget content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: effectiveBorderRadius,
        child: InkWell(
          borderRadius: effectiveBorderRadius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: content,
      );
    }

    return content;
  }
}
