import 'dart:ui';

import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/models/animation_info.dart';
import 'package:deriv_chart/src/models/chart_config.dart';
import 'package:deriv_chart/src/theme/chart_theme.dart';
import 'package:flutter/gestures.dart';

import '../../helpers/paint_helpers.dart';
import '../../helpers/types.dart';
import '../../interactive_layer_states/interactive_adding_tool_state.dart';
import 'channel_adding_preview.dart';

/// A class to show a preview and handle adding a
/// [ChannelInteractableDrawing] to the chart. It's for when we're on
/// [InteractiveLayerDesktopBehaviour].
///
/// The channel is created with three taps: the base line's two ends, then the
/// width. A live preview follows the pointer between taps.
class ChannelAddingPreviewDesktop extends ChannelAddingPreview {
  /// Initializes [ChannelAddingPreviewDesktop].
  ChannelAddingPreviewDesktop({
    required super.interactiveLayerBehaviour,
    required super.interactableDrawing,
    required super.onAddingStateChange,
  }) {
    onAddingStateChange(AddingStateInfo(0, 3));
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
  String get id => 'channel-adding-preview-desktop';

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
    final middlePoint = interactableDrawing.middlePoint;

    if (startPoint == null) {
      // Nothing placed yet, show alignment guides at the pointer.
      if (_hoverPosition != null) {
        drawPointAlignmentGuides(canvas, size, _hoverPosition!,
            lineColor: lineStyle.color);
      }
      return;
    }

    final startOffset = edgePointToOffset(startPoint, epochToX, quoteToY);
    drawPointOffset(
        startOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
        radius: ChannelAddingPreview.pointRadius);

    if (middlePoint == null) {
      // Placing the base line: preview from start to the pointer.
      if (_hoverPosition != null) {
        canvas.drawLine(startOffset, _hoverPosition!,
            paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness));
        drawPointAlignmentGuides(canvas, size, _hoverPosition!,
            lineColor: lineStyle.color);
      }
      return;
    }

    final middleOffset = edgePointToOffset(middlePoint, epochToX, quoteToY);

    // Base line is fixed; preview the parallel line following the pointer. The
    // top-right point keeps the middle point's timestamp (vertical right rail),
    // so only the pointer's vertical position matters.
    if (_hoverPosition != null) {
      final Offset previewEnd = Offset(middleOffset.dx, _hoverPosition!.dy);
      drawChannelPreview(canvas, startOffset, middleOffset, previewEnd,
          paintStyle, lineStyle, fillStyle);
      drawPointAlignmentGuides(canvas, size, previewEnd,
          lineColor: lineStyle.color);
    } else {
      // No hover yet: just show the base line.
      canvas.drawLine(startOffset, middleOffset,
          paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness));
    }

    drawPointOffset(
        middleOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
        radius: ChannelAddingPreview.pointRadius);
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
