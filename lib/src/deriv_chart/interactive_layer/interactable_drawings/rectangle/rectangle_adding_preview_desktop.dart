import 'dart:ui';

import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/models/animation_info.dart';
import 'package:deriv_chart/src/models/chart_config.dart';
import 'package:deriv_chart/src/theme/chart_theme.dart';
import 'package:flutter/gestures.dart';

import '../../helpers/paint_helpers.dart';
import '../../helpers/types.dart';
import '../../interactive_layer_states/interactive_adding_tool_state.dart';
import 'rectangle_adding_preview.dart';

/// A class to show a preview and handle adding a
/// [RectangleInteractableDrawing] to the chart. It's for when we're on
/// [InteractiveLayerDesktopBehaviour].
///
/// On desktop the user picks the two opposite corners with two taps, with a
/// live preview of the rectangle following the pointer between the taps.
class RectangleAddingPreviewDesktop extends RectangleAddingPreview {
  /// Initializes [RectangleAddingPreviewDesktop].
  RectangleAddingPreviewDesktop({
    required super.interactiveLayerBehaviour,
    required super.interactableDrawing,
    required super.onAddingStateChange,
  }) {
    onAddingStateChange(AddingStateInfo(0, 2));
  }

  Offset? _hoverPosition;

  @override
  bool hitTest(Offset offset, EpochToX epochToX, QuoteToY quoteToY) => false;

  @override
  void onHover(PointerHoverEvent event, EpochFromX epochFromX,
      QuoteFromY quoteFromY, EpochToX epochToX, QuoteToY quoteToY) {
    _hoverPosition = event.localPosition;
  }

  @override
  String get id => 'rectangle-adding-preview-desktop';

  @override
  void paint(
    Canvas canvas,
    Size size,
    EpochToX epochToX,
    QuoteToY quoteToY,
    AnimationInfo animationInfo,
    ChartConfig chartConfig,
    ChartTheme chartTheme,
    GetDrawingState getDrawingState,
  ) {
    final (paintStyle, lineStyle) = getStyles();
    final fillStyle = interactableDrawing.config.fillStyle;
    final startPoint = interactableDrawing.startPoint;
    final endPoint = interactableDrawing.endPoint;

    if (startPoint == null) {
      // No corner placed yet, just show the alignment guides at the pointer.
      if (_hoverPosition != null) {
        drawPointAlignmentGuides(canvas, size, _hoverPosition!,
            lineColor: lineStyle.color);
      }
      return;
    }

    final startOffset = edgePointToOffset(startPoint, epochToX, quoteToY);

    drawPointOffset(
        startOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
        radius: RectangleAddingPreview.pointRadius);

    if (endPoint != null) {
      // Both corners are placed, render the final rectangle preview.
      final endOffset = edgePointToOffset(endPoint, epochToX, quoteToY);
      drawPreviewRectangle(
          canvas, startOffset, endOffset, paintStyle, lineStyle, fillStyle);
      drawPointOffset(
          endOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
          radius: RectangleAddingPreview.pointRadius);
    } else if (_hoverPosition != null) {
      // Preview the rectangle from the start corner to the current pointer.
      drawPreviewRectangle(canvas, startOffset, _hoverPosition!, paintStyle,
          lineStyle, fillStyle);
      drawPointAlignmentGuides(canvas, size, _hoverPosition!,
          lineColor: lineStyle.color);
    }
  }

  @override
  void paintOverYAxis(
    Canvas canvas,
    Size size,
    EpochToX epochToX,
    QuoteToY quoteToY,
    EpochFromX? epochFromX,
    QuoteFromY? quoteFromY,
    AnimationInfo animationInfo,
    ChartConfig chartConfig,
    ChartTheme chartTheme,
    GetDrawingState getDrawingState,
  ) {
    if (_hoverPosition == null || epochFromX == null || quoteFromY == null) {
      return;
    }

    final Color lineColor = interactableDrawing.config.lineStyle.color;

    drawValueLabel(
      canvas: canvas,
      quoteToY: quoteToY,
      value: quoteFromY(_hoverPosition!.dy),
      pipSize: chartConfig.pipSize,
      size: size,
      textStyle: interactableDrawing.config.labelStyle,
      color: lineColor,
      backgroundColor: chartTheme.backgroundColor,
    );

    drawEpochLabel(
      canvas: canvas,
      epochToX: epochToX,
      epoch: epochFromX(_hoverPosition!.dx),
      size: size,
      textStyle: interactableDrawing.config.labelStyle,
      color: lineColor,
      backgroundColor: chartTheme.backgroundColor,
    );
  }

  @override
  void onCreateTap(
    TapUpDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
    EpochToX epochToX,
    QuoteToY quoteToY,
  ) {
    createPoint(details, epochFromX, quoteFromY);
  }
}
