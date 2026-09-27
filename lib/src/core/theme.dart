import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

const Color _defaultAccent = Color(0xFF1E88E5);

/// Style configurations for the `AdaptiveTableLayout` widget.
/// Enables detailed adjustments of fonts, colors, border spacing, and animations
/// to match the app's aesthetic guidelines (including dark/light mode integration).
///
/// It is a [ThemeExtension], so you can register it once for the whole app:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: [AdaptiveTableTheme.cozy(context)]),
/// )
/// ```
///
/// A table without an explicit `theme` uses [AdaptiveTableTheme.of].
@immutable
class AdaptiveTableTheme extends ThemeExtension<AdaptiveTableTheme> {
  /// Background color of the table card/container.
  final Color cardBackgroundColor;

  /// Corner radius of the table container.
  final BorderRadius borderRadius;

  /// Borders of the table container.
  final BoxBorder? cardBorder;

  /// Shadow decorations for the table container.
  final List<BoxShadow>? cardShadow;

  /// Margin around the entire table layout.
  final EdgeInsetsGeometry cardMargin;

  /// Padding inside the entire table layout.
  final EdgeInsetsGeometry cardPadding;

  /// Background color of the toolbar/header section.
  final Color? toolbarBackgroundColor;

  /// Background color of the column header row.
  final Color headerBackgroundColor;

  /// Text style of the column header cells.
  final TextStyle headerTextStyle;

  /// Style of the table title in the toolbar. Defaults to [headerTextStyle]
  /// at 18px.
  final TextStyle? titleTextStyle;

  /// Padding for header cells.
  final EdgeInsetsGeometry headerPadding;

  /// Base background color of data rows.
  final Color rowBackgroundColor;

  /// Alternate background color for zebra striping.
  final Color alternateRowBackgroundColor;

  /// Whether to use alternate row backgrounds.
  final bool useAlternateRows;

  /// Text style for cell text.
  final TextStyle rowTextStyle;

  /// Padding for cell content.
  final EdgeInsetsGeometry rowPadding;

  /// Background color when a row is hovered on Web/Desktop.
  final Color rowHoverColor;

  /// Background of selected rows. Defaults to [accentColor] at 10% opacity.
  final Color? selectedRowColor;

  /// Divider/border color between cells and rows.
  final Color dividerColor;

  /// Background color of the footer/pagination section.
  final Color footerBackgroundColor;

  /// Text style for footer texts.
  final TextStyle footerTextStyle;

  /// Background of the summary row. Defaults to [headerBackgroundColor] at 40%.
  final Color? summaryBackgroundColor;

  /// Color for positive status indications (e.g. green arrows).
  final Color statusPositiveColor;

  /// Color for negative status indications (e.g. red arrows).
  final Color statusNegativeColor;

  /// Color of standard action icons (filters, pagination…).
  final Color actionIconColor;

  /// Color of the icons in the toolbar. Defaults to [actionIconColor].
  final Color? toolbarIconColor;

  /// Primary brand color: "Add" button, active sort arrow, current page,
  /// checkboxes, focused inputs.
  final Color accentColor;

  /// Foreground used on top of [accentColor].
  final Color onAccentColor;

  /// Custom gradient for the toolbar and column header row
  /// (overrides [toolbarBackgroundColor] and [headerBackgroundColor]).
  final Gradient? headerGradient;

  /// Custom gradient for the footer background (overrides footerBackgroundColor).
  final Gradient? footerGradient;

  /// Flags whether backdrop blur glassmorphic filters should be applied.
  final bool enableGlassmorphism;

  /// Blur strength used when [enableGlassmorphism] is `true`.
  final double blurSigma;

  /// Resting color of skeleton placeholders
  /// (`TableLoadingStyle.skeleton`). Derived from the row text color when
  /// `null`. Translucent colors blend with the row background.
  final Color? skeletonBaseColor;

  /// Color of the shimmer band sweeping over skeleton placeholders. Derived
  /// from the row text color when `null`.
  final Color? skeletonHighlightColor;

