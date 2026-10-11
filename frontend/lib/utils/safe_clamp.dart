/// Extension providing safe clamping for numbers without throwing ArgumentError
/// when the upper bound is less than the lower bound (e.g. unconstrained or small layout).
extension SafeClampDouble on double {
  double safeClamp(double lower, double upper) {
    if (lower > upper) return lower;
    return clamp(lower, upper).toDouble();
  }
}

extension SafeClampNum on num {
  num safeClamp(num lower, num upper) {
    if (lower > upper) return lower;
    return clamp(lower, upper);
  }
}
