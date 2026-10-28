/// Shared layout tokens for the Squadly V1.0 interface.
///
/// Keep these values aligned with `docs/ui-design/ui-design-spec.md` so
/// feature screens can share a stable visual rhythm without owning local
/// copies of common spacing and shape values.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double micro = 6;
  static const double xs = 8;
  static const double sm = 12;
  static const double sectionTop = 10;
  static const double md = 16;
  static const double mdLg = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
}

abstract final class AppRadii {
  static const double compact = 8;
  static const double control = 14;
  static const double card = 16;
  static const double dialog = 20;
  static const double sheet = 24;
  static const double pill = 999;
}

abstract final class AppSizes {
  static const double minimumTouchTarget = 48;
  static const double navigationBarHeight = 68;
}
