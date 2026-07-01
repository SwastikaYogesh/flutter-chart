import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_paint_style.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/interactive_layer_states/interactive_adding_tool_state.dart';
import 'package:deriv_chart/src/theme/painting_styles/line_style.dart';
import 'package:flutter/material.dart';

import '../drawing_adding_preview.dart';
import 'channel_interactable_drawing.dart';

/// Base class for channel adding preview implementations.
///
/// Provides shared functionality for the desktop and mobile implementations,
/// including coordinate transformations, styling and the three-step point
/// creation logic.
abstract class ChannelAddingPreview
    extends DrawingAddingPreview<ChannelInteractableDrawing> {
  /// Initializes the base channel adding preview.
  ChannelAddingPreview({
    required super.interactiveLayerBehaviour,
    required super.interactableDrawing,
    required super.onAddingStateChange,
  });

  /// Default radius for drawing endpoints.
  static const double pointRadius = 4;

  /// Returns the current paint style and the configured line style.
  (DrawingPaintStyle, LineStyle) getStyles() =>
      (DrawingPaintStyle(), interactableDrawing.config.lineStyle);

  /// Converts a chart coordinate [point] to screen coordinates.
  Offset edgePointToOffset(
    EdgePoint point,
    EpochToX epochToX,
    QuoteToY quoteToY,
  ) =>
      Offset(epochToX(point.epoch), quoteToY(point.quote));

  /// Draws the channel's parallelogram (fill + the two parallel lines) with the
  /// parallel line passing through the [end] point.
  void drawChannelPreview(
    Canvas canvas,
    Offset start,
    Offset middle,
    Offset end,
    DrawingPaintStyle paintStyle,
    LineStyle lineStyle,
    LineStyle fillStyle,
  ) {
    final List<Offset> corners =
        ChannelInteractableDrawing.parallelogramCorners(start, middle, end);

    canvas.drawPath(
      ChannelInteractableDrawing.parallelogramPath(corners),
      paintStyle.fillPaintStyle(fillStyle.color, fillStyle.thickness),
    );

    final Paint linePaint =
        paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness);
    canvas
      ..drawLine(corners[0], corners[1], linePaint)
      ..drawLine(corners[3], corners[2], linePaint);
  }

  /// Handles the three-step creation of the channel's defining points.
  ///
  /// Tap 1 sets the start of the base line, tap 2 sets its other end, and tap 3
  /// sets the width (the third point's epoch is aligned with the middle point).
  void createPoint(
    TapUpDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
  ) {
    final ChannelInteractableDrawing drawing = interactableDrawing;

    if (drawing.startPoint == null) {
      drawing.startPoint = EdgePoint(
        epoch: epochFromX(details.localPosition.dx),
        quote: quoteFromY(details.localPosition.dy),
      );
      onAddingStateChange(AddingStateInfo(1, 3));
    } else if (drawing.middlePoint == null) {
      drawing.middlePoint = EdgePoint(
        epoch: epochFromX(details.localPosition.dx),
        quote: quoteFromY(details.localPosition.dy),
      );
      onAddingStateChange(AddingStateInfo(2, 3));
    } else if (drawing.endPoint == null) {
      drawing.endPoint = EdgePoint(
        epoch: epochFromX(details.localPosition.dx),
        quote: quoteFromY(details.localPosition.dy),
      );
      onAddingStateChange(AddingStateInfo(3, 3));
    }
  }
}
