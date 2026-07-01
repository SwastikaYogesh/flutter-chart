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
import 'rectangle_adding_preview.dart';

/// A class to show a preview and handle adding a
/// [RectangleInteractableDrawing] to the chart. It's for when we're on
/// [InteractiveLayerMobileBehaviour].
///
/// This mobile preview provides immediate focus mode by:
/// - Automatically placing a rectangle in the center of the chart
/// - Immediately completing the adding process for instant focus mode
/// - Delegating visual rendering to the main drawing for consistency
/// - Providing full functionality (drag corners or the whole rectangle)
class RectangleAddingPreviewMobile extends RectangleAddingPreview {
  /// Initializes [RectangleAddingPreviewMobile].
  RectangleAddingPreviewMobile({
    required super.interactiveLayerBehaviour,
    required super.interactableDrawing,
    required super.onAddingStateChange,
  }) {
    if (interactableDrawing.startPoint == null) {
      final interactiveLayer = interactiveLayerBehaviour.interactiveLayer;
      final Size size = interactiveLayer.drawingContext.fullSize;

      // Position the rectangle to span the center of the chart.
      final Offset startCenter = Offset(size.width * 0.3, size.height * 0.3);
      final Offset endCenter = Offset(size.width * 0.7, size.height * 0.7);

      interactableDrawing
        ..startPoint = EdgePoint(
          epoch: interactiveLayer.epochFromX(startCenter.dx),
          quote: interactiveLayer.quoteFromY(startCenter.dy),
        )
        ..endPoint = EdgePoint(
          epoch: interactiveLayer.epochFromX(endCenter.dx),
          quote: interactiveLayer.quoteFromY(endCenter.dy),
        );

      // Use a post-frame callback to ensure the points are fully set before
      // transitioning. Check if the widget is still mounted to prevent race
      // conditions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (interactiveLayerBehaviour.interactiveLayer.isStillMounted &&
            interactableDrawing.startPoint != null &&
            interactableDrawing.endPoint != null) {
          onAddingStateChange(AddingStateInfo(1, 1));
        }
      });
    }
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
    // Only paint if we have valid corners.
    if (interactableDrawing.startPoint != null &&
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
    // Only paint if we have valid corners.
    if (interactableDrawing.startPoint != null &&
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
    // Since we complete the adding process in the constructor, this is mainly
    // for consistency with the interface. If for some reason the corners are
    // not set, place a default centered rectangle.
    if (interactableDrawing.startPoint == null ||
        interactableDrawing.endPoint == null) {
      final interactiveLayer = interactiveLayerBehaviour.interactiveLayer;
      final Size size = interactiveLayer.drawingContext.fullSize;

      final Offset startCenter = Offset(size.width * 0.3, size.height * 0.3);
      final Offset endCenter = Offset(size.width * 0.7, size.height * 0.7);

      interactableDrawing
        ..startPoint = EdgePoint(
          epoch: epochFromX(startCenter.dx),
          quote: quoteFromY(startCenter.dy),
        )
        ..endPoint = EdgePoint(
          epoch: epochFromX(endCenter.dx),
          quote: quoteFromY(endCenter.dy),
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
  String get id => 'rectangle-adding-preview-mobile';
}
