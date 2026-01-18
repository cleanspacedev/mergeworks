import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

/// Responsive breakpoints used across the app.
///
/// These are intentionally simple and based on the shortest dimension so they
/// behave well in portrait/landscape and on foldables.
class AppBreakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;

  /// Constrain very wide layouts for readability.
  static const double maxContentWidthTablet = 900;
  static const double maxContentWidthDesktop = 1120;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Responsive helpers.
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  double get shortestSide => math.min(screenSize.width, screenSize.height);

  bool get isTablet => shortestSide >= AppBreakpoints.tablet;

  bool get isDesktop => shortestSide >= AppBreakpoints.desktop;

  double get contentMaxWidth {
    if (isDesktop) return AppBreakpoints.maxContentWidthDesktop;
    if (isTablet) return AppBreakpoints.maxContentWidthTablet;
    return double.infinity;
  }

  /// Default horizontal padding for pages.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: isTablet ? AppSpacing.xl : AppSpacing.md, vertical: AppSpacing.md);
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

/// Magical fantasy color palette for light mode
class LightModeColors {
  // Primary: Mystical purple
  static const lightPrimary = Color(0xFF7B2CBF);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFE9D5FF);
  static const lightOnPrimaryContainer = Color(0xFF3B0764);

  // Secondary: Golden accent
  static const lightSecondary = Color(0xFFD4AF37);
  static const lightOnSecondary = Color(0xFF1A1A1A);

  // Tertiary: Magical blue
  static const lightTertiary = Color(0xFF4CC9F0);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Error colors
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);

  // Surface and background: Soft mystical tones
  static const lightSurface = Color(0xFFFAF8FF);
  static const lightOnSurface = Color(0xFF1A1A1A);
  static const lightBackground = Color(0xFFF5F3FF);
  static const lightSurfaceVariant = Color(0xFFE9D5FF);
  static const lightOnSurfaceVariant = Color(0xFF3B0764);

  // Outline and shadow
  static const lightOutline = Color(0xFF74777F);
  static const lightShadow = Color(0xFF000000);
  static const lightInversePrimary = Color(0xFFACC7E3);
}

/// Dark mode magical fantasy colors
class DarkModeColors {
  // Primary: Light mystical purple
  static const darkPrimary = Color(0xFFBF95F9);
  static const darkOnPrimary = Color(0xFF3B0764);
  static const darkPrimaryContainer = Color(0xFF5A189A);
  static const darkOnPrimaryContainer = Color(0xFFE9D5FF);

  // Secondary: Bright gold
  static const darkSecondary = Color(0xFFFFD700);
  static const darkOnSecondary = Color(0xFF1A1A1A);

  // Tertiary: Bright magical blue
  static const darkTertiary = Color(0xFF72EFDD);
  static const darkOnTertiary = Color(0xFF003D5B);

  // Error colors
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  // Surface and background: Deep mystical dark
  static const darkSurface = Color(0xFF0F0A1F);
  static const darkOnSurface = Color(0xFFE9D5FF);
  static const darkSurfaceVariant = Color(0xFF1E1433);
  static const darkOnSurfaceVariant = Color(0xFFBF95F9);

  // Outline and shadow
  static const darkOutline = Color(0xFF8E9099);
  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = Color(0xFF5B7C99);
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with modern, neutral aesthetic
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: LightModeColors.lightOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.light),
);

/// Dark theme with good contrast and readability
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: DarkModeColors.darkOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

/// Higher-contrast variants of light and dark themes for accessibility
ThemeData highContrastLightTheme() {
  final base = lightTheme;
  final cs = base.colorScheme;
  final high = cs.copyWith(
    onSurface: Colors.black,
    onSurfaceVariant: Colors.black,
    surface: Colors.white,
    surfaceContainerHighest: Colors.white,
    primary: cs.primary,
    onPrimary: cs.onPrimary,
    outline: cs.outline.withValues(alpha: 0.6),
  );
  return base.copyWith(colorScheme: high);
}

