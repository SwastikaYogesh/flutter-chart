import 'package:deriv_chart/src/add_ons/drawing_tools_ui/callbacks.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/channel/channel_drawing_tool_config.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_config.dart';
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
import 'channel_adding_preview_desktop.dart';
import 'channel_adding_preview_mobile.dart';

/// Which vertical side (rail) of the channel is currently being dragged.
enum _ChannelEdge {
  /// The left rail: bottom-left ([startPoint]) and top-left (derived) corners.
  left,

  /// The right rail: bottom-right ([middlePoint]) and top-right ([endPoint])
  /// corners.
  right,
}

/// Interactable drawing implementation for the channel drawing tool.
///
/// A channel is two parallel lines forming a filled parallelogram, defined by
/// three points ([startPoint], [middlePoint], [endPoint]); the fourth corner is
/// derived (see [parallelogramCorners]).
///
/// The four corners behave as two rigid vertical rails:
/// - The **left rail** is bottom-left ([startPoint]) + top-left (derived).
/// - The **right rail** is bottom-right ([middlePoint]) + top-right ([endPoint]).
///
/// Dragging any corner translates the whole rail it belongs to, keeping the two
/// lines parallel and the channel width fixed.
class ChannelInteractableDrawing
    extends InteractableDrawing<ChannelDrawingToolConfig> {
  /// Initializes [ChannelInteractableDrawing].
  ChannelInteractableDrawing({
    required ChannelDrawingToolConfig config,
    required this.startPoint,
    required this.middlePoint,
    required this.endPoint,
    required super.drawingContext,
    required super.getDrawingState,
  }) : super(drawingConfig: config);

  /// Start point of the base line.
  EdgePoint? startPoint;

  /// Middle point (the other end of the base line).
  EdgePoint? middlePoint;

  /// Top-right point the parallel line passes through (right rail, top).
  EdgePoint? endPoint;

  /// Which rail is being dragged, or `null` when dragging the whole channel.
  _ChannelEdge? _draggedEdge;

  /// Computes the four parallelogram corners in screen space.
  ///
  /// The channel is a parallelogram whose base line is [start] -> [middle] and
  /// whose parallel line passes through the freely-positioned [end] point. The
  /// fourth corner is completed so opposite sides stay parallel:
  /// `topLeft = start + (end - middle)`.
  ///
  /// Returns `[start, middle, end, topLeft]` (base-left, base-right, offset,
  /// offset-left).
  static List<Offset> parallelogramCorners(
    Offset start,
    Offset middle,
    Offset end,
  ) {
    final Offset topLeft = start + (end - middle);
    return <Offset>[start, middle, end, topLeft];
  }

  /// Builds the closed parallelogram [Path] from its [corners].
  static Path parallelogramPath(List<Offset> corners) => Path()
    ..moveTo(corners[0].dx, corners[0].dy)
    ..lineTo(corners[1].dx, corners[1].dy)
    ..lineTo(corners[2].dx, corners[2].dy)
    ..lineTo(corners[3].dx, corners[3].dy)
    ..close();

  bool get _hasAllPoints =>
      startPoint != null && middlePoint != null && endPoint != null;

  Offset _toOffset(EdgePoint point, EpochToX epochToX, QuoteToY quoteToY) =>
      Offset(epochToX(point.epoch), quoteToY(point.quote));

  @override
  void onDragStart(
    DragStartDetails details,
    EpochFromX epochFromX,
    QuoteFromY quoteFromY,
    EpochToX epochToX,
    QuoteToY quoteToY,
  ) {
    if (!_hasAllPoints) {
      return;
    }

    final Offset startOffset = _toOffset(startPoint!, epochToX, quoteToY);
    final Offset middleOffset = _toOffset(middlePoint!, epochToX, quoteToY);
    final Offset endOffset = _toOffset(endPoint!, epochToX, quoteToY);
    final Offset topLeftOffset =
        parallelogramCorners(startOffset, middleOffset, endOffset)[3];

    final Offset position = details.localPosition;

    if ((position - startOffset).distance <= hitTestMargin ||
        (position - topLeftOffset).distance <= hitTestMargin) {
      _draggedEdge = _ChannelEdge.left;
    } else if ((position - middleOffset).distance <= hitTestMargin ||
        (position - endOffset).distance <= hitTestMargin) {
      _draggedEdge = _ChannelEdge.right;
    } else {
      // Dragging the whole channel.
      _draggedEdge = null;
    }
  }

  @override
  bool hitTest(Offset offset, EpochToX epochToX, QuoteToY quoteToY) {
    if (!_hasAllPoints) {
      return false;
    }

    final Offset startOffset = _toOffset(startPoint!, epochToX, quoteToY);
    final Offset middleOffset = _toOffset(middlePoint!, epochToX, quoteToY);
    final Offset endOffset = _toOffset(endPoint!, epochToX, quoteToY);

    final List<Offset> corners =
        parallelogramCorners(startOffset, middleOffset, endOffset);

    for (final Offset corner in corners) {
      if ((offset - corner).distance <= hitTestMargin) {
        return true;
      }
    }

    return parallelogramPath(corners).contains(offset);
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
    if (!_hasAllPoints) {
      return;
    }

    final LineStyle lineStyle = config.lineStyle;
    final LineStyle fillStyle = config.fillStyle;
    final DrawingPaintStyle paintStyle = DrawingPaintStyle();
    final Set<DrawingToolState> drawingState = getDrawingState(this);

    final Offset startOffset = _toOffset(startPoint!, epochToX, quoteToY);
    final Offset middleOffset = _toOffset(middlePoint!, epochToX, quoteToY);
    final Offset endOffset = _toOffset(endPoint!, epochToX, quoteToY);

    final List<Offset> corners =
        parallelogramCorners(startOffset, middleOffset, endOffset);
    final Offset bottomLeft = corners[0];
    final Offset bottomRight = corners[1];
    final Offset topRight = corners[2];
    final Offset topLeft = corners[3];

    // Corner groups per rail.
    final List<Offset> leftRail = <Offset>[bottomLeft, topLeft];
    final List<Offset> rightRail = <Offset>[bottomRight, topRight];

    // Neon glow first (unless dragging a single rail), then crisp lines.
    if (drawingState.contains(DrawingToolState.selected) &&
        !(drawingState.contains(DrawingToolState.dragging) &&
            _draggedEdge != null)) {
      final Paint neonPaint = Paint()
        ..color = lineStyle.color.withOpacity(0.4)
        ..strokeWidth = 8 * animationInfo.stateChangePercent
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas
        ..drawLine(bottomLeft, bottomRight, neonPaint)
        ..drawLine(topLeft, topRight, neonPaint);
    }

    // Translucent fill and the two parallel lines.
    canvas.drawPath(
      parallelogramPath(corners),
      paintStyle.fillPaintStyle(fillStyle.color, fillStyle.thickness),
    );
    final Paint linePaint =
        paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness);
    canvas
      ..drawLine(bottomLeft, bottomRight, linePaint)
      ..drawLine(topLeft, topRight, linePaint);

    // Handles when there's an active interaction.
    if (drawingState.contains(DrawingToolState.selected) ||
        drawingState.contains(DrawingToolState.hovered) ||
        drawingState.contains(DrawingToolState.dragging)) {
      for (final Offset corner in corners) {
        drawPointOffset(
            corner, epochToX, quoteToY, canvas, paintStyle, lineStyle,
            radius: 4);
      }

      if (drawingState.contains(DrawingToolState.dragging) &&
          _draggedEdge != null) {
        // Glow both corners of the rail being dragged.
        final List<Offset> rail =
            _draggedEdge == _ChannelEdge.left ? leftRail : rightRail;
        for (final Offset corner in rail) {
          drawFocusedCircle(
            paintStyle,
            lineStyle,
            canvas,
            corner,
            10 * animationInfo.stateChangePercent,
            3 * animationInfo.stateChangePercent,
          );
        }
      } else if ((drawingState.contains(DrawingToolState.selected) ||
              drawingState.contains(DrawingToolState.hovered)) &&
          !drawingState.contains(DrawingToolState.dragging)) {
        final bool selected = drawingState.contains(DrawingToolState.selected);
        final double outer =
            selected ? 10 * animationInfo.stateChangePercent : 10;
        final double inner =
            selected ? 3 * animationInfo.stateChangePercent : 3;
        for (final Offset corner in corners) {
          drawFocusedCircle(
              paintStyle, lineStyle, canvas, corner, outer, inner);
        }
      }
    }

    // Alignment guides while dragging.
    if (drawingState.contains(DrawingToolState.dragging)) {
      final List<Offset> guided = _draggedEdge == null
          ? corners
          : (_draggedEdge == _ChannelEdge.left ? leftRail : rightRail);
      for (final Offset corner in guided) {
        drawPointAlignmentGuides(canvas, size, corner,
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
        !_hasAllPoints) {
      return;
    }

    final double progress = animationInfo.stateChangePercent;

    // Value labels (Y-axis) for the three distinct quote levels.
    final Set<double> seenQuotes = <double>{};
    for (final EdgePoint point in <EdgePoint>[
      startPoint!,
      middlePoint!,
      endPoint!
    ]) {
      if (seenQuotes.add(point.quote)) {
        drawValueLabel(
          canvas: canvas,
          quoteToY: quoteToY,
          value: point.quote,
          pipSize: chartConfig.pipSize,
          animationProgress: progress,
          size: size,
          textStyle: config.labelStyle,
          color: config.lineStyle.color,
          backgroundColor: chartTheme.backgroundColor,
        );
      }
    }

    // Epoch labels (X-axis) for the three distinct point epochs.
    final Set<int> seenEpochs = <int>{};
    for (final EdgePoint point in <EdgePoint>[
      startPoint!,
      middlePoint!,
      endPoint!
    ]) {
      if (seenEpochs.add(point.epoch)) {
        drawEpochLabel(
          canvas: canvas,
          epochToX: epochToX,
          epoch: point.epoch,
          size: size,
          textStyle: config.labelStyle,
          animationProgress: progress,
          color: config.lineStyle.color,
          backgroundColor: chartTheme.backgroundColor,
        );
      }
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
    if (!_hasAllPoints) {
      return;
    }

    final Offset delta = details.delta;
    final Offset startOffset = _toOffset(startPoint!, epochToX, quoteToY);
    final Offset middleOffset = _toOffset(middlePoint!, epochToX, quoteToY);
    final Offset endOffset = _toOffset(endPoint!, epochToX, quoteToY);

    EdgePoint movedPoint(Offset current) {
      final Offset moved = current + delta;
      return EdgePoint(
        epoch: epochFromX(moved.dx),
        quote: quoteFromY(moved.dy),
      );
    }

    switch (_draggedEdge) {
      case _ChannelEdge.left:
        // Move the left rail: shifting `start` also shifts the derived top-left
        // corner, so both left corners translate together.
        startPoint = movedPoint(startOffset);
        break;
      case _ChannelEdge.right:
        // Move the right rail: shift both bottom-right and top-right together,
        // which keeps the derived top-left (and the width) unchanged.
        middlePoint = movedPoint(middleOffset);
        endPoint = movedPoint(endOffset);
        break;
      case null:
        // Move the whole channel.
        startPoint = movedPoint(startOffset);
        middlePoint = movedPoint(middleOffset);
        endPoint = movedPoint(endOffset);
        break;
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
    _draggedEdge = null;
  }

  @override
  ChannelDrawingToolConfig getUpdatedConfig() =>
      config.copyWith(edgePoints: <EdgePoint>[
        if (startPoint != null) startPoint!,
        if (middlePoint != null) middlePoint!,
        if (endPoint != null) endPoint!,
      ]);

  @override
  bool isInViewPort(EpochRange epochRange, QuoteRange quoteRange) {
    if (startPoint == null || middlePoint == null) {
      return true;
    }

    final int leftEpoch = startPoint!.epoch < middlePoint!.epoch
        ? startPoint!.epoch
        : middlePoint!.epoch;
    final int rightEpoch = startPoint!.epoch > middlePoint!.epoch
        ? startPoint!.epoch
        : middlePoint!.epoch;

    return rightEpoch >= epochRange.leftEpoch &&
        leftEpoch <= epochRange.rightEpoch;
  }

  @override
  DrawingAddingPreview getAddingPreviewForMobileBehaviour(
    InteractiveLayerMobileBehaviour layerBehaviour,
    Function(AddingStateInfo) onAddingStateChange,
  ) =>
      ChannelAddingPreviewMobile(
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
          ChannelAddingPreviewDesktop(
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
