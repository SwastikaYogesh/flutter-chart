import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_paint_style.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/interactive_layer_states/interactive_adding_tool_state.dart';
import 'package:deriv_chart/src/theme/painting_styles/line_style.dart';
import 'package:flutter/material.dart';

import '../drawing_adding_preview.dart';
import 'rectangle_interactable_drawing.dart';

/// Base class for rectangle adding preview implementations.
///
/// Provides shared functionality for the desktop and mobile implementations,
/// including coordinate transformations, styling and the two-step corner
/// creation logic.
abstract class RectangleAddingPreview
    extends DrawingAddingPreview<RectangleInteractableDrawing> {
  /// Initializes the base rectangle adding preview.
  RectangleAddingPreview({
    required super.interactiveLayerBehaviour,
    required super.interactableDrawing,
    required super.onAddingStateChange,
  });

  /// Default radius for drawing corner points.
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

  /// Draws a rectangle preview (fill + border) between two opposite corners.
  void drawPreviewRectangle(
    Canvas canvas,
    Offset startOffset,
    Offset endOffset,
    DrawingPaintStyle paintStyle,
    LineStyle lineStyle,
    LineStyle fillStyle,
  ) {
    final Rect rect = Rect.fromPoints(startOffset, endOffset);
    canvas
      ..drawRect(
        rect,
        paintStyle.fillPaintStyle(fillStyle.color, fillStyle.thickness),
      )
      ..drawRect(
        rect,
        paintStyle.strokeStyle(lineStyle.color, lineStyle.thickness),
      );
  }

  /// Handles the two-step creation of the rectangle corners.
  ///
  /// The first tap creates the start corner and the second tap creates the
  /// opposite corner, completing the rectangle.
  void createPoint(
    TapUpDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
  ) {
    if (interactableDrawing.startPoint == null) {
      interactableDrawing.startPoint = EdgePoint(
        epoch: epochFromX(details.localPosition.dx),
        quote: quoteFromY(details.localPosition.dy),
      );
      onAddingStateChange(AddingStateInfo(1, 2));
    } else {
      interactableDrawing.endPoint ??= EdgePoint(
        epoch: epochFromX(details.localPosition.dx),
        quote: quoteFromY(details.localPosition.dy),
      );
      onAddingStateChange(AddingStateInfo(2, 2));
    }
  }
}
