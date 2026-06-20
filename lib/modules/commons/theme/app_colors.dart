import 'package:flutter/material.dart';

/// Coastal Pulse — the brand palette defined in the brand spec §4.
///
/// All raw hex lives here. Widget code reads colors via the
/// `context.<token>` extension in `context_theme.dart` — never via raw
/// hex (brand anti-pattern §12.3).
///
/// **Backwards-compatibility note.** The original token names (`accent`,
/// `blue`, `amber`) are preserved so the rest of the app keeps compiling
/// during the brand sweep; their *hex values* now resolve to Coastal
/// Pulse equivalents:
///
///   - `accent` → coral  (#EE6F4A)
///   - `blue`   → teal   (#236767)
///   - `amber`  → butter (#F1B940)
///
/// New code should prefer the explicit brand-named getters
/// (`context.coral`, `context.teal`, `context.butter`) which are aliases
/// on the same underlying tokens.
class AppColors {
  AppColors._();

  // ── Coastal Pulse — the five brand tokens ────────────────────────────
  /// Hero / motion / live state. Primary CTA fill, pickup pin, the
  /// coral dot in the wordmark.
  static const Color coral = Color(0xFFEE6F4A);

  /// Depth / drop-off / quiet supporting accent. Saved-places icons.
  static const Color teal = Color(0xFF236767);

  /// Sparing accent — peak hour, "new", micro-callouts. One per screen.
  static const Color butter = Color(0xFFF1B940);

  /// Anchor. Default text in light mode; default background in dark mode.
  static const Color charcoalTeal = Color(0xFF0E2E2E);

  /// Breathing space. Default light-mode background; ink-on-coral.
  static const Color ivory = Color(0xFFF4ECE0);

  // Ink companions — what you write on top of a brand color.
  static const Color coralInk = ivory;
  static const Color tealInk = ivory;
  static const Color butterInk = charcoalTeal;
  static const Color charcoalInk = ivory;

  // ── Foundation — light mode lives on ivory ──────────────────────────
  static const Color bgLight = ivory;
  static const Color surfaceLight = Color(0xFFFBF7EE);
  static const Color surface2Light = Color(0xFFEFE7D8);
  static const Color surface3Light = Color(0xFFE4DBC9);
  static const Color surface4Light = Color(0xFFD9D0BD);
  // 8% charcoal-teal on ivory — hairline borders.
  static const Color borderLight = Color(0x140E2E2E);
  // 14% charcoal-teal — grouped-list dividers, strong borders.
  static const Color borderStrongLight = Color(0x240E2E2E);
  static const Color textLight = charcoalTeal;
  static const Color textDimLight = Color(0xA50E2E2E); // 65%
  static const Color textMutedLight = Color(0x730E2E2E); // 45%

  // ── Foundation — dark mode lives on charcoal-teal ───────────────────
  static const Color bgDark = charcoalTeal;
  static const Color surfaceDark = Color(0xFF16383A);
  static const Color surface2Dark = Color(0xFF1B4244);
  static const Color surface3Dark = Color(0xFF214E50);
  static const Color surface4Dark = Color(0xFF275A5C);
  // 10% ivory on charcoal — hairline.
  static const Color borderDark = Color(0x1AF4ECE0);
  // 18% ivory.
  static const Color borderStrongDark = Color(0x2EF4ECE0);
  static const Color textDark = ivory;
  static const Color textDimDark = Color(0xB8F4ECE0); // 72%
  static const Color textMutedDark = Color(0x7AF4ECE0); // 48%

  // ── Semantic — accent / blue / amber keep their NAMES, get NEW HEX ──
  // (rest of the app reads context.accent etc.; they now resolve to
  // Coastal Pulse).

  // accent = coral on both modes (brand color reads on both bases).
  static const Color accentLight = coral;
  static const Color accentInkLight = coralInk;
  static const Color accentDimLight = Color(0xFFD25A36); // pressed coral
  static const Color accentDark = coral;
  static const Color accentInkDark = coralInk;
  static const Color accentDimDark = Color(0xFFD25A36);

  // blue = teal (calm sibling to coral).
  static const Color blueLight = teal;
  static const Color blueInkLight = tealInk;
  static const Color blueDark = teal;
  static const Color blueInkDark = tealInk;

  // amber = butter (sparing peak accent).
  static const Color amberLight = butter;
  static const Color amberInkLight = butterInk;
  static const Color amberDark = butter;
  static const Color amberInkDark = butterInk;

  // Semantic red per spec §4.2.
  static const Color redLight = Color(0xFFCC3D2F);
  static const Color redInkLight = ivory;
  static const Color redDark = Color(0xFFFF6657);
  static const Color redInkDark = charcoalTeal;

  // Success — used for positive feedback toasts, completed states.
  static const Color successLight = Color(0xFF1F7A4E);
  static const Color successDark = Color(0xFF5AC287);

  // ── Map palette per §4.5 ────────────────────────────────────────────
  static const Color mapBgLight = Color(0xFFEAE2D2);
  static const Color mapRoadLight = Color(0xFFFBF7EE);
  static const Color mapRoadMajorLight = ivory;
  static const Color mapWaterLight = Color(0xFFCFE0DC);
  static const Color mapParkLight = Color(0xFFD9DDC4);

  static const Color mapBgDark = Color(0xFF1A3F40);
  static const Color mapRoadDark = Color(0xFF2A5557);
  static const Color mapRoadMajorDark = Color(0xFF356668);
  static const Color mapWaterDark = Color(0xFF10262C);
  static const Color mapParkDark = Color(0xFF1F3A2C);

  // ── Misc ────────────────────────────────────────────────────────────
  /// One step darker than bg — splash atmospherics, full-bleed hero
  /// backgrounds where bg would feel too flat.
  static const Color appBackdropLight = Color(0xFFEDE3D2);
  static const Color appBackdropDark = Color(0xFF071919);

  /// Bezel for in-app device mockups (admin previews, etc.). Not the
  /// real OS bezel — we never fake iOS chrome (anti-pattern §12.5).
  static const Color phoneBezel = Color(0xFF0A2222);

  static Color withAlpha(Color color, double alpha) =>
      color.withValues(alpha: alpha);
}
