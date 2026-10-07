bool screenCounterValid(num? value) => value != null && value.isFinite && value >= 0;

int? screenCounterPixelDimension(num? value) {
  if (!screenCounterValid(value) || value == null || value < 1 || value > 8192) {
    return null;
  }
  return value.round();
}

bool screenCounterReset(List<(num?, num?)> pairs) => pairs.any(
  (pair) => screenCounterValid(pair.$1) &&
      screenCounterValid(pair.$2) &&
      pair.$1! < pair.$2!,
);

double? screenMetricBounded(double? value, double maximum) =>
    value != null && value.isFinite && value >= 0 && value <= maximum
    ? value
    : null;

double? screenMetricCounter(num? value) => screenCounterValid(value)
    ? value!.toDouble()
    : null;

double? screenMetricRate(
  double? previous,
  double? current,
  double? elapsedMs,
  double multiplier,
  double maximum,
) {
  if (previous == null || current == null || elapsedMs == null ||
      !previous.isFinite || !current.isFinite || !elapsedMs.isFinite ||
      elapsedMs <= 0 || current < previous) {
    return null;
  }
  return screenMetricBounded((current - previous) * multiplier / elapsedMs, maximum);
}

double screenMetricRound(double value) => (value * 10).round() / 10;
