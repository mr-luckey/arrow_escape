import 'package:flutter/material.dart';

abstract final class Breakpoints {
  static const double phone = 600;
  static const double tablet = 900;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phone;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= phone;

  static double boardMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= tablet) return 560;
    if (w >= phone) return 480;
    return w - 32;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= tablet
        ? 48.0
        : w >= phone
            ? 32.0
            : 20.0;
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  static double clampFont(BuildContext context, double size) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return (size * scale.clamp(0.9, 1.2)).clamp(12, 56);
  }
}
