import 'package:flutter/material.dart';

/// Boundless F.C. design tokens.
///
/// The palette is lifted straight from the club crest: a deep navy field, the
/// cream/ivory eagle, and the antique-gold shading that models it. Everything
/// else in the app is a tint, shade or blend of those three.
///
/// Depth ("3D") is expressed through three reusable devices, all defined here
/// so screens stay declarative:
///   • **Metal gradients** — dark→light→dark sweeps that read as brushed metal.
///   • **Bevels** — a light top edge + dark bottom edge on raised surfaces.
///   • **Layered shadows** — a tight contact shadow plus a wide ambient one,
///     optionally with a coloured glow for brand-accented elements.
class AppColors {
  AppColors._();

  // ── Brand core — sampled from the crest ─────────────────────────────────────
  /// Antique gold — the crest's shading. Primary accent.
  static const Color gold      = Color(0xFFC9A961);

  /// Deep gold/bronze — the shadow end of every metal sweep.
  static const Color goldDeep  = Color(0xFF8A6A2F);

  /// Polished gold — the highlight end of every metal sweep.
  static const Color goldLight = Color(0xFFF0D89B);

  /// The eagle's ivory. Used for high-emphasis text and light fills.
  static const Color cream     = Color(0xFFF5EBD2);

  /// Cool accent: a light tint of the crest's navy. Reads as "verified"/info
  /// without leaving the palette.
  static const Color ice       = Color(0xFF8FB9E8);

  // ── Navy field — the crest background, extended into an elevation ramp ──────
  static const Color navyDeep    = Color(0xFF0A0F1A); // app background
  static const Color navy        = Color(0xFF131C2E); // crest background
  static const Color navySurface = Color(0xFF1A2438); // raised surface
  static const Color navyElev    = Color(0xFF222E47); // highest surface

  // ── Signature gradients ─────────────────────────────────────────────────────
  /// The wordmark / primary brand sweep: a full metallic gold sheen.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [goldDeep, gold, goldLight, gold, goldDeep],
    stops: [0.0, 0.28, 0.5, 0.72, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Brushed-gold fill for buttons, pills and progress bars. The diagonal
  /// direction plus the off-centre highlight is what sells the curvature.
  static const LinearGradient goldMetal = LinearGradient(
    colors: [Color(0xFFE3C880), gold, Color(0xFF9C7B3A)],
    stops: [0.0, 0.45, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A softer gold sweep for large surfaces where full metal would shout.
  static const LinearGradient goldSoft = LinearGradient(
    colors: [gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── The two-level gold system ───────────────────────────────────────────────
  // Gold is a *light* colour, so a surface filled with it needs dark content.
  // Hero surfaces (primary button, price pill, nav medallion, avatar ring) use
  // the bright [goldMetal] and carry navy foregrounds.
  //
  // Secondary action chips throughout the app carry **white** icons and labels,
  // and white on bright gold is only 2.25:1 — illegible. Those fills use the
  // deeper antique pair below instead, which holds white at 4.7:1 (AA) while
  // staying squarely in the crest's shading tones.
  /// Shadow stop of a secondary action fill. Pairs with [goldActionEnd].
  static const Color goldActionStart = Color(0xFF5E4A20);

  /// Light stop of a secondary action fill — dark enough for white content.
  static const Color goldActionEnd = Color(0xFF8F6F32);

  /// Raised card fill (dark mode) — subtly lit from the top-left.
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293F), Color(0xFF141C2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Raised card fill (light mode).
  static const LinearGradient lightCardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF4F1E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Page backdrop — a navy vignette that lifts content off the background.
  static const RadialGradient backdropGlow = RadialGradient(
    colors: [Color(0xFF1B2740), navyDeep],
    radius: 1.1,
    center: Alignment.topCenter,
  );

  // ── Bevel edges ─────────────────────────────────────────────────────────────
  /// Light catch along the top edge of a raised surface.
  static const Color bevelLight     = Color(0x26FFFFFF);
  /// Shade along the bottom edge of a raised surface.
  static const Color bevelShadow    = Color(0x40000000);
  /// Warm inner rim used on gold elements.
  static const Color bevelGoldLight = Color(0x66FFE9B8);

  // ── Elevation ───────────────────────────────────────────────────────────────
  /// Resting elevation for cards and tiles.
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Raised elevation for buttons, dialogs and floating surfaces.
  static const List<BoxShadow> shadowLifted = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// Gold halo for primary actions — the "hero" elevation.
  static const List<BoxShadow> glowGold = [
    BoxShadow(color: Color(0x59C9A961), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  // ── Dark mode surfaces ──────────────────────────────────────────────────────
  static const Color darkBg            = navyDeep;
  static const Color darkSurface       = navy;
  static const Color darkCard          = Color(0x0FFFFFFF); // glass fill
  static const Color darkBorder        = Color(0x1AC9A961); // faint gold rim
  static const Color darkTextPrimary   = cream;
  static const Color darkTextSecondary = Color(0xFF97A3BA);
  static const Color darkTextMuted     = Color(0xFF5A6780);

  // ── Light mode surfaces ─────────────────────────────────────────────────────
  static const Color lightBg             = Color(0xFFF7F5EF); // warm ivory
  static const Color lightSurface        = Color(0xFFFFFFFF);
  static const Color lightCard           = Color(0xFFFFFFFF);
  static const Color lightBorder         = Color(0xFFE6DFCE);
  static const Color lightTextPrimary    = navy;
  static const Color lightTextSecondary  = Color(0xFF6B7385);
  static const Color lightTextMuted      = Color(0xFFA9AEBC);

  // ── Status ──────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF83);
  static const Color warning = Color(0xFFE0A94A);
  static const Color danger  = Color(0xFFD9544F);

  // ── Tier colours — re-cut as metals so they sit inside the crest palette ────
  static const Color tierBeginner = Color(0xFF8B97AC); // pewter
  static const Color tierBronze   = Color(0xFFB87333); // bronze
  static const Color tierSilver   = Color(0xFFC3CCD8); // silver
  static const Color tierGold     = gold;              // crest gold
  static const Color tierPlatinum = Color(0xFFDCE6F0); // platinum
  static const Color tierDiamond  = Color(0xFF8FB9E8); // ice
  static const Color tierElite    = Color(0xFFD9544F); // ember
  static const Color tierLegend   = Color(0xFFF0D89B); // polished gold

  /// The metallic sweep for a tier colour — used by badges and the player card
  /// so every tier gets the same 3D read as the brand gold.
  static LinearGradient metalFor(Color c) => LinearGradient(
        colors: [
          Color.lerp(c, Colors.white, 0.35)!,
          c,
          Color.lerp(c, Colors.black, 0.35)!,
        ],
        stops: const [0.0, 0.45, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
