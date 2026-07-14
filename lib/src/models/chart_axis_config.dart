import 'package:flutter/foundation.dart';

/// Default top bound quote.
const double defaultTopBoundQuote = 60;

/// Default bottom bound quote.
const double defaultBottomBoundQuote = 30;

/// Default Max distance between [rightBoundEpoch] and [_nowEpoch] in pixels.
/// Limits panning to the right.
const double defaultMaxCurrentTickOffset = 150;

/// Default factor applied to the visible price range to add headroom above and
/// below the candles when auto-fitting the Y-axis.
const double defaultPriceRangePaddingFactor = 1.2;

/// Configuration for the chart axis.
@immutable
class ChartAxisConfig {
  /// Initializes the chart axis configuration.
  const ChartAxisConfig({
    this.initialTopBoundQuote = defaultTopBoundQuote,
    this.initialBottomBoundQuote = defaultBottomBoundQuote,
    this.maxCurrentTickOffset = defaultMaxCurrentTickOffset,
    this.defaultTickOffset,
    this.defaultIntervalWidth = 20,
    this.showQuoteGrid = true,
    this.showEpochGrid = true,
    this.showFrame = false,
    this.smoothScrolling = true,
    this.autofit = true,
    this.priceRangePaddingFactor = defaultPriceRangePaddingFactor,
    this.showAutoScaleButton = true,
  });

  /// Top quote bound target for animated transition.
  final double initialTopBoundQuote;

  /// Bottom quote bound target for animated transition.
  final double initialBottomBoundQuote;

  /// Max distance between [rightBoundEpoch] and [_nowEpoch] in pixels.
  /// Limits panning to the right.
  final double maxCurrentTickOffset;

  /// Default distance between the latest data point and the right edge of the
  /// chart in pixels.
  ///
  /// This value is used for:
  /// - Initial chart load tick offset
  /// - Target position when "scroll to last tick" button is clicked
  ///
  /// If not specified, defaults to [maxCurrentTickOffset].
  /// The value will be clamped between 0 and [maxCurrentTickOffset].
  final double? defaultTickOffset;

  /// Show Quote Grid lines and labels.
  final bool showQuoteGrid;

  /// Show Epoch Grid lines and labels.
  final bool showEpochGrid;

  /// Show the chart frame and indicators dividers.
  ///
  /// Used in the mobile chart.
  final bool showFrame;

  /// The default distance between two ticks in pixels.
  ///
  /// Default to this interval width on granularity change.
  final double defaultIntervalWidth;

  /// Whether the chart should scroll smoothly.
  /// If `true`, the chart will smoothly adjust the scroll position
  /// (if the last tick is visible) to the right to continuously show new ticks.
  /// If `false`, the chart will only auto-scroll to keep the new tick visible
  /// after receiving a new tick.
  ///
  /// Default is `true`.
  final bool smoothScrolling;

  /// Whether the Y-axis should automatically fit its bounds to the visible
  /// price range.
  ///
  /// When `true` (default), the visible top/bottom price bounds are recomputed
  /// from the highest and lowest visible quote on every update. When `false`,
  /// the price range is left untouched so it can be controlled manually.
  ///
  /// This acts as the master switch: when the user manually scales the Y-axis,
  /// auto-fitting is disabled internally until this is set back to `true`.
  final bool autofit;

  /// Factor applied to the visible price range (`maxQuote - minQuote`) to add
  /// headroom above and below the candles while auto-fitting.
  ///
  /// A value of `1.2` leaves 10% extra space above and below the data. Only
  /// used while [autofit] is enabled. Defaults to
  /// [defaultPriceRangePaddingFactor].
  final double priceRangePaddingFactor;

  /// Whether to show the TradingView-style "auto scale" toggle button on the
  /// price axis, letting the user enable/disable [autofit] at runtime.
  ///
  /// Defaults to `true`.
  final bool showAutoScaleButton;

  /// Creates a copy of this ChartAxisConfig but with the given fields replaced.
  ChartAxisConfig copyWith({
    double? initialTopBoundQuote,
    double? initialBottomBoundQuote,
    double? maxCurrentTickOffset,
    double? defaultTickOffset,
    bool? autofit,
    double? priceRangePaddingFactor,
    bool? showAutoScaleButton,
  }) =>
      ChartAxisConfig(
        initialTopBoundQuote: initialTopBoundQuote ?? this.initialTopBoundQuote,
        initialBottomBoundQuote:
            initialBottomBoundQuote ?? this.initialBottomBoundQuote,
        maxCurrentTickOffset: maxCurrentTickOffset ?? this.maxCurrentTickOffset,
        defaultTickOffset: defaultTickOffset ?? this.defaultTickOffset,
        autofit: autofit ?? this.autofit,
        priceRangePaddingFactor:
            priceRangePaddingFactor ?? this.priceRangePaddingFactor,
        showAutoScaleButton: showAutoScaleButton ?? this.showAutoScaleButton,
      );
}
