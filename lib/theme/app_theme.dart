// lib/theme/app_theme.dart
// GENERATED — edit AppColors to adjust master design tokens.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─── COLOR TOKENS ──────────────────────────────────────────────────────────
abstract class AppColors {
  // Dark palette
  static const darkBackground   = Color(0xFF0B0B10);
  static const darkSurface      = Color(0xFF141420);
  static const darkSurfaceVar   = Color(0xFF1C1C2E);
  static const darkDivider      = Color(0xFF2A2A3E);
  static const darkOnSurface    = Color(0xFFEAEAF0);
  static const darkOnSurfaceMut = Color(0xFF9090A8);

  // Light palette
  static const lightBackground  = Color(0xFFFFFFFF);
  static const lightSurface     = Color(0xFFF8F9FA);
  static const lightSurfaceVar  = Color(0xFFEDEEF2);
  static const lightDivider     = Color(0xFFD8D9E2);
  static const lightOnSurface   = Color(0xFF0D0D1A);
  static const lightOnSurfaceMut= Color(0xFF5A5A72);

  // Semantic — shared
  static const gold             = Color(0xFFD4AF37); // primary gold token
  static const goldHighlightDk  = Color(0xFFFFD700); // dark-mode highlights only
  static const goldHighlightLt  = Color(0xFFB8960C); // light-mode (contrast-safe)
  static const expense          = Color(0xFFE53935);
  static const expenseDark      = Color(0xFFC62828); // small text on light bg
  static const income           = Color(0xFF00E676); // dark mode
  static const incomeLight      = Color(0xFF2ECC71); // light mode
  static const incomeLightText  = Color(0xFF1A8A4A); // body text on white
  static const error            = Color(0xFFCF6679); // Material error (not expense)
  static const shimmerBase      = Color(0xFF1C1C2E); // dark shimmer
  static const shimmerHighlight = Color(0xFF2E2E45); // dark shimmer highlight
  static const shimmerBaseLt    = Color(0xFFE8E9EF); // light shimmer
  static const shimmerHighLt    = Color(0xFFF4F5F8); // light shimmer highlight
}

/// ─── TYPOGRAPHY ────────────────────────────────────────────────────────────
class AppTypography {
  static const _base = TextStyle(fontFamily: 'Roboto', letterSpacing: 0.15);

  static final displayLarge  = _base.copyWith(fontSize: 57, fontWeight: FontWeight.w300, letterSpacing: -0.25);
  static final displayMedium = _base.copyWith(fontSize: 45, fontWeight: FontWeight.w300);
  static final headlineLarge = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w600);
  static final headlineMedium= _base.copyWith(fontSize: 28, fontWeight: FontWeight.w600);
  static final headlineSmall = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w600);
  static final titleLarge    = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w500);
  static final titleMedium   = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15);
  static final titleSmall    = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1);
  static final bodyLarge     = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static final bodyMedium    = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25);
  static final bodySmall     = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4);
  static final labelLarge    = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1);
  static final labelMedium   = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5);
  static final labelSmall    = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  // Financial-specific
  static final netWorthValue = _base.copyWith(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static final transactionAmount = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
  static final currencySymbol = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
}

