class Formatters {
  const Formatters._();

  static String compactPrice(double value, {bool showDecimals = true}) {
    if (!showDecimals) {
      return value.round().toString();
    }

    if (value >= 1000) {
      return value.toStringAsFixed(2);
    }
    if (value >= 1) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }
}
