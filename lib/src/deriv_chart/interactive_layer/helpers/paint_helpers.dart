import 'dart:ui';

import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_paint_style.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/chart/helpers/chart_date_utils.dart';
import 'package:deriv_chart/src/theme/painting_styles/line_style.dart';
import 'package:flutter/material.dart';

/// Draws alignment guides (horizontal and vertical lines) for a single point
void drawPointAlignmentGuides(Canvas canvas, Size size, Offset pointOffset,
    {Color lineColor = const Color(0x80FFFFFF)}) {
  drawPointAlignmentGuidesWithOpacity(canvas, size, pointOffset,
      lineColor: lineColor);
}

/// Draws alignment guides with configurable opacity for animations
void drawPointAlignmentGuidesWithOpacity(
    Canvas canvas, Size size, Offset pointOffset,
    {Color lineColor = const Color(0x80FFFFFF), double opacity = 1.0}) {
  // Skip drawing if opacity is effectively zero (performance optimization)
  if (opacity <= 0.0) {
    return;
  }

  // Create a dashed paint style for the alignment guides with opacity
  final Paint guidesPaint = Paint()
    ..color = lineColor.withOpacity(lineColor.opacity * opacity)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  // Create paths for horizontal and vertical guides
  final Path horizontalPath = Path();
  final Path verticalPath = Path();

  // Draw horizontal and vertical guides from the point
  horizontalPath
    ..moveTo(0, pointOffset.dy)
    ..lineTo(size.width, pointOffset.dy);

  verticalPath
    ..moveTo(pointOffset.dx, 0)
    ..lineTo(pointOffset.dx, size.height);

  // Draw the dashed lines
  canvas
    ..drawPath(
      dashPath(horizontalPath,
          dashArray: CircularIntervalList<double>(<double>[2, 2])),
      guidesPaint,
    )
    ..drawPath(
      dashPath(verticalPath,
          dashArray: CircularIntervalList<double>(<double>[2, 2])),
      guidesPaint,
    );
}

/// Creates a dashed path from a regular path
Path dashPath(
  Path source, {
  required CircularIntervalList<double> dashArray,
}) {
  final Path dest = Path();
  for (final PathMetric metric in source.computeMetrics()) {
    double distance = 0;
    bool draw = true;
    while (distance < metric.length) {
      final double len = dashArray.next;
      if (draw) {
        dest.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
      }
      distance += len;
      draw = !draw;
    }
  }
  return dest;
}

/// Draws a point for a given [EdgePoint].
void drawPoint(
  EdgePoint point,
  EpochToX epochToX,
  QuoteToY quoteToY,
  Canvas canvas,
  DrawingPaintStyle paintStyle,
  LineStyle lineStyle, {
  double radius = 5,
}) {
  canvas.drawCircle(
    Offset(epochToX(point.epoch), quoteToY(point.quote)),
    radius,
    paintStyle.glowyCirclePaintStyle(lineStyle.color),
  );
}

/// Draws a point for a given [Offset].
void drawPointOffset(
  Offset point,
  EpochToX epochToX,
  QuoteToY quoteToY,
  Canvas canvas,
  DrawingPaintStyle paintStyle,
  LineStyle lineStyle, {
  double radius = 5,
}) {
  canvas.drawCircle(
    point,
    radius,
    paintStyle.glowyCirclePaintStyle(lineStyle.color),
  );
}

/// Draws a point for an anchor point of a drawing tool with a glowy effect.
void drawFocusedCircle(
  DrawingPaintStyle paintStyle,
  LineStyle lineStyle,
  Canvas canvas,
  Offset offset,
  double outerCircleRadius,
  double innerCircleRadius,
) {
  final normalPaintStyle = paintStyle.glowyCirclePaintStyle(lineStyle.color);
  final glowyPaintStyle =
      paintStyle.glowyCirclePaintStyle(lineStyle.color.withOpacity(0.3));
  canvas
    ..drawCircle(
      offset,
      outerCircleRadius,
      glowyPaintStyle,
    )
    ..drawCircle(
      offset,
      innerCircleRadius,
      normalPaintStyle,
    );
}

