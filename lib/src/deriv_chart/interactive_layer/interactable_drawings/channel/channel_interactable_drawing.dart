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
  /// The start point of the base line.
  start,

  /// The middle point (the other end of the base line).
  middle,

  /// The offset point that controls the channel width.
  end,
}

/// Interactable drawing implementation for the channel drawing tool.
///
/// A channel is two parallel lines forming a filled parallelogram, defined by
/// three points:
/// - [startPoint] and [middlePoint] define the base line.
/// - [endPoint] controls the width of the channel (the parallel line is the
///   base line offset vertically by `middle.y - end.y`). Its epoch is kept
///   aligned with [middlePoint], so the offset handle sits directly above/below
///   the middle point.
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

  /// Offset point controlling the channel width. Its epoch mirrors
  /// [middlePoint], so only its quote (vertical offset) is meaningful.
  EdgePoint? endPoint;

  /// Which handle is being dragged, or `null` when dragging the whole channel.
  _ChannelHandle? _draggedHandle;

  /// Computes the four parallelogram corners in screen space.
  ///
  /// Returns `[start, middle, offsetMiddle, offsetStart]` where the offset side
  /// is the base line shifted so it passes through [offsetY] under `middle`.
  static List<Offset> parallelogramCorners(
    Offset start,
    Offset middle,
    double offsetY,
  ) {
    final double height = middle.dy - offsetY;
    final Offset offsetMiddle = Offset(middle.dx, middle.dy - height);
    final Offset offsetStart = Offset(start.dx, start.dy - height);
    return <Offset>[start, middle, offsetMiddle, offsetStart];
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

    final Offset position = details.localPosition;

    if ((position - startOffset).distance <= hitTestMargin) {
      _draggedHandle = _ChannelHandle.start;
    } else if ((position - middleOffset).distance <= hitTestMargin) {
      _draggedHandle = _ChannelHandle.middle;
    } else if ((position - endOffset).distance <= hitTestMargin) {
      _draggedHandle = _ChannelHandle.end;
    } else {
      // Dragging the whole channel.
      _draggedHandle = null;
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

    if ((offset - startOffset).distance <= hitTestMargin ||
        (offset - middleOffset).distance <= hitTestMargin ||
        (offset - endOffset).distance <= hitTestMargin) {
      return true;
    }

    final List<Offset> corners =
        parallelogramCorners(startOffset, middleOffset, endOffset.dy);
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
        parallelogramCorners(startOffset, middleOffset, endOffset.dy);
    final Offset line1a = corners[0];
    final Offset line1b = corners[1];
    final Offset line2b = corners[2];
    final Offset line2a = corners[3];

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
        ..drawLine(line1a, line1b, neonPaint)
        ..drawLine(line2a, line2b, neonPaint);
    }

    // Translucent fill and the two parallel lines.
    canvas.drawPath(
      parallelogramPath(corners),
      paintStyle.fillPaintStyle(fillStyle.color, fillStyle.thickness),
    );
    final Paint linePaint =
        paintStyle.linePaintStyle(lineStyle.color, lineStyle.thickness);
    canvas
      ..drawLine(line1a, line1b, linePaint)
      ..drawLine(line2a, line2b, linePaint);

    // Handles when there's an active interaction.
    if (drawingState.contains(DrawingToolState.selected) ||
        drawingState.contains(DrawingToolState.hovered) ||
        drawingState.contains(DrawingToolState.dragging)) {
      for (final Offset handle in <Offset>[
        startOffset,
        middleOffset,
        endOffset
      ]) {
        drawPointOffset(
            handle, epochToX, quoteToY, canvas, paintStyle, lineStyle,
            radius: 4);
      }

      if (drawingState.contains(DrawingToolState.dragging) &&
          _draggedHandle != null) {
        final Offset draggedOffset = _handleOffset(
          _draggedHandle!,
          startOffset,
          middleOffset,
          endOffset,
        );
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
        final bool selected =
            drawingState.contains(DrawingToolState.selected);
        final double outer = selected ? 10 * animationInfo.stateChangePercent : 10;
        final double inner = selected ? 3 * animationInfo.stateChangePercent : 3;
        for (final Offset handle in <Offset>[
          startOffset,
          middleOffset,
          endOffset
        ]) {
          drawFocusedCircle(paintStyle, lineStyle, canvas, handle, outer, inner);
        }
      }
    }

    // Alignment guides while dragging.
    if (drawingState.contains(DrawingToolState.dragging)) {
      if (_draggedHandle != null) {
        final Offset draggedOffset = _handleOffset(
          _draggedHandle!,
          startOffset,
          middleOffset,
          endOffset,
        );
        drawPointAlignmentGuides(canvas, size, draggedOffset,
            lineColor: lineStyle.color);
      } else {
        for (final Offset handle in <Offset>[
          startOffset,
          middleOffset,
          endOffset
        ]) {
          drawPointAlignmentGuides(canvas, size, handle,
              lineColor: lineStyle.color);
        }
      }
    }
  }

  Offset _handleOffset(
    _ChannelHandle handle,
    Offset startOffset,
    Offset middleOffset,
    Offset endOffset,
  ) {
    switch (handle) {
      case _ChannelHandle.start:
        return startOffset;
      case _ChannelHandle.middle:
        return middleOffset;
      case _ChannelHandle.end:
        return endOffset;
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

    // Epoch labels (X-axis) for the base line points (end shares middle's epoch).
    final Set<int> seenEpochs = <int>{};
    for (final EdgePoint point in <EdgePoint>[startPoint!, middlePoint!]) {
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

    switch (_draggedHandle) {
      case _ChannelHandle.start:
        final Offset moved = startOffset + delta;
        startPoint = EdgePoint(
          epoch: epochFromX(moved.dx),
          quote: quoteFromY(moved.dy),
        );
        break;
      case _ChannelHandle.middle:
        // Move the middle point and the offset point together to keep the
        // channel width unchanged.
        final Offset movedMiddle = middleOffset + delta;
        final Offset movedEnd = endOffset + delta;
        middlePoint = EdgePoint(
          epoch: epochFromX(movedMiddle.dx),
          quote: quoteFromY(movedMiddle.dy),
        );
        endPoint = EdgePoint(
          epoch: middlePoint!.epoch,
          quote: quoteFromY(movedEnd.dy),
        );
        break;
      case _ChannelHandle.end:
        // Only the vertical offset matters; keep it aligned under middle.
        final double newY = endOffset.dy + delta.dy;
        endPoint = EdgePoint(
          epoch: middlePoint!.epoch,
          quote: quoteFromY(newY),
        );
        break;
      case null:
        // Move the whole channel.
        final Offset movedStart = startOffset + delta;
        final Offset movedMiddle = middleOffset + delta;
        final Offset movedEnd = endOffset + delta;
        startPoint = EdgePoint(
          epoch: epochFromX(movedStart.dx),
          quote: quoteFromY(movedStart.dy),
        );
        middlePoint = EdgePoint(
          epoch: epochFromX(movedMiddle.dx),
          quote: quoteFromY(movedMiddle.dy),
        );
        endPoint = EdgePoint(
          epoch: middlePoint!.epoch,
          quote: quoteFromY(movedEnd.dy),
        );
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
