import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/models/column_definition.dart';

/// Horizontal scroll information shared by every row of the grid.
///
/// The grid scrolls horizontally with a regular `SingleChildScrollView`;
/// pinned cells are painted with a counter-offset so they stay in place.
class GridHorizontalMetrics {
  /// Controller of the horizontal scroll view (may have no clients when the
  /// grid fits the viewport).
  final ScrollController controller;

  /// `contentWidth - viewportWidth` (0 when nothing scrolls).
  final double overflow;

  const GridHorizontalMetrics({
    required this.controller,
    required this.overflow,
  });

  bool get scrolls => overflow > 0.5;

  /// Left edge of the visible window in content coordinates.
  double visibleLeft(TextDirection direction) {
    if (!scrolls || !controller.hasClients) {
      return direction == TextDirection.rtl ? overflow : 0;
    }
    final pixels = controller.positions.first.pixels.clamp(0.0, overflow);
    // In RTL the horizontal scroll view uses AxisDirection.left: pixels 0
    // shows the right end of the content.
    return direction == TextDirection.rtl ? overflow - pixels : pixels;
  }
}

/// One cell of a [PinnedRow] with its width and frozen position.
class PinnedCell extends ParentDataWidget<_PinnedCellParentData> {
  final double width;
  final ColumnPin pin;

