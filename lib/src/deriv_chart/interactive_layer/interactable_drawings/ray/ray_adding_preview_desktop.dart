import 'dart:ui';

import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/models/animation_info.dart';
import 'package:deriv_chart/src/models/chart_config.dart';
import 'package:deriv_chart/src/theme/chart_theme.dart';
import 'package:flutter/gestures.dart';

import '../../helpers/paint_helpers.dart';
import '../../helpers/types.dart';
import '../../interactive_layer_states/interactive_adding_tool_state.dart';
import 'ray_adding_preview.dart';

/// A class to show a preview and handle adding a
/// [RayInteractableDrawing] to the chart. It's for when we're on
/// [InteractiveLayerDesktopBehaviour].
///
/// On desktop the user picks the anchor and the direction with two taps, with a
/// live preview of the ray following the pointer between the taps.
class RayAddingPreviewDesktop extends RayAddingPreview {
  /// Initializes [RayAddingPreviewDesktop].
  RayAddingPreviewDesktop({
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
  String get id => 'ray-adding-preview-desktop';

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
    final startPoint = interactableDrawing.startPoint;
    final endPoint = interactableDrawing.endPoint;

    if (startPoint == null) {
      // No anchor placed yet, just show alignment guides at the pointer.
      if (_hoverPosition != null) {
        drawPointAlignmentGuides(canvas, size, _hoverPosition!,
            lineColor: lineStyle.color);
      }
      return;
    }

    final startOffset = edgePointToOffset(startPoint, epochToX, quoteToY);

    drawPointOffset(
        startOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
        radius: RayAddingPreview.pointRadius);

    if (endPoint != null) {
      final endOffset = edgePointToOffset(endPoint, epochToX, quoteToY);
      drawPreviewRay(
          canvas, startOffset, endOffset, size, paintStyle, lineStyle);
      drawPointOffset(
          endOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
          radius: RayAddingPreview.pointRadius);
    } else if (_hoverPosition != null) {
      // Preview the ray from the anchor through the current pointer.
      drawPreviewRay(
          canvas, startOffset, _hoverPosition!, size, paintStyle, lineStyle);
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
