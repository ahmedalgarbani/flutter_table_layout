import 'package:flutter/material.dart';

/// Style configurations for the `AdaptiveTableLayout` widget.
/// Enables detailed adjustments of fonts, colors, border spacing, and animations
/// to match the app's aesthetic guidelines (including dark/light mode integration).
class AdaptiveTableTheme {
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

  /// Divider/border color between cells and rows.
  final Color dividerColor;

  /// Background color of the footer/pagination section.
  final Color footerBackgroundColor;

  /// Text style for footer texts.
  final TextStyle footerTextStyle;

  /// Color for positive status indications (e.g. green arrows).
  final Color statusPositiveColor;

  /// Color for negative status indications (e.g. red arrows).
  final Color statusNegativeColor;

  /// Color of standard toolbar action icons.
  final Color actionIconColor;

  /// Custom gradient for the header background (overrides headerBackgroundColor).
  final Gradient? headerGradient;

  /// Custom gradient for the footer background (overrides footerBackgroundColor).
  final Gradient? footerGradient;

  /// Flags whether backdrop blur glassmorphic filters should be applied.
  final bool enableGlassmorphism;

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
    required this.dividerColor,
    required this.footerBackgroundColor,
    required this.footerTextStyle,
    this.statusPositiveColor = const Color(0xFF2E7D32), // Green
    this.statusNegativeColor = const Color(0xFFC62828), // Red
    this.actionIconColor = const Color(0xFF555555),
    this.headerGradient,
    this.footerGradient,
    this.enableGlassmorphism = false,
  });

  /// Factory for a light modern themed table layout.
  factory AdaptiveTableTheme.light(BuildContext context) {
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
          const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      rowBackgroundColor: Colors.white,
      alternateRowBackgroundColor: Colors.grey.shade50,
      rowTextStyle:
          theme.textTheme.bodyMedium ?? const TextStyle(color: Colors.black87),
      rowHoverColor: Colors.blue.shade50.withOpacity(0.3),
      dividerColor: Colors.grey.shade200,
      footerBackgroundColor: Colors.white,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600) ??
          const TextStyle(color: Colors.grey),
      actionIconColor: Colors.grey.shade700,
    );
  }

  /// Factory for a dark premium themed table layout.
  factory AdaptiveTableTheme.dark(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveTableTheme(
      cardBackgroundColor: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12.0),
      cardBorder: Border.all(color: Colors.grey.shade800, width: 1.0),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
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
          const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      rowBackgroundColor: const Color(0xFF1E1E1E),
      alternateRowBackgroundColor: const Color(0xFF232323),
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade300) ??
          const TextStyle(color: Colors.white70),
      rowHoverColor: Colors.blue.shade900.withOpacity(0.15),
      dividerColor: Colors.grey.shade800,
      footerBackgroundColor: const Color(0xFF1E1E1E),
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400) ??
          const TextStyle(color: Colors.grey),
      actionIconColor: Colors.grey.shade300,
      statusPositiveColor: const Color(0xFF4CAF50),
      statusNegativeColor: const Color(0xFFEF5350),
    );
  }

  /// Factory for a beautiful glassmorphic layout.
  factory AdaptiveTableTheme.glassmorphic(
    BuildContext context, {
    bool isDark = false,
  }) {
    final theme = Theme.of(context);
    return AdaptiveTableTheme(
      cardBackgroundColor: isDark
          ? Colors.black.withOpacity(0.3)
          : Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(16.0),
      cardBorder: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.3),
        width: 1.5,
      ),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
      enableGlassmorphism: true,
      toolbarBackgroundColor: Colors.transparent,
      headerBackgroundColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.white.withOpacity(0.15),
      headerTextStyle:
          theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
          ) ??
          TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
      rowBackgroundColor: Colors.transparent,
      alternateRowBackgroundColor: isDark
          ? Colors.white.withOpacity(0.02)
          : Colors.white.withOpacity(0.05),
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ) ??
          TextStyle(color: isDark ? Colors.white70 : Colors.black87),
      rowHoverColor: Colors.blue.shade50.withOpacity(isDark ? 0.1 : 0.25),
      dividerColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.white.withOpacity(0.15),
      footerBackgroundColor: Colors.transparent,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ) ??
          const TextStyle(color: Colors.grey),
      actionIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
    );
  }

  /// Factory for a layout highlighting gradients.
  factory AdaptiveTableTheme.gradient(
    BuildContext context, {
    bool isDark = false,
  }) {
    final lightGrad = LinearGradient(
      colors: [Colors.blue.shade700, Colors.indigo.shade800],
    );
    final darkGrad = LinearGradient(
      colors: [Colors.teal.shade800, Colors.cyan.shade900],
    );

    final activeGrad = isDark ? darkGrad : lightGrad;

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
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      headerGradient: activeGrad,
      toolbarBackgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.grey.shade50,
      headerBackgroundColor: Colors.blue.shade800, // overridden by gradient
      headerTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 13,
      ),
      rowBackgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
      alternateRowBackgroundColor: isDark
          ? const Color(0xFF1A1A1A)
          : Colors.grey.shade50,
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ) ??
          const TextStyle(color: Colors.black87),
      rowHoverColor: Colors.blue.shade50.withOpacity(0.25),
      dividerColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
      footerBackgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.grey.shade50,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ) ??
          const TextStyle(color: Colors.grey),
      actionIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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
          color: Colors.blue.shade500.withOpacity(isDark ? 0.15 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      toolbarBackgroundColor: isDark
          ? const Color(0xFF222222)
          : Colors.blue.shade50.withOpacity(0.2),
      headerBackgroundColor: isDark
          ? const Color(0xFF282828)
          : Colors.blue.shade50.withOpacity(0.4),
      headerTextStyle:
          theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade200 : Colors.blue.shade900,
          ) ??
          TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.blue,
          ),
      headerPadding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 18.0,
      ),
      rowBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      alternateRowBackgroundColor: isDark
          ? const Color(0xFF232323)
          : Colors.blue.shade50.withOpacity(0.08),
      rowTextStyle:
          theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ) ??
          const TextStyle(color: Colors.black87),
      rowPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      rowHoverColor: Colors.blue.shade50.withOpacity(0.3),
      dividerColor: isDark ? Colors.grey.shade800 : Colors.blue.shade50,
      footerBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      footerTextStyle:
          theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey.shade400 : Colors.blue.shade700,
          ) ??
          const TextStyle(color: Colors.grey),
      actionIconColor: isDark ? Colors.grey.shade300 : Colors.blue.shade700,
    );
  }
}
