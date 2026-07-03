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

/// Which handle of the channel is currently being dragged.
enum _ChannelHandle {
  /// The left rail: bottom-left ([startPoint]) and top-left (derived) corners.
  leftRail,

  /// The right rail: bottom-right ([middlePoint]) and top-right ([endPoint])
  /// corners.
  rightRail,

  /// The derived midpoint of the top line. Dragging it moves both top corners
  /// vertically to adjust the channel width.
  topCenter,

  /// The derived midpoint of the bottom line. Dragging it moves both bottom
  /// corners vertically to adjust the channel width.
  bottomCenter,
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
/// Each rail is vertical: both of its corners share the same timestamp (so
/// [endPoint] always keeps [middlePoint]'s epoch). Dragging any corner
/// translates the whole rail it belongs to, keeping the two lines parallel and
/// the channel width fixed.
///
/// Two derived midpoint handles (top-line center and bottom-line center) let the
/// user set the channel width: dragging one moves both corners of that line
/// vertically, keeping the lines parallel and the rails vertical.
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

  /// Which handle is being dragged, or `null` when dragging the whole channel.
  _ChannelHandle? _draggedHandle;

  /// Index into the parallelogram corners (0=bottom-left, 1=bottom-right,
  /// 2=top-right, 3=top-left) of the specific rail corner grabbed. `null` when
  /// dragging a center handle or the whole channel. Used so alignment guides
  /// follow only the grabbed corner, not the corner that moves with it.
  int? _draggedCornerIndex;

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

  /// Returns the derived midpoint handles `[topCenter, bottomCenter]` from the
  /// parallelogram [corners] (`[bottomLeft, bottomRight, topRight, topLeft]`).
  static List<Offset> lineCenters(List<Offset> corners) {
    final Offset topCenter = (corners[3] + corners[2]) / 2;
    final Offset bottomCenter = (corners[0] + corners[1]) / 2;
    return <Offset>[topCenter, bottomCenter];
  }

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
    final List<Offset> corners =
        parallelogramCorners(startOffset, middleOffset, endOffset);
    final List<Offset> centers = lineCenters(corners);

    // Which screen offsets activate each handle. Insertion order gives corners
    // precedence over the line-center handles when distances tie.
    final Map<_ChannelHandle, List<Offset>> handleOffsets =
        <_ChannelHandle, List<Offset>>{
      _ChannelHandle.leftRail: <Offset>[corners[0], corners[3]],
      _ChannelHandle.rightRail: <Offset>[corners[1], corners[2]],
      _ChannelHandle.topCenter: <Offset>[centers[0]],
      _ChannelHandle.bottomCenter: <Offset>[centers[1]],
    };

    // Grab the nearest handle within [hitTestMargin]; otherwise drag the whole
    // channel. Picking the nearest (rather than first match) keeps the two
    // line-center handles distinct even on a narrow channel.
    final Offset position = details.localPosition;
    _ChannelHandle? nearest;
    double bestDistance = double.infinity;
    handleOffsets.forEach((_ChannelHandle handle, List<Offset> offsets) {
      for (final Offset o in offsets) {
        final double distance = (position - o).distance;
        if (distance <= hitTestMargin && distance < bestDistance) {
          bestDistance = distance;
          nearest = handle;
        }
      }
    });

    _draggedHandle = nearest;

