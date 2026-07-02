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
import 'fibfan_adding_preview.dart';

/// A class to show a preview and handle adding a
/// [FibfanInteractableDrawing] to the chart. It's for when we're on
/// [InteractiveLayerMobileBehaviour].
///
/// This mobile preview provides immediate focus mode by:
/// - Automatically placing a fan spanning the center of the chart
/// - Immediately completing the adding process for instant focus mode
/// - Delegating visual rendering to the main drawing for consistency
/// - Providing full functionality (drag the anchors or the whole fan)
class FibfanAddingPreviewMobile extends FibfanAddingPreview {
  /// Initializes [FibfanAddingPreviewMobile].
  FibfanAddingPreviewMobile({
    required super.interactiveLayerBehaviour,
    required super.interactableDrawing,
    required super.onAddingStateChange,
  }) {
    if (interactableDrawing.startPoint == null) {
      final interactiveLayer = interactiveLayerBehaviour.interactiveLayer;
      final Size size = interactiveLayer.drawingContext.fullSize;

      // Anchor lower-left, direction upper-right, so the fan spreads across the
      // chart.
      final Offset start = Offset(size.width * 0.20, size.height * 0.75);
      final Offset end = Offset(size.width * 0.60, size.height * 0.35);

      interactableDrawing
        ..startPoint = EdgePoint(
          epoch: interactiveLayer.epochFromX(start.dx),
          quote: interactiveLayer.quoteFromY(start.dy),
        )
        ..endPoint = EdgePoint(
          epoch: interactiveLayer.epochFromX(end.dx),
          quote: interactiveLayer.quoteFromY(end.dy),
        );

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
    if (interactableDrawing.startPoint != null &&
        interactableDrawing.endPoint != null) {
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
    if (interactableDrawing.startPoint == null ||
        interactableDrawing.endPoint == null) {
      final interactiveLayer = interactiveLayerBehaviour.interactiveLayer;
      final Size size = interactiveLayer.drawingContext.fullSize;

      final Offset start = Offset(size.width * 0.20, size.height * 0.75);
      final Offset end = Offset(size.width * 0.60, size.height * 0.35);

      interactableDrawing
        ..startPoint = EdgePoint(
          epoch: epochFromX(start.dx),
          quote: quoteFromY(start.dy),
        )
        ..endPoint = EdgePoint(
          epoch: epochFromX(end.dx),
          quote: quoteFromY(end.dy),
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
  String get id => 'fibfan-adding-preview-mobile';
}
