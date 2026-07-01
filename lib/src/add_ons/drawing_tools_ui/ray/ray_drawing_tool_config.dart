import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_config.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/drawing_tool_item.dart';
import 'package:deriv_chart/src/add_ons/drawing_tools_ui/callbacks.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/drawing_pattern.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/data_model/edge_point.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/drawing_tools/drawing_data.dart';
import 'package:deriv_chart/src/deriv_chart/chart/helpers/text_style_json_converter.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/drawing_context.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/helpers/types.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/interactable_drawings/ray/ray_interactable_drawing.dart';
import 'package:deriv_chart/src/theme/design_tokens/core_design_tokens.dart';
import 'package:deriv_chart/src/theme/painting_styles/line_style.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'ray_drawing_tool_item.dart';

part 'ray_drawing_tool_config.g.dart';

/// Ray drawing tool config
@JsonSerializable()
class RayDrawingToolConfig extends DrawingToolConfig {
  /// Initializes
  const RayDrawingToolConfig({
    String? configId,
    DrawingData? drawingData,
    List<EdgePoint> edgePoints = const <EdgePoint>[],
    this.lineStyle =
        const LineStyle(color: CoreDesignTokens.coreColorSolidBlue700),
    this.labelStyle = const TextStyle(
      color: CoreDesignTokens.coreColorSolidBlue700,
      fontSize: 12,
      fontWeight: FontWeight.normal,
      fontFamily: 'Inter',
    ),
    this.pattern = DrawingPatterns.solid,
    super.number,
  }) : super(
          configId: configId,
          drawingData: drawingData,
          edgePoints: edgePoints,
        );

  /// Initializes from JSON.
  factory RayDrawingToolConfig.fromJson(Map<String, dynamic> json) =>
      _$RayDrawingToolConfigFromJson(json);

  /// Drawing tool name
  static const String name = 'dt_ray';

  @override
  Map<String, dynamic> toJson() => _$RayDrawingToolConfigToJson(this)
    ..putIfAbsent(DrawingToolConfig.nameKey, () => name);

  /// Drawing tool line style
  final LineStyle lineStyle;

  /// The style of the labels showing on the axes when the tool is selected.
  @TextStyleJsonConverter()
  final TextStyle labelStyle;

  /// Drawing tool line pattern: 'solid', 'dotted', 'dashed'
  // TODO(maryia-binary): implement 'dotted' and 'dashed' patterns
  final DrawingPatterns pattern;

  @override
  DrawingToolItem getItem(
    UpdateDrawingTool updateDrawingTool,
    VoidCallback deleteDrawingTool,
  ) =>
      RayDrawingToolItem(
        config: this,
        updateDrawingTool: updateDrawingTool,
        deleteDrawingTool: deleteDrawingTool,
      );

  @override
  RayDrawingToolConfig copyWith({
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
      RayDrawingToolConfig(
        configId: configId ?? this.configId,
        drawingData: drawingData ?? this.drawingData,
        lineStyle: lineStyle ?? this.lineStyle,
        labelStyle: labelStyle ?? this.labelStyle,
        pattern: pattern ?? this.pattern,
        edgePoints: edgePoints ?? this.edgePoints,
        number: number ?? this.number,
      );

  @override
  RayInteractableDrawing getInteractableDrawing(
    DrawingContext drawingContext,
    GetDrawingState getDrawingState,
  ) {
    final EdgePoint? startPoint =
        edgePoints.isNotEmpty ? edgePoints.first : null;
    final EdgePoint? endPoint = edgePoints.length > 1 ? edgePoints.last : null;

    return RayInteractableDrawing(
      config: this,
      startPoint: startPoint,
      endPoint: endPoint,
      drawingContext: drawingContext,
      getDrawingState: getDrawingState,
    );
  }
}
