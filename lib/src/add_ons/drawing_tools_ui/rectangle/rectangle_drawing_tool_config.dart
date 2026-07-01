import 'package:deriv_chart/src/add_ons/drawing_tools_ui/rectangle/rectangle_drawing_tool_item.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_config.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_item.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_pattern.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/drawing_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/helpers/text_style_json_converter.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/drawing_context.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/helpers/types.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/interactable_drawings/rectangle/rectangle_interactable_drawing.dart';
import 'package:deriv_chart/src/theme/painting_styles/line_style.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import '../callbacks.dart';

part 'rectangle_drawing_tool_config.g.dart';

/// Rectangle drawing tool configurations.
@JsonSerializable()
class RectangleDrawingToolConfig extends DrawingToolConfig {
  /// Initializes
  const RectangleDrawingToolConfig({
    String? configId,
    DrawingData? drawingData,
    List<EdgePoint> edgePoints = const <EdgePoint>[],
    this.fillStyle = const LineStyle(thickness: 0.9, color: Colors.blue),
    this.lineStyle = const LineStyle(thickness: 0.9, color: Colors.white),
    this.labelStyle = const TextStyle(color: Colors.blue, fontSize: 12),
    this.pattern = DrawingPatterns.solid,
    super.number,
  }) : super(
          configId: configId,
          drawingData: drawingData,
          edgePoints: edgePoints,
        );

  /// Initializes from JSON.
  factory RectangleDrawingToolConfig.fromJson(Map<String, dynamic> json) =>
      _$RectangleDrawingToolConfigFromJson(json);

  /// Unique name for this drawing tool.
  static const String name = 'dt_rectangle';

  @override
  Map<String, dynamic> toJson() => _$RectangleDrawingToolConfigToJson(this)
    ..putIfAbsent(DrawingToolConfig.nameKey, () => name);

  /// Drawing tool line style
  final LineStyle lineStyle;

  /// Drawing tool fill style
  final LineStyle fillStyle;

  /// The style of the labels showing on the axes when the tool is selected.
  @TextStyleJsonConverter()
  final TextStyle labelStyle;

  /// Drawing tool line pattern: 'solid', 'dotted', 'dashed'
  final DrawingPatterns pattern;

  @override
  DrawingToolItem getItem(
    UpdateDrawingTool updateDrawingTool,
    VoidCallback deleteDrawingTool,
  ) =>
      RectangleDrawingToolItem(
        config: this,
        updateDrawingTool: updateDrawingTool,
        deleteDrawingTool: deleteDrawingTool,
      );

  @override
  RectangleDrawingToolConfig copyWith({
    String? configId,
    DrawingData? drawingData,
    LineStyle? lineStyle,
    LineStyle? fillStyle,
    TextStyle? labelStyle,
    DrawingPatterns? pattern,
    List<EdgePoint>? edgePoints,
    bool? enableLabel,
    int? number,
  }) =>
      RectangleDrawingToolConfig(
        configId: configId ?? this.configId,
        drawingData: drawingData ?? this.drawingData,
        lineStyle: lineStyle ?? this.lineStyle,
        fillStyle: fillStyle ?? this.fillStyle,
        labelStyle: labelStyle ?? this.labelStyle,
        pattern: pattern ?? this.pattern,
        edgePoints: edgePoints ?? this.edgePoints,
        number: number ?? this.number,
      );

  @override
  RectangleInteractableDrawing getInteractableDrawing(
    DrawingContext drawingContext,
    GetDrawingState getDrawingState,
  ) {
    final EdgePoint? startPoint =
        edgePoints.isNotEmpty ? edgePoints.first : null;
    final EdgePoint? endPoint = edgePoints.length > 1 ? edgePoints.last : null;

    return RectangleInteractableDrawing(
      config: this,
      startPoint: startPoint,
      endPoint: endPoint,
      drawingContext: drawingContext,
      getDrawingState: getDrawingState,
    );
  }
}
