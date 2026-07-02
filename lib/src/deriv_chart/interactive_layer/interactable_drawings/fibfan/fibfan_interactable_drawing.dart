import 'dart:math';

import 'package:deriv_chart/src/add_ons/drawing_tools_ui/callbacks.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_config.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/fibfan/fibfan_drawing_tool_config.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_paint_style.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/vector.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/fibfan/label.dart';
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
import 'fibfan_adding_preview_desktop.dart';
import 'fibfan_adding_preview_mobile.dart';

/// Interactable drawing implementation for the Fibonacci Fan drawing tool.
///
/// A Fibonacci Fan is anchored at [startPoint] and aimed at [endPoint]. From the
/// start it draws five rays that extend infinitely towards the end direction,
/// targeting the Fibonacci ratios of the vertical distance between the two
/// points (0, 0.382, 0.5, 0.618, 1.0). Translucent triangles are filled between
/// the base ray and each of the upper rays, and each ray is labelled with its
/// Fibonacci percentage.
///
/// Draggable anchors are [startPoint] and [endPoint]; the whole fan can also be
/// dragged from its filled area.
class FibfanInteractableDrawing
    extends InteractableDrawing<FibfanDrawingToolConfig> {
  /// Initializes [FibfanInteractableDrawing].
  FibfanInteractableDrawing({
    required FibfanDrawingToolConfig config,
    required this.startPoint,
    required this.endPoint,
    required super.drawingContext,
    required super.getDrawingState,
  }) : super(drawingConfig: config);

  /// Anchor point of the fan.
  EdgePoint? startPoint;

  /// The point defining the fan's direction and spread.
  EdgePoint? endPoint;

  /// Tracks which point is being dragged, if any.
  ///
  /// [null]: dragging the whole fan.
  ///
  /// [true]: dragging the start point.
  ///
  /// [false]: dragging the end point.
  bool? isDraggingStartPoint;

  /// Fibonacci ratios of the vertical distance, from base (0) to the trend
  /// line (1). Indices align with [_fanLabels].
  static const List<double> _fanRatios = <double>[0, 0.382, 0.5, 0.618, 1];

  /// Percentage labels for each ratio in [_fanRatios].
  static const List<String> _fanLabels = <String>[
    baseVectorPercentage,
    finalInnerVectorPercentage,
    middleInnerVectorPercentage,
    initialInnerVectorPercentage,
    zeroDegreeVectorPercentage,
  ];

  /// Extends the segment [start] -> [through] far past the canvas [size] so a
  /// fan ray renders as if it were infinite in the [through] direction.
  static Offset _extend(Offset start, Offset through, Size size) {
    final double dx = through.dx - start.dx;
    final double dy = through.dy - start.dy;

    if (dx == 0 && dy == 0) {
      return through;
    }

    final double length = sqrt(dx * dx + dy * dy);
    final double farEnough = (size.width + size.height) * 2;
    final double scale = farEnough / length;

    return Offset(start.dx + dx * scale, start.dy + dy * scale);
  }

  /// Computes the far endpoints of the five fan rays for the given [start],
  /// [end] and canvas [size]. Index 0 is the base (horizontal) ray and the last
  /// is the trend-line ray.
  static List<Offset> _fanFarEnds(Offset start, Offset end, Size size) =>
      <Offset>[
        for (final double ratio in _fanRatios)
          _extend(
            start,
            Offset(end.dx, start.dy + ratio * (end.dy - start.dy)),
            size,
          ),
      ];

  /// Draws the fan itself: the filled triangles, the five rays and the
  /// percentage labels. Shared by [paint] and the adding preview.
  static void drawFan(
    Canvas canvas,
    Size size,
    Offset start,
    Offset end,
    DrawingPaintStyle paintStyle,
    LineStyle lineStyle,
    LineStyle fillStyle,
  ) {
    final List<Offset> farEnds = _fanFarEnds(start, end, size);
    final Offset base = farEnds.first;

    // Translucent triangles between the base ray and each upper ray.
    final Paint fillPaint =
        paintStyle.fillPaintStyle(fillStyle.color, fillStyle.thickness);
    for (int i = 1; i < farEnds.length; i++) {
      final Path path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(base.dx, base.dy)
        ..lineTo(farEnds[i].dx, farEnds[i].dy)
        ..close();
      canvas.drawPath(path, fillPaint);
    }

    // The five rays.
    final Paint linePaint =
        paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness);
    for (final Offset far in farEnds) {
      canvas.drawLine(start, far, linePaint);
    }

    // Percentage labels along each ray.
    final Label label = Label(
      startXCoord: start.dx.toInt(),
      endXCoord: end.dx.toInt(),
    );
    for (int i = 0; i < farEnds.length; i++) {
      label.drawLabel(
        canvas,
        size,
        lineStyle,
        _fanLabels[i],
        Vector(
            x0: start.dx, y0: start.dy, x1: farEnds[i].dx, y1: farEnds[i].dy),
      );
    }
  }

  bool _isNearSegment(Offset p, Offset a, Offset b) {
    final double length = (b - a).distance;
    if (length < 1) {
      return (p - a).distance <= hitTestMargin;
    }

    final double distance = ((b.dy - a.dy) * p.dx -
                (b.dx - a.dx) * p.dy +
                b.dx * a.dy -
                b.dy * a.dx)
            .abs() /
        length;

    final double dotProduct =
        (p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy);
    final bool withinRange = dotProduct >= 0 && dotProduct <= length * length;

    return withinRange && distance <= hitTestMargin;
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
    } else if (endDistance <= hitTestMargin) {
      isDraggingStartPoint = false;
    } else {
      // Dragging the whole fan (e.g. from the filled area).
      isDraggingStartPoint = null;
    }
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

    // Anchor handles.
    if ((offset - startOffset).distance <= hitTestMargin ||
        (offset - endOffset).distance <= hitTestMargin) {
      return true;
    }

    final List<Offset> farEnds =
        _fanFarEnds(startOffset, endOffset, drawingContext.fullSize);

    // Any of the five rays.
    for (final Offset far in farEnds) {
      if (_isNearSegment(offset, startOffset, far)) {
        return true;
      }
    }

    // The filled area (wedge between the base ray and the trend-line ray), so
    // the whole fan can be grabbed from inside it.
    final Path wedge = Path()
      ..moveTo(startOffset.dx, startOffset.dy)
      ..lineTo(farEnds.first.dx, farEnds.first.dy)
      ..lineTo(farEnds.last.dx, farEnds.last.dy)
      ..close();
    return wedge.contains(offset);
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

    // Neon glow on the rays when selected (unless dragging a single anchor).
    if (drawingState.contains(DrawingToolState.selected) &&
        !(drawingState.contains(DrawingToolState.dragging) &&
            isDraggingStartPoint != null)) {
      final Paint neonPaint = Paint()
        ..color = lineStyle.color.withOpacity(0.4)
        ..strokeWidth = 8 * animationInfo.stateChangePercent
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      for (final Offset far in _fanFarEnds(startOffset, endOffset, size)) {
        canvas.drawLine(startOffset, far, neonPaint);
      }
    }

    // The fan (triangles + rays + labels).
    drawFan(
        canvas, size, startOffset, endOffset, paintStyle, lineStyle, fillStyle);

    // Anchor handles when there's an active interaction.
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
        drawPointAlignmentGuides(
            canvas, size, isDraggingStartPoint! ? startOffset : endOffset,
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

    final double progress = animationInfo.stateChangePercent;

    drawValueLabel(
      canvas: canvas,
      quoteToY: quoteToY,
      value: startPoint!.quote,
      pipSize: chartConfig.pipSize,
      animationProgress: progress,
      size: size,
      textStyle: config.labelStyle,
      color: config.lineStyle.color,
      backgroundColor: chartTheme.backgroundColor,
    );

    if (endPoint!.quote != startPoint!.quote) {
      drawValueLabel(
        canvas: canvas,
        quoteToY: quoteToY,
        value: endPoint!.quote,
        pipSize: chartConfig.pipSize,
        animationProgress: progress,
        size: size,
        textStyle: config.labelStyle,
        color: config.lineStyle.color,
        backgroundColor: chartTheme.backgroundColor,
      );
    }

    drawEpochLabel(
      canvas: canvas,
      epochToX: epochToX,
      epoch: startPoint!.epoch,
      size: size,
      textStyle: config.labelStyle,
      animationProgress: progress,
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
        animationProgress: progress,
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
      final Offset current = Offset(
        epochToX(pointBeingDragged.epoch),
        quoteToY(pointBeingDragged.quote),
      );
      final Offset moved = current + delta;
      final EdgePoint updated = EdgePoint(
        epoch: epochFromX(moved.dx),
        quote: quoteFromY(moved.dy),
      );

      if (isDraggingStartPoint!) {
        startPoint = updated;
      } else {
        endPoint = updated;
      }
    } else {
      final Offset newStart = Offset(
            epochToX(startPoint!.epoch),
            quoteToY(startPoint!.quote),
          ) +
          delta;
      final Offset newEnd = Offset(
            epochToX(endPoint!.epoch),
            quoteToY(endPoint!.quote),
          ) +
          delta;

      startPoint = EdgePoint(
        epoch: epochFromX(newStart.dx),
        quote: quoteFromY(newStart.dy),
      );
      endPoint = EdgePoint(
        epoch: epochFromX(newEnd.dx),
        quote: quoteFromY(newEnd.dy),
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
  FibfanDrawingToolConfig getUpdatedConfig() =>
      config.copyWith(edgePoints: <EdgePoint>[
        if (startPoint != null) startPoint!,
        if (endPoint != null) endPoint!,
      ]);

  @override
  bool isInViewPort(EpochRange epochRange, QuoteRange quoteRange) =>
      // The fan extends infinitely, so its two anchor points can't reliably
      // determine viewport visibility. Since the number of tools is limited, we
      // always consider it visible.
      true;

  @override
  DrawingAddingPreview getAddingPreviewForMobileBehaviour(
    InteractiveLayerMobileBehaviour layerBehaviour,
    Function(AddingStateInfo) onAddingStateChange,
  ) =>
      FibfanAddingPreviewMobile(
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
          FibfanAddingPreviewDesktop(
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
