import '../models/price_model.dart';

abstract interface class PriceProvider {
  Stream<PriceModel> subscribe(String symbol);
}