ThemeData highContrastDarkTheme() {
  final base = darkTheme;
  final cs = base.colorScheme;
  final high = cs.copyWith(
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white,
    surface: const Color(0xFF0A0A0A),
    surfaceContainerHighest: const Color(0xFF0F0F0F),
    outline: cs.outline.withValues(alpha: 0.7),
  );
  return base.copyWith(colorScheme: high);
}

/// Build text theme using Inter font family
TextTheme _buildTextTheme(Brightness brightness) {
  TextStyle _font(double size, FontWeight weight, {double? letterSpacing}) {
    final base = TextStyle(fontSize: size, fontWeight: weight, letterSpacing: letterSpacing);
    // Use GoogleFonts only on Web to avoid AssetManifest issues on native release builds.
    return kIsWeb ? GoogleFonts.inter(textStyle: base) : base;
  }

  return TextTheme(
    displayLarge: _font(FontSizes.displayLarge, FontWeight.w400, letterSpacing: -0.25),
    displayMedium: _font(FontSizes.displayMedium, FontWeight.w400),
    displaySmall: _font(FontSizes.displaySmall, FontWeight.w400),
    headlineLarge: _font(FontSizes.headlineLarge, FontWeight.w600, letterSpacing: -0.5),
    headlineMedium: _font(FontSizes.headlineMedium, FontWeight.w600),
    headlineSmall: _font(FontSizes.headlineSmall, FontWeight.w600),
    titleLarge: _font(FontSizes.titleLarge, FontWeight.w600),
    titleMedium: _font(FontSizes.titleMedium, FontWeight.w500),
    titleSmall: _font(FontSizes.titleSmall, FontWeight.w500),
    labelLarge: _font(FontSizes.labelLarge, FontWeight.w500, letterSpacing: 0.1),
    labelMedium: _font(FontSizes.labelMedium, FontWeight.w500, letterSpacing: 0.5),
    labelSmall: _font(FontSizes.labelSmall, FontWeight.w500, letterSpacing: 0.5),
    bodyLarge: _font(FontSizes.bodyLarge, FontWeight.w400, letterSpacing: 0.15),
    bodyMedium: _font(FontSizes.bodyMedium, FontWeight.w400, letterSpacing: 0.25),
    bodySmall: _font(FontSizes.bodySmall, FontWeight.w400, letterSpacing: 0.4),
  );
}

// =============================================================================
// DYNAMIC LEVEL THEMING
// =============================================================================

class AppLevelTheme {
  /// Returns two colors for a vertical gradient based on the current level.
  /// Colors are generated algorithmically; no assets required.
  static List<Color> gradientForLevel(BuildContext context, int level) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use a curated hue sequence so early levels feel dramatically different.
    // This avoids the “everything is green-ish until L4” problem.
    const hues = <double>[
      120, // green
      0, // red
      210, // blue
      285, // purple
      35, // orange/gold
      165, // teal
      55, // yellow
      320, // magenta
      195, // cyan
      15, // ember
      250, // indigo
      95, // lime
    ];
    final double hue = hues[(level - 1).abs() % hues.length];

    // Raw level colors (before blending with the app surface).
    // Tuned to be noticeably different between levels, especially in dark mode.
    // Make the gradient noticeably more "biome-like" by widening contrast.
    final double satTop = isDark ? 0.88 : 0.70;
    final double lightTop = isDark ? 0.30 : 0.94;
    final double satBottom = isDark ? 0.92 : 0.60;
    final double lightBottom = isDark ? 0.11 : 0.985;

    final topRaw = HSLColor.fromAHSL(1, hue, satTop, lightTop).toColor();
    final bottomRaw = HSLColor.fromAHSL(1, (hue + 28) % 360, satBottom, lightBottom).toColor();

    // Blend with surface for visual consistency.
    // NOTE: This previously used a manual blend with incorrect channel math,
    // which effectively “flattened” the gradient and made levels look the same.
    final surface = Theme.of(context).colorScheme.surface;
    // Blend slightly with surface so text/cards still feel cohesive, but keep
    // enough saturation for a dramatic background change.
    final top = Color.lerp(topRaw, surface, isDark ? 0.08 : 0.06)!;
    final bottom = Color.lerp(bottomRaw, surface, isDark ? 0.03 : 0.02)!;

    return [top, bottom];
  }
}
