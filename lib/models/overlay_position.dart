class OverlayPosition {
  const OverlayPosition({required this.dx, required this.dy});

  factory OverlayPosition.defaults() {
    return const OverlayPosition(dx: 24, dy: 160);
  }

  factory OverlayPosition.fromJson(Map<dynamic, dynamic> json) {
    final defaults = OverlayPosition.defaults();

    return OverlayPosition(
      dx: (json['dx'] as num?)?.toDouble() ?? defaults.dx,
      dy: (json['dy'] as num?)?.toDouble() ?? defaults.dy,
    );
  }

  final double dx;
  final double dy;

  Map<String, double> toJson() {
    return {'dx': dx, 'dy': dy};
  }
}
