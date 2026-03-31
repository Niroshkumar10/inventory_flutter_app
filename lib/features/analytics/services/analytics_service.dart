import '../../bill/models/bill_model.dart';

class AnalyticsService {

  Map<String, double> _calculateItems(List<Bill> bills, String type) {
    Map<String, double> itemMap = {};

    for (var bill in bills) {
      if (bill.type == type) {
        for (var item in bill.items) {

          String name = item.itemName; // ✅ using your getter
          double qty = item.quantity;

          if (itemMap.containsKey(name)) {
            itemMap[name] = itemMap[name]! + qty;
          } else {
            itemMap[name] = qty;
          }
        }
      }
    }

    return itemMap;
  }

  List<MapEntry<String, double>> getTopSelling(List<Bill> bills) {
    final data = _calculateItems(bills, 'sales');

    var list = data.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));

    return list;
  }

  List<MapEntry<String, double>> getTopPurchase(List<Bill> bills) {
    final data = _calculateItems(bills, 'purchase');

    var list = data.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));

    return list;
  }

  String getSuggestion(double qty) {
    if (qty > 50) return "🔥 High demand";
    if (qty < 10) return "⚠ Low demand";
    return "✅ Normal";
  }
}