/// Draws a point for an anchor point of a drawing tool with a glowy effect.
void drawPointsFocusedCircle(
  DrawingPaintStyle paintStyle,
  LineStyle lineStyle,
  Canvas canvas,
  Offset startOffset,
  double outerCircleRadius,
  double innerCircleRadius,
  Offset endOffset,
) {
  drawFocusedCircle(paintStyle, lineStyle, canvas, startOffset,
      outerCircleRadius, innerCircleRadius);
  drawFocusedCircle(paintStyle, lineStyle, canvas, endOffset, outerCircleRadius,
      innerCircleRadius);
}

/// A circular array for dash patterns
class CircularIntervalList<T> {
  /// Initializes [CircularIntervalList].
  CircularIntervalList(this._values);

  final List<T> _values;
  int _index = 0;

  /// Returns the next value in the circular list.
  T get next {
    if (_index >= _values.length) {
      _index = 0;
    }
    return _values[_index++];
  }
}

/// Layout for a pair of Y-axis price labels that must not overlap.
///
/// Produced by [layoutValueLabelPair].
class ValueLabelPairLayout {
  /// Creates a [ValueLabelPairLayout].
  const ValueLabelPairLayout({
    required this.showSecond,
    this.firstYOverride,
    this.secondYOverride,
  });

  /// Y position to draw the first label's box at, or `null` to use its true
  /// price. Pass to [drawValueLabel]'s `yPositionOverride`.
  final double? firstYOverride;

  /// Y position to draw the second label's box at, or `null` to use its true
  /// price. Pass to [drawValueLabel]'s `yPositionOverride`.
  final double? secondYOverride;

  /// Whether the second label should be drawn. `false` when both prices format
  /// to the same displayed value, so a single shared label is shown.
  final bool showSecond;
}

/// Computes non-overlapping positions for two Y-axis price labels.
///
/// * If [firstQuote] and [secondQuote] format to the same displayed value (at
///   [pipSize] decimals) only one label is shown ([ValueLabelPairLayout.showSecond]
///   is `false`).
/// * Otherwise, if the two label boxes would overlap (their centres are closer
///   than [minGap]), only the label of the point currently being dragged is
///   pushed to the adjacent slot while the other stays anchored to its price,
///   so a drag never shoves the stationary label. [isDraggingFirst] is `true`
///   when the first point is being dragged, `false` for the second, and `null`
///   when neither is (static selection or whole-shape drag) — in which case the
///   first label stays anchored and the second one moves.
ValueLabelPairLayout layoutValueLabelPair({
  required double firstQuote,
  required double secondQuote,
  required QuoteToY quoteToY,
  required int pipSize,
  required bool? isDraggingFirst,
  double minGap = 24,
}) {
  if (firstQuote.toStringAsFixed(pipSize) ==
      secondQuote.toStringAsFixed(pipSize)) {
    return const ValueLabelPairLayout(showSecond: false);
  }

  final double firstY = quoteToY(firstQuote);
  final double secondY = quoteToY(secondQuote);

  double? firstYOverride;
  double? secondYOverride;
  if ((firstY - secondY).abs() < minGap) {
    if (isDraggingFirst ?? false) {
      firstYOverride = secondY + (firstY <= secondY ? -minGap : minGap);
    } else {
      secondYOverride = firstY + (secondY <= firstY ? -minGap : minGap);
    }
  }

  return ValueLabelPairLayout(
    showSecond: true,
    firstYOverride: firstYOverride,
    secondYOverride: secondYOverride,
  );
}

/// Output of [layoutValueLabels]: a price and the Y its box should draw at.
class PositionedValueLabel {
  /// Creates a [PositionedValueLabel].
  const PositionedValueLabel({required this.quote, required this.y});

  /// The price the label shows.
  final double quote;