    // For a rail, remember which of its two corners the user actually grabbed
    // so the alignment guides follow only that corner. Cleared for the center
    // handles and whole-channel drags.
    if (nearest == _ChannelHandle.leftRail) {
      _draggedCornerIndex =
          (position - corners[0]).distance <= (position - corners[3]).distance
              ? 0
              : 3;
    } else if (nearest == _ChannelHandle.rightRail) {
      _draggedCornerIndex =
          (position - corners[1]).distance <= (position - corners[2]).distance
              ? 1
              : 2;
    } else {
      _draggedCornerIndex = null;
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

    // The 4 corner handles and the 2 derived line-center (width) handles. The
    // centers sit on the parallelogram's edges, where [Path.contains] is
    // unreliable, so they must be hit-tested explicitly.
    for (final Offset handle in <Offset>[...corners, ...lineCenters(corners)]) {
      if ((offset - handle).distance <= hitTestMargin) {
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

    // Corner groups per rail and the derived width handles.
    final List<Offset> leftRail = <Offset>[bottomLeft, topLeft];
    final List<Offset> rightRail = <Offset>[bottomRight, topRight];
    final List<Offset> centers = lineCenters(corners);

    // The offsets highlighted (glow + alignment guides) for a given handle.
    List<Offset> handleTargets(_ChannelHandle handle) {
      switch (handle) {
        case _ChannelHandle.leftRail:
          return leftRail;
        case _ChannelHandle.rightRail:
          return rightRail;
        case _ChannelHandle.topCenter:
          return <Offset>[centers[0]];
        case _ChannelHandle.bottomCenter:
          return <Offset>[centers[1]];
      }
    }

    // Neon glow first (unless dragging a single handle), then crisp lines.
    if (drawingState.contains(DrawingToolState.selected) &&
        !(drawingState.contains(DrawingToolState.dragging) &&
            _draggedHandle != null)) {
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
      // Corner handles and the two derived width handles.
      for (final Offset handle in <Offset>[...corners, ...centers]) {
        drawPointOffset(
            handle, epochToX, quoteToY, canvas, paintStyle, lineStyle,
            radius: 4);
      }

      if (drawingState.contains(DrawingToolState.dragging) &&
          _draggedHandle != null) {
        // Glow the handle(s) being dragged.
        for (final Offset target in handleTargets(_draggedHandle!)) {
          drawFocusedCircle(
            paintStyle,
            lineStyle,
            canvas,
            target,
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
        for (final Offset handle in <Offset>[...corners, ...centers]) {
          drawFocusedCircle(
              paintStyle, lineStyle, canvas, handle, outer, inner);
        }
      }
    }

    // Alignment guides are shown only for a corner point that is being
    // dragged directly. A rail's partner corner that just moves along, the
    // width (edge-midpoint) handles, and whole-channel drags show none.
    if (drawingState.contains(DrawingToolState.dragging) &&
        _draggedCornerIndex != null) {
      drawPointAlignmentGuides(canvas, size, corners[_draggedCornerIndex!],
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
    if (!getDrawingState(this).contains(DrawingToolState.selected) ||
        !_hasAllPoints) {
      return;
    }

    final double progress = animationInfo.stateChangePercent;

    // Value labels (Y-axis) for the four corner quote levels. The fourth
    // (top-left) corner is derived to keep the sides parallel, so its price is
    // `start + end - middle` (matching `topLeft = start + (end - middle)`).
    final double derivedCornerQuote =
        startPoint!.quote + endPoint!.quote - middlePoint!.quote;
    // Lay the labels out: equal displayed prices collapse to one label and
    // near-equal ones spread apart. Identical during a drag and at rest.
    final List<PositionedValueLabel> labels = layoutValueLabels(
      <double>[
        startPoint!.quote, // bottom-left
        middlePoint!.quote, // bottom-right
        endPoint!.quote, // top-right
        derivedCornerQuote, // top-left (derived)
      ],
      quoteToY,
      chartConfig.pipSize,
    );
    for (final PositionedValueLabel label in labels) {
      drawValueLabel(
        canvas: canvas,
        quoteToY: quoteToY,
        value: label.quote,
        pipSize: chartConfig.pipSize,
        animationProgress: progress,
        size: size,
        textStyle: config.labelStyle,
        color: config.lineStyle.color,
        backgroundColor: chartTheme.backgroundColor,
        yPositionOverride: label.y,
      );
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

    // Moves a point vertically only, preserving its timestamp (used by the
    // width handles so the rails stay vertical).
    EdgePoint verticallyMovedPoint(Offset current, EdgePoint point) =>
        EdgePoint(
          epoch: point.epoch,
          quote: quoteFromY(current.dy + delta.dy),
        );

    switch (_draggedHandle) {
      case _ChannelHandle.leftRail:
        // Move the left rail: shifting `start` also shifts the derived top-left
        // corner, so both left corners translate together.
        startPoint = movedPoint(startOffset);
        break;
      case _ChannelHandle.rightRail:
        // Move the right rail: shift both bottom-right and top-right together,
        // which keeps the derived top-left (and the width) unchanged.
        middlePoint = movedPoint(middleOffset);
        endPoint = movedPoint(endOffset);
        break;
      case _ChannelHandle.topCenter:
        // Adjust width from the top: move both top corners vertically. Shifting
        // `end` vertically also shifts the derived top-left corner.
        endPoint = verticallyMovedPoint(endOffset, endPoint!);
        break;
      case _ChannelHandle.bottomCenter:
        // Adjust width from the bottom: move both bottom corners vertically. The
        // derived top-left stays put since start and middle shift equally.
        startPoint = verticallyMovedPoint(startOffset, startPoint!);
        middlePoint = verticallyMovedPoint(middleOffset, middlePoint!);
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
    _draggedHandle = null;
    _draggedCornerIndex = null;
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
