import 'dart:math';

import 'package:deriv_chart/src/add_ons/drawing_tools_ui/callbacks.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_config.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/ray/ray_drawing_tool_config.dart';
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
import 'ray_adding_preview_desktop.dart';
import 'ray_adding_preview_mobile.dart';

/// Interactable drawing implementation for the ray drawing tool.
///
/// A ray is anchored at [startPoint] and passes through [endPoint], extending
/// infinitely past [endPoint]. This class handles rendering, hit testing, drag
/// interactions (either endpoint or the whole ray) and state management with
/// visual feedback and alignment guides.
class RayInteractableDrawing extends InteractableDrawing<RayDrawingToolConfig> {
  /// Initializes [RayInteractableDrawing].
  RayInteractableDrawing({
    required RayDrawingToolConfig config,
    required this.startPoint,
    required this.endPoint,
    required super.drawingContext,
    required super.getDrawingState,
  }) : super(drawingConfig: config);

  /// Anchor point of the ray (fixed origin).
  EdgePoint? startPoint;

  /// The point defining the direction of the ray. The ray extends past this
  /// point to infinity.
  EdgePoint? endPoint;

  /// Tracks which point is being dragged, if any.
  ///
  /// [null]: dragging the whole ray.
  ///
  /// [true]: dragging the start point.
  ///
  /// [false]: dragging the end point.
  bool? isDraggingStartPoint;

  /// Extends the segment [start] -> [through] far beyond the canvas [size] so
  /// the ray renders as if it were infinite in the [through] direction.
  ///
  /// [start] stays fixed; only the far end is projected outward.
  static Offset extendToBoundary(Offset start, Offset through, Size size) {
    final double dx = through.dx - start.dx;
    final double dy = through.dy - start.dy;

    if (dx == 0 && dy == 0) {
      return through;
    }

    final double length = sqrt(dx * dx + dy * dy);
    // A distance large enough to always leave the visible canvas.
    final double farEnough = (size.width + size.height) * 2;
    final double scale = farEnough / length;

    return Offset(start.dx + dx * scale, start.dy + dy * scale);
  }

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

    if (startDistance <= hitTestMargin) {
      isDraggingStartPoint = true;
      return;
    }

    if (endDistance <= hitTestMargin) {
      isDraggingStartPoint = false;
      return;
    }

    // Otherwise we're dragging the whole ray.
    isDraggingStartPoint = null;
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

    // Endpoints are easy-to-hit handles.
    if ((offset - startOffset).distance <= hitTestMargin ||
        (offset - endOffset).distance <= hitTestMargin) {
      return true;
    }

    // Hit test against the extended ray segment (start -> far end).
    final Offset farOffset =
        extendToBoundary(startOffset, endOffset, drawingContext.fullSize);

    final double rayLength = (farOffset - startOffset).distance;
    if (rayLength < 1) {
      return (offset - startOffset).distance <= hitTestMargin;
    }

    // Perpendicular distance from the point to the (infinite) line.
    final double distance = ((farOffset.dy - startOffset.dy) * offset.dx -
                (farOffset.dx - startOffset.dx) * offset.dy +
                farOffset.dx * startOffset.dy -
                farOffset.dy * startOffset.dx)
            .abs() /
        rayLength;

    // Ensure the point projects onto the ray (from the start onwards).
    final double dotProduct =
        (offset.dx - startOffset.dx) * (farOffset.dx - startOffset.dx) +
            (offset.dy - startOffset.dy) * (farOffset.dy - startOffset.dy);

    final bool isWithinRange =
        dotProduct >= 0 && dotProduct <= rayLength * rayLength;

    return isWithinRange && distance <= hitTestMargin;
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
    final DrawingPaintStyle paintStyle = DrawingPaintStyle();
    final Set<DrawingToolState> drawingState = getDrawingState(this);

    final Offset startOffset =
        Offset(epochToX(startPoint!.epoch), quoteToY(startPoint!.quote));
    final Offset endOffset =
        Offset(epochToX(endPoint!.epoch), quoteToY(endPoint!.quote));
    final Offset farOffset = extendToBoundary(startOffset, endOffset, size);

    // Draw the neon glow first (unless dragging a single point), then the crisp
    // line on top.
    if (drawingState.contains(DrawingToolState.selected) &&
        !(drawingState.contains(DrawingToolState.dragging) &&
            isDraggingStartPoint != null)) {
      final Paint neonPaint = Paint()
        ..color = lineStyle.color.withOpacity(0.4)
        ..strokeWidth = 8 * animationInfo.stateChangePercent
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(startOffset, farOffset, neonPaint);
    }

    final Paint paint =
        paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness);
    canvas.drawLine(startOffset, farOffset, paint);

    // Draw the endpoints only when there's an active interaction.
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
          isDraggingStartPoint != null) {
        final Offset draggedOffset =
            isDraggingStartPoint! ? startOffset : endOffset;
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

    // Alignment guides while dragging.
    if (drawingState.contains(DrawingToolState.dragging)) {
      if (isDraggingStartPoint != null) {
        final Offset draggedOffset =
            isDraggingStartPoint! ? startOffset : endOffset;
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

    // Value labels (Y-axis) for both defining points. Equal displayed prices
    // collapse to one label; near-equal ones don't overlap, moving only the
    // dragged point's box.
    final ValueLabelPairLayout labelLayout = layoutValueLabelPair(
      firstQuote: startPoint!.quote,
      secondQuote: endPoint!.quote,
      quoteToY: quoteToY,
      pipSize: chartConfig.pipSize,
      isDraggingFirst: isDraggingStartPoint,
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

    // Epoch labels (X-axis) for both defining points.
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

    if (isDraggingStartPoint != null) {
      final EdgePoint pointBeingDragged =
          isDraggingStartPoint! ? startPoint! : endPoint!;

      final Offset currentOffset = Offset(
        epochToX(pointBeingDragged.epoch),
        quoteToY(pointBeingDragged.quote),
      );
      final Offset newOffset = currentOffset + delta;

      final EdgePoint updatedPoint = EdgePoint(
        epoch: epochFromX(newOffset.dx),
        quote: quoteFromY(newOffset.dy),
      );

      if (isDraggingStartPoint!) {
        startPoint = updatedPoint;
      } else {
        endPoint = updatedPoint;
      }
    } else {
      // Move the whole ray.
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
    isDraggingStartPoint = null;
  }

  @override
  RayDrawingToolConfig getUpdatedConfig() =>
      config.copyWith(edgePoints: <EdgePoint>[
        if (startPoint != null) startPoint!,
        if (endPoint != null) endPoint!,
      ]);

  @override
  bool isInViewPort(EpochRange epochRange, QuoteRange quoteRange) =>
      // A ray is infinite in the end direction, so a simple check on the two
      // defining points can't reliably tell whether its visible part is in the
      // viewport. Since the number of drawing tools is limited, we always
      // consider it visible.
      true;

  @override
  DrawingAddingPreview getAddingPreviewForMobileBehaviour(
    InteractiveLayerMobileBehaviour layerBehaviour,
    Function(AddingStateInfo) onAddingStateChange,
  ) =>
      RayAddingPreviewMobile(
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
          RayAddingPreviewDesktop(
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
