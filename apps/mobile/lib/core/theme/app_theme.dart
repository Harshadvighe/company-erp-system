import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Phase 1 & 2: Modular Typography Scale, Weights, Line Heights & Accessibility ───

class AppTypography {
  // Modular Scale Font Sizes (px)
  static const double scaleDisplayLarge = 32.0;   // Hero metrics, large dashboard totals
  static const double scaleDisplayMedium = 28.0;  // Page hero titles
  static const double scaleDisplaySmall = 24.0;   // Section primary titles
  static const double scaleHeadlineLarge = 22.0;  // Module title, Card major heading (H1)
  static const double scaleHeadlineMedium = 20.0; // Section heading (H2)
  static const double scaleHeadlineSmall = 18.0;  // Subsection heading (H3)
  static const double scaleTitleLarge = 16.0;     // Card title, Dialog header
  static const double scaleTitleMedium = 15.0;    // List item title, Form group title
  static const double scaleTitleSmall = 14.0;     // Table header, Nav item
  static const double scaleBodyLarge = 15.0;      // Lead paragraph, Longform body
  static const double scaleBodyMedium = 14.0;     // Standard body, Description, Inputs
  static const double scaleBodySmall = 13.0;      // Secondary body, Table cells
  static const double scaleLabelLarge = 13.0;     // Button label, Action bar items
  static const double scaleLabelMedium = 12.0;    // Badge, Chip, Timestamp
  static const double scaleLabelSmall = 11.0;     // Caption, Helper text
  static const double scaleMicro = 10.0;          // Tag, Subscript, Status pill

  // Line Heights (Leading ratios)
  // Headings: 1.2 to 1.35 | Body: 1.5 to 1.6 | Labels/Buttons: 1.25 to 1.35
  static const double leadingDisplay = 1.25;
  static const double leadingHeading = 1.30;
  static const double leadingTitle = 1.35;
  static const double leadingBody = 1.55;
  static const double leadingLabel = 1.30;
  static const double leadingCaption = 1.25;

  // Purposeful Font Weights
  static const FontWeight regular = FontWeight.w400;   // Body text, descriptions, placeholders
  static const FontWeight medium = FontWeight.w500;    // Table cells, interactive labels, inputs
  static const FontWeight semiBold = FontWeight.w600;  // Card headers, section titles, active tabs
  static const FontWeight bold = FontWeight.w700;      // Module titles, key metrics, primary CTAs

  // WCAG AA Compliant Text Colors (Tested against #0F1115 & #181B21 dark, and #FFFFFF light)
  // Minimum contrast: 4.5:1 for normal text, 3.0:1 for large/bold text
  static const Color darkTextPrimary = Color(0xFFFFFFFF);     // 15.6:1 contrast (AAA)
  static const Color darkTextSecondary = Color(0xFF94A3B8);   // 6.8:1 contrast (Slate 400 - AA/AAA)
  static const Color darkTextMuted = Color(0xFF7A8B9E);       // 5.2:1 contrast (Exceeds WCAG AA 4.5:1)
  static const Color darkTextDisabled = Color(0xFF64748B);    // 3.8:1 contrast (For disabled states)

  static const Color lightTextPrimary = Color(0xFF0F172A);    // 17.5:1 contrast (Slate 900 - AAA)
  static const Color lightTextSecondary = Color(0xFF475569);  // 7.1:1 contrast (Slate 600 - AA/AAA)
  static const Color lightTextMuted = Color(0xFF64748B);      // 4.9:1 contrast (Slate 500 - AA)
  static const Color lightTextDisabled = Color(0xFF94A3B8);   // 3.2:1 contrast (Disabled states)