  /// The Y position to draw the box at (pass as [drawValueLabel]'s
  /// `yPositionOverride`).
  final double y;
}

/// Lays out several Y-axis price labels so their boxes don't overlap.
///
/// Labels whose prices format to the same displayed value (at [pipSize]) are
/// merged into a single label. Remaining labels whose boxes would overlap are
/// spread symmetrically until each vertically-adjacent pair is at least
/// [minGap] apart. The layout depends only on the prices, so it is identical
/// whether or not a drag is in progress.
///
/// Returns one entry per visible label; duplicates are dropped.
List<PositionedValueLabel> layoutValueLabels(
  List<double> quotes,
  QuoteToY quoteToY,
  int pipSize, {
  double minGap = 24,
}) {
  // Merge quotes that format to the same displayed value.
  final Map<String, double> byDisplay = <String, double>{};
  for (final double quote in quotes) {
    byDisplay.putIfAbsent(quote.toStringAsFixed(pipSize), () => quote);
  }

  final List<double> unique = byDisplay.values.toList();
  final List<double> ys = unique.map(quoteToY).toList();

  // Relax positions so vertically adjacent boxes stay [minGap] apart. A few
  // passes converge for the handful of labels a drawing shows.
  for (int iteration = 0; iteration < 8; iteration++) {
    final List<int> order = List<int>.generate(unique.length, (int i) => i)
      ..sort((int a, int b) => ys[a].compareTo(ys[b]));
    bool changed = false;
    for (int k = 0; k < order.length - 1; k++) {
      final int i = order[k]; // Upper label (smaller y).
      final int j = order[k + 1]; // Lower label (larger y).
      final double overlap = minGap - (ys[j] - ys[i]);
      if (overlap <= 0.01) {
        continue;
      }
      ys[i] -= overlap / 2;
      ys[j] += overlap / 2;
      changed = true;
    }
    if (!changed) {
      break;
    }
  }

  return <PositionedValueLabel>[
    for (int i = 0; i < unique.length; i++)
      PositionedValueLabel(quote: unique[i], y: ys[i]),
  ];
}

/// Draws a value rectangle with formatted price based on pip size
///
/// This draws a rounded rectangle with the formatted value inside it.
/// The value is formatted according to the provided pip size.
/// If [addNeonEffect] is true, it will add a neon glow effect around the label.
void drawValueLabel({
  required Canvas canvas,
  required QuoteToY quoteToY,
  required double value,
  required int pipSize,
  required Size size,
  required TextStyle textStyle,
  double animationProgress = 1,
  Color color = Colors.white,
  Color backgroundColor = Colors.transparent,
  bool addNeonEffect = false,
  double neonOpacity = 0.4,
  double neonStrokeWidth = 8,
  double neonBlurRadius = 6,
  double? yPositionOverride,
}) {
  // Calculate Y position based on the value. Callers can pass
  // [yPositionOverride] to shift the label box (e.g. to stop two labels with
  // near-equal prices from overlapping) while the value text still reflects the
  // real price.
  final double yPosition = yPositionOverride ?? quoteToY(value);

  // Format the value according to pip size with proper decimal places
  final String formattedValue = value.toStringAsFixed(pipSize);

  // Create text painter to measure text dimensions
  final TextPainter textPainter = _getTextPainter(
    formattedValue,
    textStyle: textStyle.copyWith(
      color: textStyle.color?.withOpacity(animationProgress),
    ),
  )..layout();

  // Create rectangle with padding around the text
  final double rectWidth =
      textPainter.width + 16; // Add padding of 8px on each side
  const double rectHeight = 24; // Fixed height to match the image

  // Add 8px gap between the chart content and the label
  final double rectRight = size.width - 4;
  final double rectLeft = rectRight - rectWidth;

  final Rect rect = Rect.fromLTRB(
    rectLeft,
    yPosition - rectHeight / 2,
    rectRight,
    yPosition + rectHeight / 2,
  );

  final RRect roundedRect =
      RRect.fromRectAndRadius(rect, const Radius.circular(4));

  // Draw neon effect if requested
  if (addNeonEffect) {
    final Paint neonPaint = Paint()
      ..color = color.withOpacity(neonOpacity)
      ..strokeWidth = neonStrokeWidth * animationProgress
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, neonBlurRadius);

    canvas.drawRRect(roundedRect, neonPaint);
  }

  // Draw rounded rectangle
  final Paint rectPaint = Paint()
    ..color = backgroundColor.withOpacity(animationProgress)
    ..style = PaintingStyle.fill;

  final Paint borderPaint = Paint()
    ..color = color.withOpacity(animationProgress)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  // Draw the background and border
  canvas
    ..drawRRect(roundedRect, rectPaint)
    ..drawRRect(roundedRect, borderPaint);

  // Draw the text centered in the rectangle
  textPainter.paint(
    canvas,
    Offset(
      rect.left + (rectWidth - textPainter.width) / 2,
      rect.top + (rectHeight - textPainter.height) / 2,
    ),
  );
}

