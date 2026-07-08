part of 'chart.dart';

class _ChartStateMobile extends _ChartState {
  double _bottomSectionHeight = 0;

  /// Whether the overlay indicator labels list is expanded. When collapsed,
  /// only the toggle button is shown so the labels don't take up chart space.
  bool _isOverlayLabelsExpanded = true;

  @override
  void initState() {
    super.initState();

    _bottomSectionHeight =
        _getBottomIndicatorsSectionHeightFraction(widget.bottomConfigs.length);
  }

  @override
  void didUpdateWidget(covariant Chart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.bottomConfigs.length != widget.bottomConfigs.length) {
      _bottomSectionHeight = _getBottomIndicatorsSectionHeightFraction(
        widget.bottomConfigs.length,
      );
    }
  }

  @override
  Widget buildChartsLayout(
    BuildContext context,
    List<Series>? overlaySeries,
    List<Series>? bottomSeries,
  ) {
    final Duration currentTickAnimationDuration =
        widget.currentTickAnimationDuration ?? _defaultDuration;

    final Duration quoteBoundsAnimationDuration =
        widget.quoteBoundsAnimationDuration ?? _defaultDuration;

    List<Widget> getBottomIndicatorsList(BuildContext context) =>
        widget.indicatorsRepo!.items
            .mapIndexed((int index, IndicatorConfig config) {
          if (config.isOverlay) {
            return const SizedBox.shrink();
          }

          final Series series = config.getSeries(
            IndicatorInput(
              widget.mainSeries.input,
              widget.granularity,
            ),
          );
          final Repository<IndicatorConfig>? repository = widget.indicatorsRepo;

          // TODO(Ramin): Use the key (type + number) once it's implemented.
          final int indexInBottomConfigs =
              referenceIndexOf(widget.bottomConfigs, config);

          final Widget bottomChart = BottomChartMobile(
            series: series,
            isHidden: repository?.getHiddenStatus(index) ?? false,
            granularity: widget.granularity,
            pipSize: config.pipSize,
            title:
                '${config.shortTitle} ${config.number > 0 ? config.number : ''}'
                ' (${config.configSummary})',
            currentTickAnimationDuration: currentTickAnimationDuration,
            quoteBoundsAnimationDuration: quoteBoundsAnimationDuration,
            bottomChartTitleMargin:
                const EdgeInsets.only(left: Dimens.margin04),
            onHideUnhideToggle: () =>
                _onIndicatorHideToggleTapped(repository, index),
            onSwap: (int offset) => _onSwap(
                config, widget.bottomConfigs[indexInBottomConfigs + offset]),
            showMoveUpIcon:
                bottomSeries!.length > 1 && indexInBottomConfigs != 0,
            showMoveDownIcon: bottomSeries.length > 1 &&
                indexInBottomConfigs != bottomSeries.length - 1,
            showFrame: context.read<ChartConfig>().chartAxisConfig.showFrame,
          );

          return (repository?.getHiddenStatus(index) ?? false)
              ? bottomChart
              : Expanded(
                  child: bottomChart,
                );
        }).toList();

    final List<Series> overlaySeries = <Series>[];

    if (widget.indicatorsRepo != null) {
      for (int i = 0; i < widget.indicatorsRepo!.items.length; i++) {
        final IndicatorConfig config = widget.indicatorsRepo!.items[i];
        if (widget.indicatorsRepo!.getHiddenStatus(i) || !config.isOverlay) {
          continue;
        }

        overlaySeries.add(config.getSeries(
          IndicatorInput(
            widget.mainSeries.input,
            widget.granularity,
          ),
        ));
      }
    }

    return LayoutBuilder(builder: (
      BuildContext context,
      BoxConstraints constraints,
    ) {
      final List<Widget> bottomIndicatorsList =
          getBottomIndicatorsList(context);
      return Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                if (context.read<ChartConfig>().chartAxisConfig.showFrame)
                  _buildMainChartFrame(context),
                MainChart(
                  drawingTools: widget.drawingTools,
                  controller: _controller,
                  mainSeries: widget.mainSeries,
                  overlaySeries: overlaySeries,
                  annotations: widget.annotations,
                  markerSeries: widget.markerSeries,
                  pipSize: widget.pipSize,
                  onCrosshairAppeared: widget.onCrosshairAppeared,
                  onQuoteAreaChanged: widget.onQuoteAreaChanged,
                  isLive: widget.isLive,
                  showLoadingAnimationForHistoricalData: !widget.dataFitEnabled,
                  showDataFitButton:
                      widget.showDataFitButton ?? widget.dataFitEnabled,
                  showScrollToLastTickButton:
                      widget.showScrollToLastTickButton ?? true,
                  opacity: widget.opacity,
                  chartAxisConfig: widget.chartAxisConfig,
                  verticalPaddingFraction: widget.verticalPaddingFraction,
                  showCrosshair: widget.showCrosshair,
                  onCrosshairDisappeared: widget.onCrosshairDisappeared,
                  onCrosshairHover: _onCrosshairHover,
                  loadingAnimationColor: widget.loadingAnimationColor,
                  currentTickAnimationDuration: currentTickAnimationDuration,
                  quoteBoundsAnimationDuration: quoteBoundsAnimationDuration,
                  showCurrentTickBlinkAnimation:
                      widget.showCurrentTickBlinkAnimation ?? true,
                  crosshairVariant: widget.crosshairVariant,
                  interactiveLayerBehaviour: widget.interactiveLayerBehaviour,
                  useDrawingToolsV2: widget.useDrawingToolsV2,
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimens.margin08,
                      horizontal: Dimens.margin04,
                    ),
                    child: _buildOverlayIndicatorsLabels(),
                  ),
                ),
              ],
            ),
          ),
          if (context.read<ChartConfig>().chartAxisConfig.showFrame &&
              bottomIndicatorsList.isNotEmpty)
            const Divider(
              height: 0.5,
              thickness: 1,
              color: Color(0xFF242828),
            ),
          if (_isAllBottomIndicatorsHidden)
            ...bottomIndicatorsList
          else
            SizedBox(
              height: _bottomSectionHeight * constraints.maxHeight,
              child: Column(children: bottomIndicatorsList),
            ),
        ],
      );
    });
  }

  Widget _buildMainChartFrame(BuildContext context) => Container(
        constraints: const BoxConstraints.expand(),
        child: MobileChartFrameDividers(
          color: const Color(0xFF242828),
          rightPadding: (context.read<XAxisModel>().rightPadding ?? 0) +
              _chartTheme.gridStyle.labelHorizontalPadding,
        ),
      );

  int referenceIndexOf(List<dynamic> list, dynamic element) {
    for (int i = 0; i < list.length; i++) {
      if (identical(list[i], element)) {
        return i;
      }
    }
    return -1;
  }

  void _onIndicatorHideToggleTapped(
    Repository<IndicatorConfig>? repository,
    int index,
  ) {
    repository?.updateHiddenStatus(
      index: index,
      hidden: !repository.getHiddenStatus(index),
    );
  }

  double _getBottomIndicatorsSectionHeightFraction(int bottomIndicatorsCount) =>
      1 - (0.65 - 0.125 * (bottomIndicatorsCount - 1));

  bool get _isAllBottomIndicatorsHidden {
    bool isAllHidden = true;
    for (int i = 0; i < widget.indicatorsRepo!.items.length; i++) {
      if (!widget.indicatorsRepo!.items[i].isOverlay &&
          !(widget.indicatorsRepo?.getHiddenStatus(i) ?? false)) {
        isAllHidden = false;
      }
    }
    return isAllHidden;
  }

  Widget _buildOverlayIndicatorsLabels() {
    final List<Widget> overlayIndicatorsLabels = <Widget>[];
    if (widget.indicatorsRepo != null) {
      for (int i = 0; i < widget.indicatorsRepo!.items.length; i++) {
        final IndicatorConfig config = widget.indicatorsRepo!.items[i];
        if (!config.isOverlay) {
          continue;
        }

        overlayIndicatorsLabels.add(
          Padding(
            padding: const EdgeInsets.only(bottom: Dimens.margin04),
            child: IndicatorLabelMobile(
              title:
                  '${config.shortTitle} ${config.number > 0 ? config.number : ''}'
                  ' (${config.configSummary})',
              showMoveUpIcon: false,
              showMoveDownIcon: false,
              isHidden: widget.indicatorsRepo?.getHiddenStatus(i) ?? false,
              onHideUnhideToggle: () {
                _onIndicatorHideToggleTapped(widget.indicatorsRepo, i);
              },
            ),
          ),
        );
      }
    }

    // Nothing to show if there are no overlay indicators.
    if (overlayIndicatorsLabels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildOverlayLabelsCollapseButton(overlayIndicatorsLabels.length),
        if (_isOverlayLabelsExpanded) ...<Widget>[
          const SizedBox(height: Dimens.margin04),
          ...overlayIndicatorsLabels,
        ],
      ],
    );
  }

  /// A stadium "filter tag" pill showing the number of overlay indicators and a
  /// caret to expand/collapse the labels list (matches the Figma design).
  Widget _buildOverlayLabelsCollapseButton(int count) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_overlayPillRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _chartTheme
                  .crosshairInformationBoxContainerGlassBackgroundBlur,
              sigmaY: _chartTheme
                  .crosshairInformationBoxContainerGlassBackgroundBlur,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(_overlayPillRadius),
                onTap: () => setState(
                  () => _isOverlayLabelsExpanded = !_isOverlayLabelsExpanded,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimens.margin08,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _chartTheme.crosshairInformationBoxContainerGlassColor,
                    borderRadius: BorderRadius.circular(_overlayPillRadius),
                    border: Border.all(
                      color: _chartTheme.base01Color.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$count',
                        style: _chartTheme.textStyle(
                          textStyle: TextStyles.caption2,
                          color: _chartTheme.base01Color,
                        ),
                      ),
                      const SizedBox(width: Dimens.margin04),
                      Icon(
                        _isOverlayLabelsExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: _chartTheme.base01Color,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// Fully-rounded (stadium) corner radius for the overlay labels toggle pill.
  static const double _overlayPillRadius = 100;
}