  const AdaptiveTableTheme({
    required this.cardBackgroundColor,
    required this.borderRadius,
    this.cardBorder,
    this.cardShadow,
    this.cardMargin = const EdgeInsets.all(16.0),
    this.cardPadding = EdgeInsets.zero,
    this.toolbarBackgroundColor,
    required this.headerBackgroundColor,
    required this.headerTextStyle,
    this.titleTextStyle,
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 14.0,
    ),
    required this.rowBackgroundColor,
    required this.alternateRowBackgroundColor,
    this.useAlternateRows = true,
    required this.rowTextStyle,
    this.rowPadding = const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 12.0,
    ),
    required this.rowHoverColor,
    this.selectedRowColor,
    required this.dividerColor,
    required this.footerBackgroundColor,
    required this.footerTextStyle,
    this.summaryBackgroundColor,
    this.statusPositiveColor = const Color(0xFF2E7D32), // Green
    this.statusNegativeColor = const Color(0xFFC62828), // Red
    this.actionIconColor = const Color(0xFF555555),
    this.toolbarIconColor,
    this.accentColor = _defaultAccent,
    this.onAccentColor = Colors.white,
    this.headerGradient,
    this.footerGradient,
    this.enableGlassmorphism = false,
    this.blurSigma = 12.0,
    this.skeletonBaseColor,
    this.skeletonHighlightColor,
  });

  /// The theme a table uses when none is passed explicitly: the
  /// [AdaptiveTableTheme] registered in `ThemeData.extensions`, otherwise
  /// [AdaptiveTableTheme.adaptive].
  static AdaptiveTableTheme of(BuildContext context) {
    return Theme.of(context).extension<AdaptiveTableTheme>() ??
        AdaptiveTableTheme.adaptive(context);
  }

  /// [light] or [dark] depending on the ambient [ThemeData.brightness], using
  /// the app's `colorScheme.primary` as accent.
  factory AdaptiveTableTheme.adaptive(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return theme.brightness == Brightness.dark
        ? AdaptiveTableTheme.dark(context, accentColor: accent)
        : AdaptiveTableTheme.light(context, accentColor: accent);
  }

  /// Factory for a light modern themed table layout.
  factory AdaptiveTableTheme.light(
    BuildContext context, {
    Color accentColor = _defaultAccent,
  }) {
    final theme = Theme.of(context);
    return AdaptiveTableTheme(
      cardBackgroundColor: Colors.white,
      borderRadius: BorderRadius.circular(12.0),
      cardBorder: Border.all(color: Colors.grey.shade200, width: 1.0),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      toolbarBackgroundColor: Colors.grey.shade50,
      headerBackgroundColor: Colors.grey.shade100,
      headerTextStyle:
          theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ) ??
          TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
      rowBackgroundColor: Colors.white,
      alternateRowBackgroundColor: Colors.grey.shade50,
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade900) ??
          const TextStyle(color: Colors.black87),
      rowHoverColor: accentColor.withValues(alpha: 0.06),
      dividerColor: Colors.grey.shade200,
      footerBackgroundColor: Colors.white,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600) ??
          TextStyle(color: Colors.grey.shade600),
      actionIconColor: Colors.grey.shade700,
      accentColor: accentColor,
    );
  }

  /// Factory for a dark premium themed table layout.
  factory AdaptiveTableTheme.dark(
    BuildContext context, {
    Color accentColor = const Color(0xFF64B5F6),
  }) {
    final theme = Theme.of(context);
    return AdaptiveTableTheme(
      cardBackgroundColor: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12.0),
      cardBorder: Border.all(color: Colors.grey.shade800, width: 1.0),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      toolbarBackgroundColor: const Color(0xFF252525),
      headerBackgroundColor: const Color(0xFF2A2A2A),
      headerTextStyle:
          theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade200,
          ) ??
          TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade200),
      rowBackgroundColor: const Color(0xFF1E1E1E),
      alternateRowBackgroundColor: const Color(0xFF232323),
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade300) ??
          TextStyle(color: Colors.grey.shade300),
      rowHoverColor: accentColor.withValues(alpha: 0.08),
      dividerColor: Colors.grey.shade800,
      footerBackgroundColor: const Color(0xFF1E1E1E),
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400) ??
          TextStyle(color: Colors.grey.shade400),
      actionIconColor: Colors.grey.shade300,
      statusPositiveColor: const Color(0xFF66BB6A),
      statusNegativeColor: const Color(0xFFEF5350),
      accentColor: accentColor,
      onAccentColor: const Color(0xFF0D1B2A),
    );
  }

  /// Factory for a beautiful glassmorphic layout. Place the table over a
  /// colorful background (image / gradient) to see the blur.
  factory AdaptiveTableTheme.glassmorphic(
    BuildContext context, {
    bool isDark = false,
    Color? accentColor,
  }) {
    final theme = Theme.of(context);
    final accent =
        accentColor ?? (isDark ? const Color(0xFF80CBC4) : _defaultAccent);
    return AdaptiveTableTheme(
      cardBackgroundColor: isDark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16.0),
      cardBorder: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.5),
        width: 1.5,
      ),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
      enableGlassmorphism: true,
      toolbarBackgroundColor: Colors.transparent,
      headerBackgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.3),
      headerTextStyle:
          theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade200 : Colors.grey.shade900,
          ) ??
          TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
      rowBackgroundColor: Colors.transparent,
      alternateRowBackgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.white.withValues(alpha: 0.18),
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade900,
          ) ??
          TextStyle(color: isDark ? Colors.white70 : Colors.black87),
      rowHoverColor: Colors.white.withValues(alpha: isDark ? 0.06 : 0.25),
      dividerColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.4),
      footerBackgroundColor: Colors.transparent,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade800,
          ) ??
          const TextStyle(color: Colors.grey),
      summaryBackgroundColor: Colors.white.withValues(
        alpha: isDark ? 0.04 : 0.2,
      ),
      actionIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
      accentColor: accent,
      onAccentColor: isDark ? Colors.black : Colors.white,
    );
  }

  /// Factory for a layout highlighting gradients.
  factory AdaptiveTableTheme.gradient(
    BuildContext context, {
    bool isDark = false,
    Gradient? gradient,
  }) {
    final activeGrad =
        gradient ??
        (isDark
            ? LinearGradient(
                colors: [Colors.teal.shade800, Colors.cyan.shade900],
              )
            : LinearGradient(
                colors: [Colors.blue.shade700, Colors.indigo.shade800],
              ));

    final theme = Theme.of(context);
    return AdaptiveTableTheme(
      cardBackgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
      borderRadius: BorderRadius.circular(14.0),
      cardBorder: Border.all(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        width: 1.0,
      ),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      headerGradient: activeGrad,
      toolbarBackgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.grey.shade50,
      headerBackgroundColor: isDark
          ? Colors.teal.shade800
          : Colors.blue.shade800, // overridden by gradient
      headerTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 13,
      ),
      titleTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 18,
      ),
      toolbarIconColor: Colors.white,
      rowBackgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
      alternateRowBackgroundColor: isDark
          ? const Color(0xFF1A1A1A)
          : Colors.grey.shade50,
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ) ??
          const TextStyle(color: Colors.black87),
      rowHoverColor: (isDark ? Colors.teal : Colors.blue).withValues(
        alpha: 0.08,
      ),
      dividerColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
      footerBackgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.grey.shade50,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ) ??
          const TextStyle(color: Colors.grey),
      summaryBackgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.blue.shade50.withValues(alpha: 0.6),
      actionIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
      accentColor: isDark ? Colors.tealAccent.shade400 : Colors.indigo.shade600,
      onAccentColor: isDark ? Colors.black : Colors.white,
    );
  }

  /// Factory for a cozy, highly-spaced table layout.
  factory AdaptiveTableTheme.cozy(BuildContext context, {bool isDark = false}) {
    final theme = Theme.of(context);
    return AdaptiveTableTheme(
      cardBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(20.0),
      cardBorder: Border.all(
        color: isDark ? Colors.grey.shade800 : Colors.blue.shade100,
        width: 1.5,
      ),
      cardMargin: const EdgeInsets.all(24.0),
      cardShadow: [
        BoxShadow(
          color: Colors.blue.shade500.withValues(alpha: isDark ? 0.15 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      toolbarBackgroundColor: isDark
          ? const Color(0xFF222222)
          : Colors.blue.shade50.withValues(alpha: 0.2),
      headerBackgroundColor: isDark
          ? const Color(0xFF282828)
          : Colors.blue.shade50.withValues(alpha: 0.4),
      headerTextStyle:
          theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade200 : Colors.blue.shade900,
          ) ??
          TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.blue.shade900,
          ),
      headerPadding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 18.0,
      ),
      rowBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      alternateRowBackgroundColor: isDark
          ? const Color(0xFF232323)
          : Colors.blue.shade50.withValues(alpha: 0.25),
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ) ??
          const TextStyle(color: Colors.black87),
      rowPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      rowHoverColor: Colors.blue.withValues(alpha: isDark ? 0.1 : 0.06),
      dividerColor: isDark ? Colors.grey.shade800 : Colors.blue.shade50,
      footerBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey.shade400 : Colors.blue.shade700,
          ) ??
          const TextStyle(color: Colors.grey),
      actionIconColor: isDark ? Colors.grey.shade300 : Colors.blue.shade700,
      accentColor: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
      onAccentColor: isDark ? Colors.black : Colors.white,
    );
  }

  // --- Resolved helpers used by the widgets ---

  /// [titleTextStyle] or a derived default.
  TextStyle get effectiveTitleTextStyle =>
      titleTextStyle ?? headerTextStyle.copyWith(fontSize: 18);

  /// [selectedRowColor] or a derived default.
  Color get effectiveSelectedRowColor =>
      selectedRowColor ?? accentColor.withValues(alpha: 0.10);

  /// [toolbarIconColor] or [actionIconColor].
  Color get effectiveToolbarIconColor => toolbarIconColor ?? actionIconColor;

  /// [summaryBackgroundColor] or a derived default.
  Color get effectiveSummaryBackgroundColor =>
      summaryBackgroundColor ?? headerBackgroundColor.withValues(alpha: 0.4);

  /// [skeletonBaseColor] or a derived default.
  Color get effectiveSkeletonBaseColor =>
      skeletonBaseColor ?? _skeletonInk.withValues(alpha: 0.12);

  /// [skeletonHighlightColor] or a derived default: a fainter tint, so the
  /// band reads as light sweeping by on both light and dark rows.
  Color get effectiveSkeletonHighlightColor =>
      skeletonHighlightColor ?? _skeletonInk.withValues(alpha: 0.04);

  Color get _skeletonInk => rowTextStyle.color ?? const Color(0xFF808080);

  @override
  AdaptiveTableTheme copyWith({
    Color? cardBackgroundColor,
    BorderRadius? borderRadius,
    BoxBorder? cardBorder,
    List<BoxShadow>? cardShadow,
    EdgeInsetsGeometry? cardMargin,
    EdgeInsetsGeometry? cardPadding,
    Color? toolbarBackgroundColor,
    Color? headerBackgroundColor,
    TextStyle? headerTextStyle,
    TextStyle? titleTextStyle,
    EdgeInsetsGeometry? headerPadding,
    Color? rowBackgroundColor,
    Color? alternateRowBackgroundColor,
    bool? useAlternateRows,
    TextStyle? rowTextStyle,
    EdgeInsetsGeometry? rowPadding,
    Color? rowHoverColor,
    Color? selectedRowColor,
    Color? dividerColor,
    Color? footerBackgroundColor,
    TextStyle? footerTextStyle,
    Color? summaryBackgroundColor,
    Color? statusPositiveColor,
    Color? statusNegativeColor,
    Color? actionIconColor,
    Color? toolbarIconColor,
    Color? accentColor,
    Color? onAccentColor,
    Gradient? headerGradient,
    Gradient? footerGradient,
    bool? enableGlassmorphism,
    double? blurSigma,
    Color? skeletonBaseColor,
    Color? skeletonHighlightColor,
  }) {
    return AdaptiveTableTheme(
      cardBackgroundColor: cardBackgroundColor ?? this.cardBackgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      cardMargin: cardMargin ?? this.cardMargin,
      cardPadding: cardPadding ?? this.cardPadding,
      toolbarBackgroundColor:
          toolbarBackgroundColor ?? this.toolbarBackgroundColor,
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      headerPadding: headerPadding ?? this.headerPadding,
      rowBackgroundColor: rowBackgroundColor ?? this.rowBackgroundColor,
      alternateRowBackgroundColor:
          alternateRowBackgroundColor ?? this.alternateRowBackgroundColor,
      useAlternateRows: useAlternateRows ?? this.useAlternateRows,
      rowTextStyle: rowTextStyle ?? this.rowTextStyle,
      rowPadding: rowPadding ?? this.rowPadding,
      rowHoverColor: rowHoverColor ?? this.rowHoverColor,
      selectedRowColor: selectedRowColor ?? this.selectedRowColor,
      dividerColor: dividerColor ?? this.dividerColor,
      footerBackgroundColor:
          footerBackgroundColor ?? this.footerBackgroundColor,
      footerTextStyle: footerTextStyle ?? this.footerTextStyle,
      summaryBackgroundColor:
          summaryBackgroundColor ?? this.summaryBackgroundColor,
      statusPositiveColor: statusPositiveColor ?? this.statusPositiveColor,
      statusNegativeColor: statusNegativeColor ?? this.statusNegativeColor,
      actionIconColor: actionIconColor ?? this.actionIconColor,
      toolbarIconColor: toolbarIconColor ?? this.toolbarIconColor,
      accentColor: accentColor ?? this.accentColor,
      onAccentColor: onAccentColor ?? this.onAccentColor,
      headerGradient: headerGradient ?? this.headerGradient,
      footerGradient: footerGradient ?? this.footerGradient,
      enableGlassmorphism: enableGlassmorphism ?? this.enableGlassmorphism,
      blurSigma: blurSigma ?? this.blurSigma,
      skeletonBaseColor: skeletonBaseColor ?? this.skeletonBaseColor,
      skeletonHighlightColor:
          skeletonHighlightColor ?? this.skeletonHighlightColor,
    );
  }

  @override
  AdaptiveTableTheme lerp(
    covariant ThemeExtension<AdaptiveTableTheme>? other,
    double t,
  ) {
    if (other is! AdaptiveTableTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    Color? cn(Color? a, Color? b) => Color.lerp(a, b, t);
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    EdgeInsetsGeometry e(EdgeInsetsGeometry a, EdgeInsetsGeometry b) =>
        EdgeInsetsGeometry.lerp(a, b, t)!;
    T pick<T>(T a, T b) => t < 0.5 ? a : b;

    return AdaptiveTableTheme(
      cardBackgroundColor: c(cardBackgroundColor, other.cardBackgroundColor),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
      cardBorder: BoxBorder.lerp(cardBorder, other.cardBorder, t),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t),
      cardMargin: e(cardMargin, other.cardMargin),
      cardPadding: e(cardPadding, other.cardPadding),
      toolbarBackgroundColor: cn(
        toolbarBackgroundColor,
        other.toolbarBackgroundColor,
      ),
      headerBackgroundColor: c(
        headerBackgroundColor,
        other.headerBackgroundColor,
      ),
      headerTextStyle: s(headerTextStyle, other.headerTextStyle),
      titleTextStyle: TextStyle.lerp(titleTextStyle, other.titleTextStyle, t),
      headerPadding: e(headerPadding, other.headerPadding),
      rowBackgroundColor: c(rowBackgroundColor, other.rowBackgroundColor),
      alternateRowBackgroundColor: c(
        alternateRowBackgroundColor,
        other.alternateRowBackgroundColor,
      ),
      useAlternateRows: pick(useAlternateRows, other.useAlternateRows),
      rowTextStyle: s(rowTextStyle, other.rowTextStyle),
      rowPadding: e(rowPadding, other.rowPadding),
      rowHoverColor: c(rowHoverColor, other.rowHoverColor),
      selectedRowColor: cn(selectedRowColor, other.selectedRowColor),
      dividerColor: c(dividerColor, other.dividerColor),
      footerBackgroundColor: c(
        footerBackgroundColor,
        other.footerBackgroundColor,
      ),
      footerTextStyle: s(footerTextStyle, other.footerTextStyle),
      summaryBackgroundColor: cn(
        summaryBackgroundColor,
        other.summaryBackgroundColor,
      ),
      statusPositiveColor: c(statusPositiveColor, other.statusPositiveColor),
      statusNegativeColor: c(statusNegativeColor, other.statusNegativeColor),
      actionIconColor: c(actionIconColor, other.actionIconColor),
      toolbarIconColor: cn(toolbarIconColor, other.toolbarIconColor),
      accentColor: c(accentColor, other.accentColor),
      onAccentColor: c(onAccentColor, other.onAccentColor),
      headerGradient: Gradient.lerp(headerGradient, other.headerGradient, t),
      footerGradient: Gradient.lerp(footerGradient, other.footerGradient, t),
      enableGlassmorphism: pick(enableGlassmorphism, other.enableGlassmorphism),
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      skeletonBaseColor: cn(skeletonBaseColor, other.skeletonBaseColor),
      skeletonHighlightColor: cn(
        skeletonHighlightColor,
        other.skeletonHighlightColor,
      ),
    );
  }
}
