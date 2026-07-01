import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_paint_style.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/interactive_layer_states/interactive_adding_tool_state.dart';
import 'package:deriv_chart/src/theme/painting_styles/line_style.dart';
import 'package:flutter/material.dart';

import '../drawing_adding_preview.dart';
import 'ray_interactable_drawing.dart';

/// Base class for ray adding preview implementations.
///
/// Provides shared functionality for the desktop and mobile implementations,
/// including coordinate transformations, styling and the two-step point
/// creation logic.
abstract class RayAddingPreview
    extends DrawingAddingPreview<RayInteractableDrawing> {
  /// Initializes the base ray adding preview.
  RayAddingPreview({
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

  /// Draws a ray preview anchored at [start] going through [through], extended
  /// to the boundary of [size] so it looks infinite.
  void drawPreviewRay(
    Canvas canvas,
    Offset start,
    Offset through,
    Size size,
    DrawingPaintStyle paintStyle,
    LineStyle lineStyle,
  ) {
    final Offset far =
        RayInteractableDrawing.extendToBoundary(start, through, size);
    canvas.drawLine(
      start,
      far,
      paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness),
    );
  }

  /// Handles the two-step creation of the ray's defining points.
  ///
  /// The first tap sets the anchor (start) point and the second tap sets the
  /// direction (end) point, completing the ray.
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
