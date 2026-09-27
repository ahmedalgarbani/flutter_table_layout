import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../domain/models/column_definition.dart';

/// How a table shows that its rows are loading.
enum TableLoadingStyle {
  /// A centered [CircularProgressIndicator].
  spinner,

  /// Placeholder rows (desktop) or cards (mobile) with a shimmer sweep.
  skeleton,
}

/// Paints a moving highlight over the opaque parts of [child].
///
/// Give it [SkeletonBox]es (or any solid shapes): their pixels are recolored
/// with a [baseColor] → [highlightColor] → [baseColor] band that sweeps in
/// the reading direction (right to left in RTL). The animation stops when
/// [enabled] is `false` or the platform asks to reduce motion.
class TableShimmer extends StatefulWidget {
  final Widget child;

  /// Resting color of the placeholders. Defaults to
  /// [AdaptiveTableTheme.effectiveSkeletonBaseColor].
  final Color? baseColor;

  /// Color of the moving band. Defaults to
  /// [AdaptiveTableTheme.effectiveSkeletonHighlightColor].
  final Color? highlightColor;

  /// Duration of one sweep.
  final Duration period;

  /// `false` shows the placeholders in [baseColor] without animating.
  final bool enabled;

  const TableShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1400),
    this.enabled = true,
  });

  @override
  State<TableShimmer> createState() => _TableShimmerState();
}

class _TableShimmerState extends State<TableShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TableShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.period;
    _sync();
  }

  bool get _animate =>
      widget.enabled &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    if (_animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdaptiveTableTheme.of(context);
    final base = widget.baseColor ?? theme.effectiveSkeletonBaseColor;
    final highlight =
        widget.highlightColor ?? theme.effectiveSkeletonHighlightColor;
    if (!_animate) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(base, BlendMode.srcIn),
        child: widget.child,
      );
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Slides the band from one edge (-1) past the other (+1).
        final shift = (_controller.value * 2 - 1) * (rtl ? -1 : 1);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(shift),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double fraction;
  const _SlideGradient(this.fraction);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// A solid rounded placeholder shape; meant to be placed inside a
/// [TableShimmer], which recolors it.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Any opaque color: TableShimmer paints over it.
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder that mirrors the table's shape while rows load: a grid with a
/// header and [rowCount] rows on wide layouts, or a list of cards when
/// [compact] is `true`.
class TableSkeleton extends StatelessWidget {
  /// Columns to mirror (widths / flex). When `null`, [columnCount] equal
  /// columns are drawn.
  final List<ColumnDefinition>? columns;

  /// Number of columns when [columns] is `null`.
  final int columnCount;

  /// Number of placeholder rows (or cards).
  final int rowCount;

  /// Card layout used on phones.
  final bool compact;

  /// Draws a placeholder header row above the rows (grid layout only).
  final bool showHeader;

  /// Adds a checkbox placeholder at the start of each row.
  final bool showSelection;

  /// Defaults to [AdaptiveTableTheme.of].
  final AdaptiveTableTheme? theme;

  /// Whether the shimmer sweeps. `false` shows static placeholders.
  final bool animate;

  const TableSkeleton({
    super.key,
    this.columns,
    this.columnCount = 5,
    this.rowCount = 6,
    this.compact = false,
    this.showHeader = true,
    this.showSelection = false,
    this.theme,
    this.animate = true,
  }) : assert(rowCount >= 0),
       assert(columnCount > 0);

  // Varied text lengths so the rows don't look like a barcode.
  static const _widths = [0.9, 0.6, 0.75, 0.5, 0.8, 0.65, 0.7];

  @override
  Widget build(BuildContext context) {
    final t = theme ?? AdaptiveTableTheme.of(context);
    final body = compact ? _cards(t) : _grid(t);
    // Never scrolls, never overflows: extra rows are clipped when the table
    // body is shorter than the skeleton.
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        primary: false,
        child: body,
      ),
    );
  }

  TableShimmer _shimmer(AdaptiveTableTheme t, Widget child) => TableShimmer(
    baseColor: t.effectiveSkeletonBaseColor,
    highlightColor: t.effectiveSkeletonHighlightColor,
    enabled: animate,
    child: child,
  );

  /// Relative column weights. Fixed widths and flex columns are both turned
  /// into proportions (a flex unit ≈ 150 px) so the skeleton always fits the
  /// available width.
  List<int> get _weights {
    final visible = columns?.where((c) => c.isVisible).toList();
    if (visible == null || visible.isEmpty) return List.filled(columnCount, 1);
    return [
      for (final c in visible)
        (c.width ?? 150.0 * (c.flex < 1 ? 1 : c.flex)).round().clamp(1, 100000),
    ];
  }

  Widget _cells(
    AdaptiveTableTheme t,
    int row, {
    required bool header,
    required EdgeInsetsGeometry padding,
  }) {
    final weights = _weights;
    Widget bar(int col) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: header ? 0.55 : _widths[(row + col * 3) % _widths.length],
      child: SkeletonBox(height: header ? 12 : 10),
    );
    return Row(
      children: [
        if (showSelection)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 16, end: 4),
            child: SkeletonBox(width: 18, height: 18, radius: 4),
          ),
        for (var i = 0; i < weights.length; i++)
          Expanded(
            flex: weights[i],
            child: Padding(padding: padding, child: bar(i)),
          ),
      ],
    );
  }

  Widget _grid(AdaptiveTableTheme t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.headerGradient == null ? t.headerBackgroundColor : null,
              gradient: t.headerGradient,
            ),
            child: _shimmer(
              t,
              _cells(t, 0, header: true, padding: t.headerPadding),
            ),
          ),
          Divider(height: 1, thickness: 1, color: t.dividerColor),
        ],
        for (var r = 0; r < rowCount; r++) ...[
          ColoredBox(
            color: t.useAlternateRows && r.isOdd
                ? t.alternateRowBackgroundColor
                : t.rowBackgroundColor,
            child: _shimmer(
              t,
              _cells(t, r, header: false, padding: t.rowPadding),
            ),
          ),
          Divider(height: 1, color: t.dividerColor),
        ],
      ],
    );
  }

  Widget _cards(AdaptiveTableTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < rowCount; r++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 14, 12, 14),
              decoration: BoxDecoration(
                color: t.rowBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.dividerColor),
              ),
              child: _shimmer(
                t,
                Row(
                  children: [
                    if (showSelection) ...[
                      const SkeletonBox(width: 18, height: 18, radius: 4),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: _widths[r % _widths.length] * 0.8,
                            child: const SkeletonBox(height: 13),
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor:
                                _widths[(r + 3) % _widths.length] * 0.6,
                            child: const SkeletonBox(height: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SkeletonBox(width: 20, height: 20, radius: 10),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
