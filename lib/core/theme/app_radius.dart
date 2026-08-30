import 'package:flutter/material.dart';

/// Centralized corner radius tokens.
class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 18.0;
  static const double xl = 22.0;
  static const double xxl = 28.0;
  static const double pill = 999.0;

  static final BorderRadius rSm = BorderRadius.circular(sm);
  static final BorderRadius rMd = BorderRadius.circular(md);
  static final BorderRadius rLg = BorderRadius.circular(lg);
  static final BorderRadius rXl = BorderRadius.circular(xl);
  static final BorderRadius rXxl = BorderRadius.circular(xxl);
  static final BorderRadius rPill = BorderRadius.circular(pill);
}