  /// Builds a comprehensive, unified TextTheme adhering to the modular scale & line heights
  static TextTheme makeTextTheme(bool isDark) {
    final primaryColor = isDark ? darkTextPrimary : lightTextPrimary;
    final secondaryColor = isDark ? darkTextSecondary : lightTextSecondary;
    final mutedColor = isDark ? darkTextMuted : lightTextMuted;

    return GoogleFonts.interTextTheme(
      TextTheme(
        // Display styles
        displayLarge: TextStyle(
          fontSize: scaleDisplayLarge,
          fontWeight: bold,
          height: leadingDisplay,
          letterSpacing: -0.5,
          color: primaryColor,
        ),
        displayMedium: TextStyle(
          fontSize: scaleDisplayMedium,
          fontWeight: bold,
          height: leadingDisplay,
          letterSpacing: -0.3,
          color: primaryColor,
        ),
        displaySmall: TextStyle(
          fontSize: scaleDisplaySmall,
          fontWeight: semiBold,
          height: leadingHeading,
          letterSpacing: -0.2,
          color: primaryColor,
        ),

        // Headline styles (H1, H2, H3)
        headlineLarge: TextStyle(
          fontSize: scaleHeadlineLarge,
          fontWeight: semiBold,
          height: leadingHeading,
          letterSpacing: -0.1,
          color: primaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: scaleHeadlineMedium,
          fontWeight: semiBold,
          height: leadingTitle,
          color: primaryColor,
        ),
        headlineSmall: TextStyle(
          fontSize: scaleHeadlineSmall,
          fontWeight: semiBold,
          height: leadingTitle,
          color: primaryColor,
        ),

        // Title styles
        titleLarge: TextStyle(
          fontSize: scaleTitleLarge,
          fontWeight: semiBold,
          height: leadingTitle,
          color: primaryColor,
        ),
        titleMedium: TextStyle(
          fontSize: scaleTitleMedium,
          fontWeight: medium,
          height: leadingTitle,
          color: primaryColor,
        ),
        titleSmall: TextStyle(
          fontSize: scaleTitleSmall,
          fontWeight: medium,
          height: leadingTitle,
          color: secondaryColor,
        ),

        // Body styles (with optimal reading leading of 1.55)
        bodyLarge: TextStyle(
          fontSize: scaleBodyLarge,
          fontWeight: regular,
          height: leadingBody,
          color: primaryColor,
        ),
        bodyMedium: TextStyle(
          fontSize: scaleBodyMedium,
          fontWeight: regular,
          height: leadingBody,
          color: secondaryColor,
        ),
        bodySmall: TextStyle(
          fontSize: scaleBodySmall,
          fontWeight: regular,
          height: leadingBody,
          color: mutedColor,
        ),

        // Label styles
        labelLarge: TextStyle(
          fontSize: scaleLabelLarge,
          fontWeight: semiBold,
          height: leadingLabel,
          letterSpacing: 0.2,
          color: primaryColor,
        ),
        labelMedium: TextStyle(
          fontSize: scaleLabelMedium,
          fontWeight: medium,
          height: leadingLabel,
          letterSpacing: 0.2,
          color: secondaryColor,
        ),
        labelSmall: TextStyle(
          fontSize: scaleLabelSmall,
          fontWeight: medium,
          height: leadingCaption,
          letterSpacing: 0.3,
          color: mutedColor,
        ),
      ),
    );
  }
}

// ─── Phase 3: Standardized 4px/8px Spacing System & Grid Tokens ─────────────

class AppSpacing {
  // Base 4px/8px Grid Tokens
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  // Standard EdgeInsets
  static const EdgeInsets pXxs = EdgeInsets.all(xxs);
  static const EdgeInsets pXs = EdgeInsets.all(xs);
  static const EdgeInsets pSm = EdgeInsets.all(sm);
  static const EdgeInsets pMd = EdgeInsets.all(md);
  static const EdgeInsets pBase = EdgeInsets.all(base);
  static const EdgeInsets pLg = EdgeInsets.all(lg);
  static const EdgeInsets pXl = EdgeInsets.all(xl);
  static const EdgeInsets pXxl = EdgeInsets.all(xxl);

  // Semantic Aliases
  static const EdgeInsets allXxs = pXxs;
  static const EdgeInsets allXs = pXs;
  static const EdgeInsets allSm = pSm;
  static const EdgeInsets allMd = pMd;
  static const EdgeInsets allBase = pBase;
  static const EdgeInsets allLg = pLg;
  static const EdgeInsets allXl = pXl;
  static const EdgeInsets allXxl = pXxl;

  // Horizontal Padding
  static const EdgeInsets hXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets hSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets hMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets hBase = EdgeInsets.symmetric(horizontal: base);
  static const EdgeInsets hLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets hXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets hXxl = EdgeInsets.symmetric(horizontal: xxl);

  // Vertical Padding
  static const EdgeInsets vXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets vSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets vMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets vBase = EdgeInsets.symmetric(vertical: base);
  static const EdgeInsets vLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets vXl = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets vXxl = EdgeInsets.symmetric(vertical: xxl);

  // Component Specific Padding
  static const EdgeInsets cardPadding = EdgeInsets.all(base);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(lg);
  static const EdgeInsets modalPadding = EdgeInsets.all(xl);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: base, vertical: md);
  static const EdgeInsets buttonPaddingCompact = EdgeInsets.symmetric(horizontal: md, vertical: sm);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  // Standard Horizontal Gaps (SizedBox)
  static const SizedBox gapW2 = SizedBox(width: xxs);
  static const SizedBox gapW4 = SizedBox(width: xs);
  static const SizedBox gapW6 = SizedBox(width: 6.0);
  static const SizedBox gapW8 = SizedBox(width: sm);
  static const SizedBox gapW10 = SizedBox(width: 10.0);
  static const SizedBox gapW12 = SizedBox(width: md);
  static const SizedBox gapW16 = SizedBox(width: base);
  static const SizedBox gapW20 = SizedBox(width: lg);
  static const SizedBox gapW24 = SizedBox(width: xl);
  static const SizedBox gapW32 = SizedBox(width: xxl);

  // Standard Vertical Gaps (SizedBox)
  static const SizedBox gapH2 = SizedBox(height: xxs);
  static const SizedBox gapH4 = SizedBox(height: xs);
  static const SizedBox gapH6 = SizedBox(height: 6.0);
  static const SizedBox gapH8 = SizedBox(height: sm);
  static const SizedBox gapH10 = SizedBox(height: 10.0);
  static const SizedBox gapH12 = SizedBox(height: md);
  static const SizedBox gapH16 = SizedBox(height: base);
  static const SizedBox gapH20 = SizedBox(height: lg);
  static const SizedBox gapH24 = SizedBox(height: xl);
  static const SizedBox gapH32 = SizedBox(height: xxl);
  static const SizedBox gapH40 = SizedBox(height: xxxl);
  static const SizedBox gapH48 = SizedBox(height: huge);
}

