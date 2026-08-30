import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standardized avatar for child or parent with initials or icon.
class AppAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isChild;
  final bool isSelected;

  const AppAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.radius = 22.0,
    this.backgroundColor,
    this.textColor,
    this.isChild = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ??
        (isChild
            ? AppColors.childPrimary.withAlpha((0.15 * 255).round())
            : AppColors.parentPrimary.withAlpha((0.15 * 255).round()));

    final effectiveFg = textColor ?? (isChild ? AppColors.childPrimary : AppColors.parentPrimary);

    String initial = '?';
    if (name != null && name!.trim().isNotEmpty) {
      initial = name!.trim().substring(0, 1).toUpperCase();
    }

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: effectiveBg,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w800,
          color: effectiveFg,
        ),
      ),
    );

    if (isSelected) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isChild ? AppColors.childPrimary : AppColors.parentPrimary,
            width: 2.0,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
