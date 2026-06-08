import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Drivio type scale per brand spec §5.3.
///
/// Two faces:
///   - **Marcellus** (serif): wordmark, display, headlines. Roman-inscriptional
///     classical refinement — what Drivio "speaks" with.
///   - **Albert Sans** (humanist sans): UI body, buttons, captions,
///     micro-copy. The information layer.
///
/// Loaded via `google_fonts` at runtime — no asset bundling. The styles
/// are static finals (not const) because `GoogleFonts` returns a
/// `TextStyle` whose family resolves on first paint.
///
/// Reference these tokens. Never compose `TextStyle` inline in widgets
/// (brand anti-pattern §13.3).
class AppTextStyles {
  AppTextStyles._();

  /// Kept for backwards compatibility — old callers passing
  /// `AppTextStyles.fontFamily` get the Albert Sans family name. New
  /// code should reference the style tokens below, not the family name.
  static const String fontFamily = 'AlbertSans';

  // ── Marcellus — display + headlines (the brand voice) ───────────────

  /// 56 / 400 / 1.05 / -1.0px. Splash hero, marketing hero.
  static final TextStyle displayXl = GoogleFonts.marcellus(
    fontSize: 56,
    fontWeight: FontWeight.w400,
    height: 1.05,
    letterSpacing: -1.0,
  );

  /// 40 / 400 / 1.1 / -0.6px. Welcome, app-store hero.
  static final TextStyle displayLg = GoogleFonts.marcellus(
    fontSize: 40,
    fontWeight: FontWeight.w400,
    height: 1.1,
    letterSpacing: -0.6,
  );

  /// 28 / 400 / 1.15 / -0.4px. Top-of-screen titles, sheet titles.
  static final TextStyle screenTitle = GoogleFonts.marcellus(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.15,
    letterSpacing: -0.4,
  );

  /// 24 / 400 / 1.2 / -0.4px. Smaller screen title — when 28 feels heavy.
  static final TextStyle screenTitleSm = GoogleFonts.marcellus(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// 22 / 400 / 1.2 / -0.3px. Section headings.
  static final TextStyle h1 = GoogleFonts.marcellus(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// 18 / 400 / 1.25 / -0.2px. Card titles.
  static final TextStyle h2 = GoogleFonts.marcellus(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.25,
    letterSpacing: -0.2,
  );

  // ── Albert Sans — UI body, the information layer ────────────────────

  /// 16 / 600 / 1.3 / -0.1px. List row primary text — sans, for
  /// tabular density per spec §5.4.
  static final TextStyle h3 = GoogleFonts.albertSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// 16 / 400 / 1.5. Long-form body.
  static final TextStyle bodyLg = GoogleFonts.albertSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 15 / 400 / 1.5. Default body.
  static final TextStyle body = GoogleFonts.albertSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 14 / 400 / 1.5. Supporting paragraphs.
  static final TextStyle bodySm = GoogleFonts.albertSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 13 / 400 / 1.45. Captions, meta.
  static final TextStyle caption = GoogleFonts.albertSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// 12 / 500 / 1.4 / 0.1px. Compact captions.
  static final TextStyle captionSm = GoogleFonts.albertSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// 11 / 600 / 1.4 / 0.4px. Tiny captions, chips, fineprint.
  static final TextStyle micro = GoogleFonts.albertSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.4,
  );

  /// 11 / 700 / 1.3 / 1.6px. Section labels, eyebrows.
  /// ALWAYS UPPERCASE at the call site. Never ends with a period.
  static final TextStyle eyebrow = GoogleFonts.albertSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 1.6,
  );

  /// System monospace — codes, plates, timers. Always tabular.
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.4,
  );

  // ── Numeric — Albert Sans tabular for digits ────────────────────────

  /// 56 / 700 / 1.0 / -1.6px. Bid composer hero. Tabular figures.
  static final TextStyle priceHero = GoogleFonts.albertSans(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1.6,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// 24 / 700 / 1.05 / -0.4px. Stat strip values. Tabular.
  static final TextStyle metricVal = GoogleFonts.albertSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.4,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  // ── Buttons ─────────────────────────────────────────────────────────

  /// 15 / 600 / 1.0 / 0.2px. Primary button label.
  static final TextStyle button = GoogleFonts.albertSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 0.2,
  );

  /// 13 / 600 / 1.0 / 0.3px. Compact button label.
  static final TextStyle buttonSm = GoogleFonts.albertSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 0.3,
  );
}