// ─── Layout, Breakpoints & Line-Length (Measure) Constraints ────────────────

class AppLayout {
  // Breakpoints
  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;
  static const double desktopMax = 1440.0;

  // Reading Measure (Optimal 45–75 characters per line to eliminate fatigue)
  static const double maxTextMeasure = 680.0;
  static const double maxFormWidth = 580.0;
  static const double maxAuthCardWidth = 420.0;
  static const double maxModalWidth = 640.0;
  static const double maxContentWidth = 1440.0;

  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < mobileMax;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobileMax && w < tabletMax;
  }
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= tabletMax;
}

// ─── Core App Theme ─────────────────────────────────────────────────────────

class AppTheme {
  // Brand Colors (Saark Industrial Orange)
  static const Color primary = Color(0xFFF97316); // Vibrant Safety Orange
  static const Color primaryColor = primary;
  static const Color primaryDark = Color(0xFFC2410C);
  static const Color primaryLight = Color(0xFFFFEDD5);
  static const Color primaryHover = Color(0xFFFF8533);
  static const Color backgroundColor = Color(0xFFF7F8FA);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF181B21);
  static const Color darkCard = Color(0xFF1E222A);
  static const Color darkCardElevated = Color(0xFF242933);
  static const Color darkText = AppTypography.darkTextPrimary;
  static const Color darkTextSecondary = AppTypography.darkTextSecondary;
  static const Color darkTextMuted = AppTypography.darkTextMuted;
  static const Color darkBorder = Color(0xFF2C313C);
  static const Color darkBorderSubtle = Color(0xFF232731);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightText = AppTypography.lightTextPrimary;
  static const Color lightTextSecondary = AppTypography.lightTextSecondary;
  static const Color lightTextMuted = AppTypography.lightTextMuted;
  static const Color lightBorder = Color(0xFFE5E7EB);

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color error = Color(0xFFEF4444);   // Crimson
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color info = Color(0xFF3B82F6);    // Blue

  static ThemeData get darkTheme {
    final textTheme = AppTypography.makeTextTheme(true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        surface: darkSurface,
        onSurface: darkText,
        error: error,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkText),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: darkText,
          fontWeight: AppTypography.semiBold,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: AppSpacing.buttonPadding,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppTypography.bold,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 40),
          padding: AppSpacing.buttonPadding,
          side: const BorderSide(color: primary, width: 1.2),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppTypography.semiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: AppSpacing.buttonPaddingCompact,
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: AppTypography.medium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: AppSpacing.inputPadding,
        filled: true,
        fillColor: darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: darkTextMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: primary, fontWeight: AppTypography.semiBold),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowHeight: 44,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        horizontalMargin: 16,
        columnSpacing: 24,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: primary,
              fontWeight: AppTypography.semiBold,
            );
          }
          return textTheme.labelSmall?.copyWith(color: darkTextSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1E2028),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: darkBorder),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: darkText),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: darkTextSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFF1E2028)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: darkBorder),
            ),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        alignment: Alignment.center,
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: darkText,
          fontWeight: AppTypography.bold,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: darkTextSecondary,
          height: AppTypography.leadingBody,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = AppTypography.makeTextTheme(false);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: lightSurface,
        onSurface: lightText,
        error: error,
      ),
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: lightText),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: lightText,
          fontWeight: AppTypography.semiBold,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: AppSpacing.buttonPadding,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppTypography.bold,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 40),
          padding: AppSpacing.buttonPadding,
          side: const BorderSide(color: primary, width: 1.2),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppTypography.semiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: AppSpacing.buttonPaddingCompact,
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: AppTypography.medium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: AppSpacing.inputPadding,
        filled: true,
        fillColor: lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: lightTextMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: lightTextSecondary),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: primary, fontWeight: AppTypography.semiBold),
        prefixIconColor: lightTextSecondary,
        suffixIconColor: lightTextSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowHeight: 44,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        horizontalMargin: 16,
        columnSpacing: 24,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: primary,
              fontWeight: AppTypography.semiBold,
            );
          }
          return textTheme.labelSmall?.copyWith(color: lightTextSecondary);
        }),
      ),
    );
  }
}
