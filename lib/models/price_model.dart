class PriceModel {
  const PriceModel({
    required this.symbol,
    required this.price,
    required this.previousPrice,
    required this.percentChange,
    required this.updatedAt,
  });

  final String symbol;
  final double price;
  final double previousPrice;
  final double percentChange;
  final DateTime updatedAt;

  bool get isUp => price > previousPrice;
  bool get isDown => price < previousPrice;
}