/// Draws an epoch label rectangle on the x-axis with formatted time
///
/// This draws a rounded rectangle with the formatted epoch time inside it.
/// The epoch is formatted as a readable time string.
/// If [addNeonEffect] is true, it will add a neon glow effect around the label.
void drawEpochLabel({
  required Canvas canvas,
  required EpochToX epochToX,
  required int epoch,
  required Size size,
  required TextStyle textStyle,
  double animationProgress = 1,
  Color color = Colors.white,
  Color backgroundColor = Colors.transparent,
  bool addNeonEffect = false,
  double neonOpacity = 0.4,
  double neonStrokeWidth = 8,
  double neonBlurRadius = 6,
}) {
  // Calculate X position based on the epoch
  final double xPosition = epochToX(epoch);
  final String formattedTime = ChartDateUtils.formatCompactDateTime(epoch);

  // Create text painter to measure text dimensions
  final TextPainter textPainter = _getTextPainter(
    formattedTime,
    textStyle: textStyle.copyWith(
      color: textStyle.color?.withOpacity(animationProgress),
    ),
  )..layout();

  // Create rectangle with padding around the text
  final double rectWidth = textPainter.width + 16;
  const double rectHeight = 24;
  final double rectBottom = size.height + rectHeight;
  final double rectTop = rectBottom - rectHeight;

  final Rect rect = Rect.fromLTRB(
    xPosition - rectWidth / 2,
    rectTop,
    xPosition + rectWidth / 2,
    rectBottom,
  );

  final RRect roundedRect =
      RRect.fromRectAndRadius(rect, const Radius.circular(4));

  // Draw neon effect if requested
  if (addNeonEffect) {
    final Paint neonPaint = Paint()
      ..color = color.withOpacity(neonOpacity)
      ..strokeWidth = neonStrokeWidth * animationProgress
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, neonBlurRadius);

    canvas.drawRRect(roundedRect, neonPaint);
  }

  // Draw rounded rectangle
  final Paint rectPaint = Paint()
    ..color = backgroundColor.withOpacity(animationProgress)
    ..style = PaintingStyle.fill;

  final Paint borderPaint = Paint()
    ..color = color.withOpacity(animationProgress)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  // Draw the background and border
  canvas
    ..drawRRect(roundedRect, rectPaint)
    ..drawRRect(roundedRect, borderPaint);

  // Draw the text centered in the rectangle
  textPainter.paint(
    canvas,
    Offset(
      rect.left + (rectWidth - textPainter.width) / 2,
      rect.top + (rectHeight - textPainter.height) / 2,
    ),
  );
}

/// Returns a [TextPainter] for the given formatted value and color.
TextPainter _getTextPainter(
  String formattedValue, {
  TextStyle textStyle = const TextStyle(
    color: Colors.white38,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  ),
}) {
  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: formattedValue,
      style: textStyle,
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  return textPainter;
}
