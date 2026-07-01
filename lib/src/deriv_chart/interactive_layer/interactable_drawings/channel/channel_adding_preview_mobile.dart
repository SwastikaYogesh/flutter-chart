import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/models/animation_info.dart';
import 'package:deriv_chart/src/models/chart_config.dart';
import 'package:deriv_chart/src/theme/chart_theme.dart';
import 'package:flutter/material.dart';

import '../../enums/drawing_tool_state.dart';
import '../../helpers/types.dart';
import '../../interactive_layer_states/interactive_adding_tool_state.dart';
import '../drawing_v2.dart';
import 'channel_adding_preview.dart';

/// A class to show a preview and handle adding a
/// [ChannelInteractableDrawing] to the chart. It's for when we're on
/// [InteractiveLayerMobileBehaviour].
///
/// This mobile preview provides immediate focus mode by:
/// - Automatically placing a channel spanning the center of the chart
/// - Immediately completing the adding process for instant focus mode
/// - Delegating visual rendering to the main drawing for consistency
/// - Providing full functionality (drag the three handles or the whole channel)
class ChannelAddingPreviewMobile extends ChannelAddingPreview {
  /// Initializes [ChannelAddingPreviewMobile].
  ChannelAddingPreviewMobile({
    required super.interactiveLayerBehaviour,
    required super.interactableDrawing,
    required super.onAddingStateChange,
  }) {
    if (interactableDrawing.startPoint == null) {
      final interactiveLayer = interactiveLayerBehaviour.interactiveLayer;
      final Size size = interactiveLayer.drawingContext.fullSize;

      _placeDefaultPoints(
        size,
        interactiveLayer.epochFromX,
        interactiveLayer.quoteFromY,
      );

      // Use a post-frame callback to ensure the points are fully set before
      // transitioning. Check if the widget is still mounted to prevent race
      // conditions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (interactiveLayerBehaviour.interactiveLayer.isStillMounted &&
            interactableDrawing.startPoint != null &&
            interactableDrawing.middlePoint != null &&
            interactableDrawing.endPoint != null) {
          onAddingStateChange(AddingStateInfo(1, 1));
        }
      });
    }
  }

  void _placeDefaultPoints(
    Size size,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
  ) {
    final Offset start = Offset(size.width * 0.25, size.height * 0.60);
    final Offset middle = Offset(size.width * 0.60, size.height * 0.50);
    final double offsetY = size.height * 0.35;

    final EdgePoint middlePoint = EdgePoint(
      epoch: epochFromX(middle.dx),
      quote: quoteFromY(middle.dy),
    );

    interactableDrawing
      ..startPoint = EdgePoint(
        epoch: epochFromX(start.dx),
        quote: quoteFromY(start.dy),
      )
      ..middlePoint = middlePoint
      // The offset point shares the middle point's epoch; only its quote (the
      // channel width) is meaningful.
      ..endPoint = EdgePoint(
        epoch: middlePoint.epoch,
        quote: quoteFromY(offsetY),
      );
  }

  @override
  bool hitTest(Offset offset, EpochToX epochToX, QuoteToY quoteToY) =>
      interactableDrawing.hitTest(offset, epochToX, quoteToY);

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
    if (interactableDrawing.startPoint != null &&
        interactableDrawing.middlePoint != null &&
        interactableDrawing.endPoint != null) {
      // Delegate to the main drawing with a selected state simulation for the
      // full visual appearance.
      Set<DrawingToolState> mockGetDrawingState(DrawingV2 drawing) =>
          {DrawingToolState.selected};

      interactableDrawing.paint(
        canvas,
        size,
        epochToX,
        quoteToY,
        animationInfo,
        chartConfig,
        chartTheme,
        mockGetDrawingState,
      );
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
    if (interactableDrawing.startPoint != null &&
        interactableDrawing.middlePoint != null &&
        interactableDrawing.endPoint != null) {
      Set<DrawingToolState> mockGetDrawingState(DrawingV2 drawing) =>
          {DrawingToolState.selected};

      interactableDrawing.paintOverYAxis(
        canvas,
        size,
        epochToX,
        quoteToY,
        epochFromX,
        quoteFromY,
        animationInfo,
        chartConfig,
        chartTheme,
        mockGetDrawingState,
      );
    }
  }

  @override
  void onCreateTap(
    TapUpDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
    EpochToX epochToX,
    QuoteToY quoteToY,
  ) {
    // Adding completes in the constructor; this is mainly for interface
    // consistency. If for some reason the points are not set, place a default
    // centered channel.
    if (interactableDrawing.startPoint == null ||
        interactableDrawing.middlePoint == null ||
        interactableDrawing.endPoint == null) {
      final interactiveLayer = interactiveLayerBehaviour.interactiveLayer;
      _placeDefaultPoints(
        interactiveLayer.drawingContext.fullSize,
        epochFromX,
        quoteFromY,
      );
    }

    onAddingStateChange(AddingStateInfo(1, 1));
  }

  @override
  void onDragStart(DragStartDetails details, EpochFromX epochFromX,
          QuoteFromY quoteFromY, EpochToX epochToX, QuoteToY quoteToY) =>
      interactableDrawing.onDragStart(
          details, epochFromX, quoteFromY, epochToX, quoteToY);

  @override
  void onDragUpdate(DragUpdateDetails details, EpochFromX epochFromX,
          QuoteFromY quoteFromY, EpochToX epochToX, QuoteToY quoteToY) =>
      interactableDrawing.onDragUpdate(
          details, epochFromX, quoteFromY, epochToX, quoteToY);

  @override
  void onDragEnd(DragEndDetails details, EpochFromX epochFromX,
          QuoteFromY quoteFromY, EpochToX epochToX, QuoteToY quoteToY) =>
      interactableDrawing.onDragEnd(
          details, epochFromX, quoteFromY, epochToX, quoteToY);

  @override
  bool shouldRepaint(
          Set<DrawingToolState> drawingState, DrawingV2 oldDrawing) =>
      true;

  @override
  String get id => 'channel-adding-preview-mobile';
}