/// ─── THEME DATA ────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  // Backwards compatibility getters
  static ThemeData get darkTheme => dark;
  static ThemeData get lightTheme => light;

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background   = isDark ? AppColors.darkBackground   : AppColors.lightBackground;
    final surface      = isDark ? AppColors.darkSurface      : AppColors.lightSurface;
    final surfaceVar   = isDark ? AppColors.darkSurfaceVar   : AppColors.lightSurfaceVar;
    final onSurface    = isDark ? AppColors.darkOnSurface    : AppColors.lightOnSurface;
    final onSurfaceMut = isDark ? AppColors.darkOnSurfaceMut : AppColors.lightOnSurfaceMut;
    final divider      = isDark ? AppColors.darkDivider      : AppColors.lightDivider;
    final incomeColor  = isDark ? AppColors.income           : AppColors.incomeLight;
    final goldHL       = isDark ? AppColors.goldHighlightDk  : AppColors.goldHighlightLt;

    final colorScheme = ColorScheme(
      brightness:           brightness,
      primary:              AppColors.gold,
      onPrimary:            AppColors.darkBackground,
      primaryContainer:     isDark ? const Color(0xFF2A2410) : const Color(0xFFFFF8DC),
      onPrimaryContainer:   isDark ? AppColors.goldHighlightDk : AppColors.goldHighlightLt,
      secondary:            incomeColor,
      onSecondary:          AppColors.darkBackground,
      secondaryContainer:   isDark ? const Color(0xFF003320) : const Color(0xFFDCF5E8),
      onSecondaryContainer: isDark ? AppColors.income : AppColors.incomeLightText,
      error:                AppColors.error,
      onError:              Colors.white,
      errorContainer:       isDark ? const Color(0xFF370B1E) : const Color(0xFFFFDAD6),
      onErrorContainer:     isDark ? const Color(0xFFFFB3BA) : const Color(0xFF410002),
      surface:              surface,
      onSurface:            onSurface,
      surfaceContainerHighest: surfaceVar,
      outline:              divider,
      outlineVariant:       divider.withValues(alpha: 0.5),
      scrim:                Colors.black87,
      inverseSurface:       onSurface,
      onInverseSurface:     surface,
      inversePrimary:       AppColors.gold,
    );

    return ThemeData(
      useMaterial3:    true,
      brightness:      brightness,
      colorScheme:     colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor:     surface,
      cardColor:       surface,
      dividerColor:    divider,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:    background,
        foregroundColor:    onSurface,
        surfaceTintColor:   Colors.transparent,
        elevation:          0,
        scrolledUnderElevation: 1,
        shadowColor:        divider,
        titleTextStyle:     AppTypography.titleLarge.copyWith(color: onSurface),
        iconTheme:          IconThemeData(color: onSurface),
        actionsIconTheme:   IconThemeData(color: onSurface),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),

      // ── Navigation Bar (bottom) ─────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:          surface,
        indicatorColor:           AppColors.gold.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.gold, size: 24);
          }
          return IconThemeData(color: onSurfaceMut, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelMedium.copyWith(color: AppColors.gold);
          }
          return AppTypography.labelMedium.copyWith(color: onSurfaceMut);
        }),
        elevation: 4,
        shadowColor: Colors.black45,
        overlayColor: WidgetStateProperty.all(AppColors.gold.withValues(alpha: 0.08)),
      ),

      // ── Navigation Rail ─────────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor:   surface,
        indicatorColor:    AppColors.gold.withValues(alpha: 0.15),
        selectedIconTheme: const IconThemeData(color: AppColors.gold, size: 24),
        unselectedIconTheme: IconThemeData(color: onSurfaceMut, size: 24),
        selectedLabelTextStyle: AppTypography.labelMedium.copyWith(color: AppColors.gold),
        unselectedLabelTextStyle: AppTypography.labelMedium.copyWith(color: onSurfaceMut),
        elevation: 0,
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color:        surface,
        elevation:    isDark ? 0 : 1,
        shadowColor:  Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:         BorderSide(color: divider, width: 1),
        ),
        margin:       const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Elevated Button ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:    AppColors.gold,
          foregroundColor:    AppColors.darkBackground,
          disabledBackgroundColor: divider,
          disabledForegroundColor: onSurfaceMut,
          elevation:          0,
          shape:              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:          AppTypography.labelLarge,
        ),
      ),

      // ── Outlined Button ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:  onSurface,
          side:             BorderSide(color: divider, width: 1),
          shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:        AppTypography.labelLarge,
        ),
      ),

      // ── Text Button ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle:       AppTypography.labelLarge,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor:  AppColors.gold,
        foregroundColor:  AppColors.darkBackground,
        elevation:        4,
        shape:            RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:         BorderSide(color: goldHL.withValues(alpha: 0.4), width: 1),
        ),
        extendedTextStyle: AppTypography.labelLarge.copyWith(color: AppColors.darkBackground),
      ),

      // ── Input Decoration ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       surfaceVar,
        contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border:          OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: divider),
        ),
        enabledBorder:   OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: divider),
        ),
        focusedBorder:   OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.gold, width: 2),
        ),
        errorBorder:     OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.expense, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.expense, width: 2),
        ),
        hintStyle:       AppTypography.bodyMedium.copyWith(color: onSurfaceMut),
        labelStyle:      AppTypography.bodyMedium.copyWith(color: onSurfaceMut),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(color: AppColors.gold),
        prefixIconColor: onSurfaceMut,
        suffixIconColor: onSurfaceMut,
        errorStyle:      AppTypography.bodySmall.copyWith(color: AppColors.expense),
      ),

      // ── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor:   surfaceVar,
        selectedColor:     AppColors.gold.withValues(alpha: 0.18),
        disabledColor:     divider,
        labelStyle:        AppTypography.labelMedium.copyWith(color: onSurface),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(color: AppColors.gold),
        side:              BorderSide(color: divider),
        shape:             RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding:           const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconTheme:         IconThemeData(color: onSurfaceMut, size: 16),
        selectedShadowColor: Colors.transparent,
        checkmarkColor:    AppColors.gold,
      ),

      // ── Switch ──────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.gold;
          return onSurfaceMut;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.gold.withValues(alpha: 0.3);
          return divider;
        }),
      ),

      // ── Slider ──────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor:   AppColors.gold,
        inactiveTrackColor: divider,
        thumbColor:         AppColors.gold,
        overlayColor:       AppColors.gold.withValues(alpha: 0.12),
        valueIndicatorColor: surface,
        valueIndicatorTextStyle: AppTypography.labelSmall.copyWith(color: onSurface),
      ),

      // ── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor:  surface,
        surfaceTintColor: Colors.transparent,
        elevation:        8,
        shadowColor:      Colors.black54,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle:   AppTypography.headlineSmall.copyWith(color: onSurface),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
      ),

      // ── Bottom Sheet ────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:  surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation:        8,
        modalElevation:   16,
        shape:            const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle:   true,
        dragHandleColor:  divider,
      ),

      // ── Drawer ──────────────────────────────────────────────────────────
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation:       0,
        shape:           const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        ),
      ),

      // ── List Tile ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor:       Colors.transparent,
        selectedTileColor: AppColors.gold.withValues(alpha: 0.08),
        selectedColor:   AppColors.gold,
        iconColor:       onSurfaceMut,
        textColor:       onSurface,
        contentPadding:  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle:  AppTypography.bodyMedium.copyWith(color: onSurface),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(color: onSurfaceMut),
      ),

      // ── Tab Bar ─────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor:         AppColors.gold,
        unselectedLabelColor: onSurfaceMut,
        labelStyle:         AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
        indicator:          UnderlineTabIndicator(
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
        indicatorSize:      TabBarIndicatorSize.label,
        dividerColor:       divider,
        overlayColor:       WidgetStateProperty.all(AppColors.gold.withValues(alpha: 0.06)),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color:    divider,
        thickness: 1,
        space:    1,
      ),

      // ── Progress Indicator ───────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:              AppColors.gold,
        linearTrackColor:   divider,
        circularTrackColor: divider,
      ),

      // ── Icon ────────────────────────────────────────────────────────────
      iconTheme: IconThemeData(color: onSurface, size: 24),
      primaryIconTheme: const IconThemeData(color: AppColors.gold, size: 24),

      // ── SnackBar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:    isDark ? const Color(0xFF2A2A3E) : const Color(0xFF1A1A2E),
        contentTextStyle:   AppTypography.bodyMedium.copyWith(color: Colors.white),
        actionTextColor:    AppColors.gold,
        shape:              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior:           SnackBarBehavior.floating,
        elevation:          4,
      ),

      // ── Tooltip ─────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color:        isDark ? const Color(0xFF2E2E45) : const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTypography.bodySmall.copyWith(color: Colors.white),
        padding:   const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ── Popup Menu ──────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color:        surface,
        surfaceTintColor: Colors.transparent,
        elevation:    4,
        shadowColor:  Colors.black45,
        shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:    AppTypography.bodyMedium.copyWith(color: onSurface),
        labelTextStyle: WidgetStateProperty.all(
          AppTypography.bodyMedium.copyWith(color: onSurface),
        ),
      ),

      // ── Date/Time Picker ─────────────────────────────────────────────────
      datePickerTheme: DatePickerThemeData(
        backgroundColor:      surface,
        surfaceTintColor:     Colors.transparent,
        headerBackgroundColor: background,
        headerForegroundColor: onSurface,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.darkBackground;
          return onSurface;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.gold;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.all(AppColors.gold),
        todayBorder:          const BorderSide(color: AppColors.gold, width: 1),
        shape:                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Time Picker ──────────────────────────────────────────────────────
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        hourMinuteColor: surfaceVar,
        hourMinuteTextColor: onSurface,
        dialBackgroundColor: surfaceVar,
        dialHandColor:   AppColors.gold,
        dialTextColor:   onSurface,
        dayPeriodBorderSide: BorderSide(color: divider),
        dayPeriodColor: AppColors.gold.withValues(alpha: 0.2),
        dayPeriodTextColor: AppColors.gold,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Search Bar ───────────────────────────────────────────────────────
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(surfaceVar),
        shadowColor:     WidgetStateProperty.all(Colors.transparent),
        shape:           WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        textStyle:       WidgetStateProperty.all(AppTypography.bodyMedium.copyWith(color: onSurface)),
        hintStyle:       WidgetStateProperty.all(AppTypography.bodyMedium.copyWith(color: onSurfaceMut)),
        padding:         WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
      ),

      // ── Expansion Tile ───────────────────────────────────────────────────
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor:      Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor:            AppColors.gold,
        collapsedIconColor:   onSurfaceMut,
        textColor:            AppColors.gold,
        collapsedTextColor:   onSurface,
        childrenPadding:      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tilePadding:          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape:                const Border(),
        collapsedShape:       const Border(),
      ),

      // ── Text Selection ───────────────────────────────────────────────────
      textSelectionTheme: TextSelectionThemeData(
        cursorColor:         AppColors.gold,
        selectionColor:      AppColors.gold.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.gold,
      ),

      // ── Typography ───────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge:   AppTypography.displayLarge.copyWith(color: onSurface),
        displayMedium:  AppTypography.displayMedium.copyWith(color: onSurface),
        headlineLarge:  AppTypography.headlineLarge.copyWith(color: onSurface),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: onSurface),
        headlineSmall:  AppTypography.headlineSmall.copyWith(color: onSurface),
        titleLarge:     AppTypography.titleLarge.copyWith(color: onSurface),
        titleMedium:    AppTypography.titleMedium.copyWith(color: onSurface),
        titleSmall:     AppTypography.titleSmall.copyWith(color: onSurface),
        bodyLarge:      AppTypography.bodyLarge.copyWith(color: onSurface),
        bodyMedium:     AppTypography.bodyMedium.copyWith(color: onSurface),
        bodySmall:      AppTypography.bodySmall.copyWith(color: onSurfaceMut),
        labelLarge:     AppTypography.labelLarge.copyWith(color: onSurface),
        labelMedium:    AppTypography.labelMedium.copyWith(color: onSurfaceMut),
        labelSmall:     AppTypography.labelSmall.copyWith(color: onSurfaceMut),
      ),
    );
  }
}
