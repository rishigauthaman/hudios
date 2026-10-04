import '../models/price_model.dart';
import '../providers/price_provider.dart';

abstract interface class PriceRepository {
  Stream<PriceModel> watch(String symbol);
}

class ProviderPriceRepository implements PriceRepository {
  const ProviderPriceRepository(this._provider);

  final PriceProvider _provider;

  @override
  Stream<PriceModel> watch(String symbol) {
    return _provider.subscribe(symbol);
  }
}
