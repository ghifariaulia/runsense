import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0A0A);
  static const foreground = Color(0xFFFAFAFA);
  static const muted = Color(0xFF737373);
  static const border = Color(0xFF262626);
  static const surface = Color(0xFF101010);
  static const accent = Color(0xFFFF3D00);
}

class KickerStyle {
  static const text = TextStyle(
    color: AppColors.accent,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
  );
}
