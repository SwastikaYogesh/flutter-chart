import 'dart:math';

import 'package:flutter/foundation.dart';

///A Model for calculating the grid intervals and quotes.
class YAxisModel {
  ///Initializes a Model for calculating the grid intervals and quotes.
  YAxisModel({
    required double topBoundQuote,
    required double bottomBoundQuote,
    required double yTopBound,
    required double yBottomBound,
    required double canvasHeight,
    required double topPadding,
    required double bottomPadding,
  })  : _quoteGridInterval = quoteGridInterval(
          topBoundQuote - bottomBoundQuote,
          yBottomBound - yTopBound,
        ),
        _topBoundQuote = topBoundQuote,
        _bottomBoundQuote = bottomBoundQuote,
        _canvasHeight = canvasHeight,
        _topPadding = topPadding,
        _bottomPadding = bottomPadding;

  /// Initializes a model with zero values.
  YAxisModel.zero()
      : _quoteGridInterval = 0,
        _topBoundQuote = 0,
        _bottomBoundQuote = 0,
        _canvasHeight = 0,
        _topPadding = 0,
        _bottomPadding = 0;

  final double _quoteGridInterval;
  final double _topBoundQuote;
  final double _bottomBoundQuote;
  final double _canvasHeight;
  final double _topPadding;
  final double _bottomPadding;

  /// Top padding.
  double get topPadding => _topPadding;

  /// Bottom padding.
  double get bottomPadding => _bottomPadding;

  /// Top bound quote
  double get topBoundQuote => _topBoundQuote;

  /// Bottom bound quote
  double get bottomBoundQuote => _bottomBoundQuote;

  /// The height of the canvas.
  double get canvasHeight => _canvasHeight;

  /// Calculates the grid line quotes for the currently visible price range.
  ///
  /// The visible range is derived from the lowest ([_bottomBoundQuote]) and
  /// highest ([_topBoundQuote]) price of the visible candles, expanded by the
  /// vertical padding so grid lines can cover the full canvas. Grid lines are
  /// then placed on "nice" multiples of [_quoteGridInterval] (computed with a
  /// logarithmic step, see [quoteGridInterval]), matching how the TradingView
  /// price axis snaps its labels to round values.
  List<double> gridQuotes() {
    // Guard against a degenerate range/interval that would otherwise loop
    // forever or produce NaN/Infinity values.
    if (_quoteGridInterval <= 0 ||
        !_quoteGridInterval.isFinite ||
        _canvasHeight - _topPadding - _bottomPadding <= 0) {
      return <double>[];
    }

    final double pixelToQuote = (_topBoundQuote - _bottomBoundQuote) /
        (_canvasHeight - _topPadding - _bottomPadding);

    // Expand the visible [min, max] price range by the top/bottom padding so
    // grid lines are drawn across the whole canvas, not just between candles.
    final double topEdgeQuote = _topBoundQuote + _topPadding * pixelToQuote;
    final double bottomEdgeQuote =
        _bottomBoundQuote - _bottomPadding * pixelToQuote;

    final List<double> gridLineQuotes = <double>[];
    // Start from the highest multiple of the interval that is not above the top
    // edge, then step down by one interval at a time.
    for (double q = topEdgeQuote - topEdgeQuote % _quoteGridInterval;
        q > bottomEdgeQuote;
        q -= _quoteGridInterval) {
      if (q < topEdgeQuote) {
        gridLineQuotes.add(q);
      }
    }
    return gridLineQuotes;
  }
}

/// Calculates the quotes that can be placed per pixel.
double quotePerPx({
  required double topBoundQuote,
  required double bottomBoundQuote,
  required double yTopBound,
  required double yBottomBound,
}) {
  final double quoteDiff = topBoundQuote - bottomBoundQuote;
  final double pxDiff = yBottomBound - yTopBound;

  return quoteDiff / pxDiff;
}

/// Calculates the grid interval of a quote using a logarithmic "nice number"
/// step, similar to how the TradingView price axis chooses its label spacing.
///
/// Instead of picking from a fixed list of hard-coded intervals, the step is
/// derived directly from the data scale:
///
/// 1. Aim for one grid line per [minDistanceBetweenLines] pixels, i.e.
///    `targetGridLines = viewHeight / minDistanceBetweenLines`.
/// 2. The raw (un-rounded) step is `visiblePriceRange / targetGridLines`.
/// 3. Snap that raw step up to a "nice" value — `1`, `2`, `2.5`, `5` or `10`
///    times a power of ten — so the resulting price labels stay readable.
///
/// [visiblePriceRange] is the price difference between the highest and lowest
/// visible quote, and [viewHeight] is the height (in pixels) that range is
/// drawn across. Working with these keeps labels readable at any scale — from
/// fractional forex pips to large index values — without an intervals table.
double quoteGridInterval(
  double visiblePriceRange,
  double viewHeight, {
  double minDistanceBetweenLines = 50,
}) {
  // Number of grid lines that fit while keeping [minDistanceBetweenLines]
  // pixels between them.
  final double targetGridLines = viewHeight / minDistanceBetweenLines;

  if (visiblePriceRange <= 0 ||
      !visiblePriceRange.isFinite ||
      targetGridLines <= 0) {
    return 0.01;
  }

  // The un-rounded step, in quote units, before snapping to a nice value.
  final double rawStep = visiblePriceRange / targetGridLines;

  // Order of magnitude of the raw step (e.g. 0.01, 1, 100, ...), floored at
  // 0.01 so the axis never shows sub-cent precision.
  double exponent = pow(10, (log(rawStep) / ln10).floor()).toDouble();
  exponent = max(0.01, exponent);

  // Normalize the raw step into the [1, 10) range so it can be snapped to a
  // nice multiplier.
  final double fraction = rawStep / exponent;

  // Snap up to the next nice multiplier so the on-screen spacing is never
  // smaller than the requested minimum.
  double niceFraction;
  if (fraction <= 1) {
    niceFraction = 1;
  } else if (fraction <= 2) {
    niceFraction = 2;
  } else if (fraction <= 2.5) {
    niceFraction = 2.5;
  } else if (fraction <= 5) {
    niceFraction = 5;
  } else {
    niceFraction = 10;
  }

  return niceFraction * exponent;
}

/// A notifier for the Y-axis model.
class YAxisNotifier extends ValueNotifier<YAxisModel> {
  /// Initializes a notifier for the Y-axis model.
  YAxisNotifier(super.value);
}