  const PinnedCell({
    super.key,
    required this.width,
    this.pin = ColumnPin.none,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _PinnedCellParentData;
    if (data.width != width || data.pin != pin) {
      data
        ..width = width
        ..pin = pin;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => PinnedRow;
}

class _PinnedCellParentData extends ContainerBoxParentData<RenderBox> {
  double width = 0;
  ColumnPin pin = ColumnPin.none;

  /// Horizontal paint shift applied to pinned cells (set during paint).
  double shift = 0;
}

/// A table row that lays its [PinnedCell] children out horizontally with
/// fixed widths, gives them all the height of the tallest cell, and keeps
/// pinned cells visible while the row is scrolled horizontally.
class PinnedRow extends MultiChildRenderObjectWidget {
  final GridHorizontalMetrics metrics;
  final TextDirection textDirection;

  /// Painted behind pinned cells while scrolled, so the scrolled cells don't
  /// show through. Usually the (opaque) row background.
  final Color? pinnedBackground;

  /// Line drawn at the inner edge of the pinned groups while scrolled.
  final Color? pinnedDividerColor;

  /// Minimum row height.
  final double minHeight;

  const PinnedRow({
    super.key,
    required this.metrics,
    required this.textDirection,
    this.pinnedBackground,
    this.pinnedDividerColor,
    this.minHeight = 0,
    required List<PinnedCell> super.children,
  });

  @override
  RenderPinnedRow createRenderObject(BuildContext context) => RenderPinnedRow(
    metrics: metrics,
    textDirection: textDirection,
    pinnedBackground: pinnedBackground,
    pinnedDividerColor: pinnedDividerColor,
    minHeight: minHeight,
  );

  @override
  void updateRenderObject(BuildContext context, RenderPinnedRow renderObject) {
    renderObject
      ..metrics = metrics
      ..textDirection = textDirection
      ..pinnedBackground = pinnedBackground
      ..pinnedDividerColor = pinnedDividerColor
      ..minHeight = minHeight;
  }
}

class RenderPinnedRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PinnedCellParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PinnedCellParentData> {
  RenderPinnedRow({
    required GridHorizontalMetrics metrics,
    required TextDirection textDirection,
    Color? pinnedBackground,
    Color? pinnedDividerColor,
    double minHeight = 0,
  }) : _metrics = metrics,
       _textDirection = textDirection,
       _pinnedBackground = pinnedBackground,
       _pinnedDividerColor = pinnedDividerColor,
       _minHeight = minHeight;

  GridHorizontalMetrics _metrics;
  set metrics(GridHorizontalMetrics value) {
    if (identical(value.controller, _metrics.controller) &&
        value.overflow == _metrics.overflow) {
      _metrics = value;
      return;
    }
    if (attached) _metrics.controller.removeListener(markNeedsPaint);
    _metrics = value;
    if (attached) _metrics.controller.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  Color? _pinnedBackground;
  set pinnedBackground(Color? value) {
    if (value == _pinnedBackground) return;
    _pinnedBackground = value;
    markNeedsPaint();
  }

  Color? _pinnedDividerColor;
  set pinnedDividerColor(Color? value) {
    if (value == _pinnedDividerColor) return;
    _pinnedDividerColor = value;
    markNeedsPaint();
  }

  double _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _metrics.controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _metrics.controller.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PinnedCellParentData) {
      child.parentData = _PinnedCellParentData();
    }
  }

  /// Children in visual (left → right) order.
  List<RenderBox> get _visualChildren {
    final list = getChildrenAsList();
    return _textDirection == TextDirection.rtl ? list.reversed.toList() : list;
  }

  /// Whether a pinned cell sticks to the visual left edge.
  bool _pinnedLeft(ColumnPin pin) =>
      (pin == ColumnPin.start) == (_textDirection == TextDirection.ltr);

  double get _contentWidth {
    var w = 0.0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PinnedCellParentData;
      w += data.width;
      child = data.nextSibling;
    }
    return w;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _contentWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _contentWidth;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _maxChildIntrinsic((c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _maxChildIntrinsic((c, w) => c.getMaxIntrinsicHeight(w));

  double _maxChildIntrinsic(double Function(RenderBox, double) f) {
    var h = _minHeight;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PinnedCellParentData;
      h = math.max(h, f(child, data.width));
      child = data.nextSibling;
    }
    return h;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    var h = _minHeight;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PinnedCellParentData;
      h = math.max(
        h,
        child.getDryLayout(BoxConstraints.tightFor(width: data.width)).height,
      );
      child = data.nextSibling;
    }
    return constraints.constrain(Size(_contentWidth, h));
  }

  @override
  void performLayout() {
    var height = _minHeight;
    // Pass 1: natural heights.
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PinnedCellParentData;
      child.layout(
        BoxConstraints(minWidth: data.width, maxWidth: data.width),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      child = data.nextSibling;
    }
    if (constraints.hasBoundedHeight) {
      height = math.min(height, constraints.maxHeight);
    }
    height = math.max(height, constraints.minHeight);
    // Pass 2: every cell gets the row height so backgrounds line up.
    var x = 0.0;
    for (final c in _visualChildren) {
      final data = c.parentData! as _PinnedCellParentData;
      if (c.size.height != height) {
        c.layout(BoxConstraints.tightFor(width: data.width, height: height));
      }
      data.offset = Offset(x, 0);
      x += data.width;
    }
    size = constraints.constrain(Size(x, height));
  }

  void _updateShifts() {
    final overflow = _metrics.overflow;
    final left = _metrics.visibleLeft(_textDirection);
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PinnedCellParentData;
      if (!_metrics.scrolls || data.pin == ColumnPin.none) {
        data.shift = 0;
      } else if (_pinnedLeft(data.pin)) {
        data.shift = left;
      } else {
        data.shift = -(overflow - left);
      }
      child = data.nextSibling;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _updateShifts();
    // Unpinned cells first, pinned cells on top.
    RenderBox? pinnedLeftEdge;
    RenderBox? pinnedRightEdge;
    for (final c in _visualChildren) {
      final data = c.parentData! as _PinnedCellParentData;
      if (data.pin == ColumnPin.none) {
        context.paintChild(c, offset + data.offset);
      }
    }
    final background = _metrics.scrolls ? _pinnedBackground : null;
    for (final c in _visualChildren) {
      final data = c.parentData! as _PinnedCellParentData;
      if (data.pin == ColumnPin.none) continue;
      final o = offset + data.offset + Offset(data.shift, 0);
      if (background != null) {
        context.canvas.drawRect(o & c.size, Paint()..color = background);
      }
      context.paintChild(c, o);
      if (_pinnedLeft(data.pin)) {
        pinnedLeftEdge = c; // last visual-left pinned cell
      } else {
        pinnedRightEdge ??= c; // first visual-right pinned cell
      }
    }
    final dividerColor = _pinnedDividerColor;
    if (_metrics.scrolls && dividerColor != null) {
      final paint = Paint()
        ..color = dividerColor
        ..strokeWidth = 1;
      if (pinnedLeftEdge != null) {
        final data = pinnedLeftEdge.parentData! as _PinnedCellParentData;
        final x = offset.dx + data.offset.dx + data.shift + data.width - 0.5;
        context.canvas.drawLine(
          Offset(x, offset.dy),
          Offset(x, offset.dy + size.height),
          paint,
        );
      }
      if (pinnedRightEdge != null) {
        final data = pinnedRightEdge.parentData! as _PinnedCellParentData;
        final x = offset.dx + data.offset.dx + data.shift + 0.5;
        context.canvas.drawLine(
          Offset(x, offset.dy),
          Offset(x, offset.dy + size.height),
          paint,
        );
      }
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as _PinnedCellParentData;
    transform.translateByDouble(
      data.offset.dx + data.shift,
      data.offset.dy,
      0,
      1,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    _updateShifts();
    final visual = _visualChildren;
    // Pinned cells are on top: test them first.
    for (final pinnedPass in [true, false]) {
      for (final c in visual.reversed) {
        final data = c.parentData! as _PinnedCellParentData;
        if ((data.pin != ColumnPin.none) != pinnedPass) continue;
        final hit = result.addWithPaintOffset(
          offset: data.offset + Offset(data.shift, 0),
          position: position,
          hitTest: (result, transformed) =>
              c.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
    }
    return false;
  }
}

/// Keeps [child] (width = viewport) visually fixed while the grid scrolls
/// horizontally. Used for group headers and expanded-row panels.
class ViewportAnchored extends StatelessWidget {
  final GridHorizontalMetrics metrics;
  final double viewportWidth;
  final Widget child;

  const ViewportAnchored({
    super.key,
    required this.metrics,
    required this.viewportWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!metrics.scrolls) return child;
    final direction = Directionality.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: metrics.controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(metrics.visibleLeft(direction), 0),
          child: child,
        ),
        child: SizedBox(width: viewportWidth, child: child),
      ),
    );
  }
}
