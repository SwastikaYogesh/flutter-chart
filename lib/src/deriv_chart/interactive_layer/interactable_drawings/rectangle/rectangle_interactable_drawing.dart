import 'package:deriv_chart/src/add_ons/drawing_tools_ui/callbacks.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_config.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/rectangle/rectangle_drawing_tool_config.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_paint_style.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/models/animation_info.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/enums/drawing_tool_state.dart';
import 'package:deriv_chart/src/models/axis_range.dart';
import 'package:deriv_chart/src/models/chart_config.dart';
import 'package:deriv_chart/src/theme/chart_theme.dart';
import 'package:deriv_chart/src/theme/painting_styles/line_style.dart';
import 'package:deriv_chart/src/widgets/color_picker/color_picker_dropdown_button.dart';
import 'package:deriv_chart/src/widgets/dropdown/line_thickness/line_thickness_dropdown_button.dart';
import 'package:flutter/material.dart';

import '../../helpers/paint_helpers.dart';
import '../../helpers/types.dart';
import '../../interactive_layer_behaviours/interactive_layer_desktop_behaviour.dart';
import '../../interactive_layer_behaviours/interactive_layer_mobile_behaviour.dart';
import '../../interactive_layer_states/interactive_adding_tool_state.dart';
import '../drawing_adding_preview.dart';
import '../drawing_v2.dart';
import '../interactable_drawing.dart';
import 'rectangle_adding_preview_desktop.dart';
import 'rectangle_adding_preview_mobile.dart';

/// Interactable drawing implementation for the rectangle drawing tool.
///
/// A rectangle is defined by two opposite corners ([startPoint] and [endPoint]).
/// This class handles rendering (fill + border), hit testing, drag interactions,
/// and state management. The user can drag either corner individually or move
/// the whole rectangle, with visual feedback and alignment guides.
class RectangleInteractableDrawing
    extends InteractableDrawing<RectangleDrawingToolConfig> {
  /// Initializes [RectangleInteractableDrawing].
  RectangleInteractableDrawing({
    required RectangleDrawingToolConfig config,
    required this.startPoint,
    required this.endPoint,
    required super.drawingContext,
    required super.getDrawingState,
  }) : super(drawingConfig: config);

  /// One corner of the rectangle.
  EdgePoint? startPoint;

  /// The opposite corner of the rectangle.
  EdgePoint? endPoint;

  /// Tracks which corner is being dragged, if any.
  ///
  /// [null]: dragging the whole rectangle.
  ///
  /// [true]: dragging the start corner.
  ///
  /// [false]: dragging the end corner.
  bool? isDraggingStartCorner;

  @override
  void onDragStart(
    DragStartDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
    EpochToX epochToX,
    QuoteToY quoteToY,
  ) {
    if (startPoint == null || endPoint == null) {
      return;
    }

    final Offset startOffset = Offset(
      epochToX(startPoint!.epoch),
      quoteToY(startPoint!.quote),
    );
    final Offset endOffset = Offset(
      epochToX(endPoint!.epoch),
      quoteToY(endPoint!.quote),
    );

    final double startDistance = (details.localPosition - startOffset).distance;
    final double endDistance = (details.localPosition - endOffset).distance;

    // If the drag starts on the start corner.
    if (startDistance <= hitTestMargin) {
      isDraggingStartCorner = true;
      return;
    }

    // If the drag starts on the end corner.
    if (endDistance <= hitTestMargin) {
      isDraggingStartCorner = false;
      return;
    }

    // Otherwise the drag is on the body/border, so we move the whole rectangle.
    isDraggingStartCorner = null;
  }

  @override
  bool hitTest(Offset offset, EpochToX epochToX, QuoteToY quoteToY) {
    if (startPoint == null || endPoint == null) {
      return false;
    }

    final Offset startOffset = Offset(
      epochToX(startPoint!.epoch),
      quoteToY(startPoint!.quote),
    );
    final Offset endOffset = Offset(
      epochToX(endPoint!.epoch),
      quoteToY(endPoint!.quote),
    );

    // Check if the pointer is near either corner first to make them easy to hit.
    if ((offset - startOffset).distance <= hitTestMargin ||
        (offset - endOffset).distance <= hitTestMargin) {
      return true;
    }

    // Check if the pointer is near the rectangle border (a band of
    // [hitTestMargin] width around the perimeter).
    final Rect rect = Rect.fromPoints(startOffset, endOffset);
    final Rect outerRect = rect.inflate(hitTestMargin);
    final Rect innerRect = rect.deflate(hitTestMargin);

    // For [innerRect], a rectangle smaller than 2 * [hitTestMargin] becomes
    // inverted (left > right), so [Rect.contains] returns false for it and the
    // whole [outerRect] area is treated as a hit, which is the desired behaviour
    // for small rectangles.
    return outerRect.contains(offset) && !innerRect.contains(offset);
  }

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
    if (startPoint == null || endPoint == null) {
      return;
    }

    final LineStyle lineStyle = config.lineStyle;
    final LineStyle fillStyle = config.fillStyle;
    final DrawingPaintStyle paintStyle = DrawingPaintStyle();
    final Set<DrawingToolState> drawingState = getDrawingState(this);

    final Offset startOffset =
        Offset(epochToX(startPoint!.epoch), quoteToY(startPoint!.quote));
    final Offset endOffset =
        Offset(epochToX(endPoint!.epoch), quoteToY(endPoint!.quote));
    final Rect rect = Rect.fromPoints(startOffset, endOffset);

    // Draw the neon glow effect first if selected, so the crisp border is drawn
    // on top of it.
    if (drawingState.contains(DrawingToolState.selected)) {
      final Paint neonPaint = Paint()
        ..color = lineStyle.color.withOpacity(0.4)
        ..strokeWidth = 8 * animationInfo.stateChangePercent
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRect(rect, neonPaint);
    }

    // Draw the semi-transparent fill and the crisp border.
    canvas
      ..drawRect(
        rect,
        paintStyle.fillPaintStyle(fillStyle.color, fillStyle.thickness),
      )
      ..drawRect(
        rect,
        paintStyle.strokeStyle(lineStyle.color, lineStyle.thickness),
      );

    // Only draw corner points when there's an active interaction.
    if (drawingState.contains(DrawingToolState.selected) ||
        drawingState.contains(DrawingToolState.hovered) ||
        drawingState.contains(DrawingToolState.dragging)) {
      drawPointOffset(
          startOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
          radius: 4);
      drawPointOffset(
          endOffset, epochToX, quoteToY, canvas, paintStyle, lineStyle,
          radius: 4);

      if (drawingState.contains(DrawingToolState.dragging) &&
          isDraggingStartCorner != null) {
        // When dragging an individual corner, only glow the dragged one.
        final Offset draggedOffset =
            isDraggingStartCorner! ? startOffset : endOffset;
        drawFocusedCircle(
          paintStyle,
          lineStyle,
          canvas,
          draggedOffset,
          10 * animationInfo.stateChangePercent,
          3 * animationInfo.stateChangePercent,
        );
      } else if ((drawingState.contains(DrawingToolState.selected) ||
              drawingState.contains(DrawingToolState.hovered)) &&
          !drawingState.contains(DrawingToolState.dragging)) {
        // When not dragging a corner, glow both corners.
        drawPointsFocusedCircle(
          paintStyle,
          lineStyle,
          canvas,
          startOffset,
          drawingState.contains(DrawingToolState.selected)
              ? 10 * animationInfo.stateChangePercent
              : 10,
          drawingState.contains(DrawingToolState.selected)
              ? 3 * animationInfo.stateChangePercent
              : 3,
          endOffset,
        );
      }
    }

    // Draw alignment guides for the dragged corner, or for both corners when
    // moving the whole rectangle.
    if (drawingState.contains(DrawingToolState.dragging)) {
      if (isDraggingStartCorner != null) {
        final Offset draggedOffset =
            isDraggingStartCorner! ? startOffset : endOffset;
        drawPointAlignmentGuides(canvas, size, draggedOffset,
            lineColor: lineStyle.color);
      } else {
        drawPointAlignmentGuides(canvas, size, startOffset,
            lineColor: lineStyle.color);
        drawPointAlignmentGuides(canvas, size, endOffset,
            lineColor: lineStyle.color);
      }
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
    if (!getDrawingState(this).contains(DrawingToolState.selected) ||
        startPoint == null ||
        endPoint == null) {
      return;
    }

    // Draw value labels for both corners on the Y-axis. Equal displayed prices
    // collapse to one label; near-equal ones don't overlap, moving only the
    // dragged corner's box.
    final ValueLabelPairLayout labelLayout = layoutValueLabelPair(
      firstQuote: startPoint!.quote,
      secondQuote: endPoint!.quote,
      quoteToY: quoteToY,
      pipSize: chartConfig.pipSize,
      isDraggingFirst: isDraggingStartCorner,
    );

    drawValueLabel(
      canvas: canvas,
      quoteToY: quoteToY,
      value: startPoint!.quote,
      pipSize: chartConfig.pipSize,
      animationProgress: animationInfo.stateChangePercent,
      size: size,
      textStyle: config.labelStyle,
      color: config.lineStyle.color,
      backgroundColor: chartTheme.backgroundColor,
      yPositionOverride: labelLayout.firstYOverride,
    );

    if (labelLayout.showSecond) {
      drawValueLabel(
        canvas: canvas,
        quoteToY: quoteToY,
        value: endPoint!.quote,
        pipSize: chartConfig.pipSize,
        animationProgress: animationInfo.stateChangePercent,
        size: size,
        textStyle: config.labelStyle,
        color: config.lineStyle.color,
        backgroundColor: chartTheme.backgroundColor,
        yPositionOverride: labelLayout.secondYOverride,
      );
    }

    // Draw epoch labels for both corners on the X-axis.
    drawEpochLabel(
      canvas: canvas,
      epochToX: epochToX,
      epoch: startPoint!.epoch,
      size: size,
      textStyle: config.labelStyle,
      animationProgress: animationInfo.stateChangePercent,
      color: config.lineStyle.color,
      backgroundColor: chartTheme.backgroundColor,
    );

    if (endPoint!.epoch != startPoint!.epoch) {
      drawEpochLabel(
        canvas: canvas,
        epochToX: epochToX,
        epoch: endPoint!.epoch,
        size: size,
        textStyle: config.labelStyle,
        animationProgress: animationInfo.stateChangePercent,
        color: config.lineStyle.color,
        backgroundColor: chartTheme.backgroundColor,
      );
    }
  }

  @override
  void onDragUpdate(
    DragUpdateDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
    EpochToX epochToX,
    QuoteToY quoteToY,
  ) {
    if (startPoint == null || endPoint == null) {
      return;
    }

    final Offset delta = details.delta;

    if (isDraggingStartCorner != null) {
      // Dragging a single corner.
      final EdgePoint pointBeingDragged =
          isDraggingStartCorner! ? startPoint! : endPoint!;

      final Offset currentOffset = Offset(
        epochToX(pointBeingDragged.epoch),
        quoteToY(pointBeingDragged.quote),
      );
      final Offset newOffset = currentOffset + delta;

      final EdgePoint updatedPoint = EdgePoint(
        epoch: epochFromX(newOffset.dx),
        quote: quoteFromY(newOffset.dy),
      );

      if (isDraggingStartCorner!) {
        startPoint = updatedPoint;
      } else {
        endPoint = updatedPoint;
      }
    } else {
      // Moving the whole rectangle.
      final Offset newStartOffset = Offset(
            epochToX(startPoint!.epoch),
            quoteToY(startPoint!.quote),
          ) +
          delta;
      final Offset newEndOffset = Offset(
            epochToX(endPoint!.epoch),
            quoteToY(endPoint!.quote),
          ) +
          delta;

      startPoint = EdgePoint(
        epoch: epochFromX(newStartOffset.dx),
        quote: quoteFromY(newStartOffset.dy),
      );
      endPoint = EdgePoint(
        epoch: epochFromX(newEndOffset.dx),
        quote: quoteFromY(newEndOffset.dy),
      );
    }
  }

  @override
  void onDragEnd(
    DragEndDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
    EpochToX epochToX,
    QuoteToY quoteToY,
  ) {
    // Reset the dragging flag when the drag is complete.
    isDraggingStartCorner = null;
  }

  @override
  RectangleDrawingToolConfig getUpdatedConfig() =>
      config.copyWith(edgePoints: <EdgePoint>[
        if (startPoint != null) startPoint!,
        if (endPoint != null) endPoint!,
      ]);

  @override
  bool isInViewPort(EpochRange epochRange, QuoteRange quoteRange) {
    if (startPoint == null || endPoint == null) {
      return true;
    }

    final int leftEpoch = startPoint!.epoch < endPoint!.epoch
        ? startPoint!.epoch
        : endPoint!.epoch;
    final int rightEpoch = startPoint!.epoch > endPoint!.epoch
        ? startPoint!.epoch
        : endPoint!.epoch;

    return rightEpoch >= epochRange.leftEpoch &&
        leftEpoch <= epochRange.rightEpoch;
  }

  @override
  DrawingAddingPreview getAddingPreviewForMobileBehaviour(
    InteractiveLayerMobileBehaviour layerBehaviour,
    Function(AddingStateInfo) onAddingStateChange,
  ) =>
      RectangleAddingPreviewMobile(
        interactiveLayerBehaviour: layerBehaviour,
        interactableDrawing: this,
        onAddingStateChange: onAddingStateChange,
      );

  @override
  DrawingAddingPreview<InteractableDrawing<DrawingToolConfig>>
      getAddingPreviewForDesktopBehaviour(
    InteractiveLayerDesktopBehaviour layerBehaviour,
    Function(AddingStateInfo) onAddingStateChange,
  ) =>
          RectangleAddingPreviewDesktop(
            interactiveLayerBehaviour: layerBehaviour,
            interactableDrawing: this,
            onAddingStateChange: onAddingStateChange,
          );

  @override
  Widget buildDrawingToolBarMenu(UpdateDrawingTool onUpdate) => Row(
        children: <Widget>[
          _buildLineThicknessIcon(onUpdate),
          const SizedBox(width: 4),
          _buildColorPickerIcon(onUpdate),
        ],
      );

  Widget _buildColorPickerIcon(UpdateDrawingTool onUpdate) => SizedBox(
        width: 32,
        height: 32,
        child: ColorPickerDropdownButton(
          currentColor: config.lineStyle.color,
          onColorChanged: (newColor) => onUpdate(config.copyWith(
            lineStyle: config.lineStyle.copyWith(color: newColor),
            fillStyle: config.fillStyle.copyWith(color: newColor),
            labelStyle: config.labelStyle.copyWith(color: newColor),
          )),
        ),
      );

  Widget _buildLineThicknessIcon(UpdateDrawingTool onUpdate) =>
      LineThicknessDropdownButton(
        thickness: config.lineStyle.thickness,
        onValueChanged: (double newValue) {
          onUpdate(config.copyWith(
            lineStyle: config.lineStyle.copyWith(thickness: newValue),
          ));
        },
      );
}
