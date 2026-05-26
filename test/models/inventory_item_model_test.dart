import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/features/inventory/models/inventory_item_model.dart';

void main() {
  group('InventoryItem', () {
    InventoryItem makeItem({
      int quantity = 20,
      int lowStockThreshold = 10,
      double price = 100.0,
      double cost = 60.0,
    }) {
      return InventoryItem(
        id: 'item-1',
        name: 'Test Item',
        sku: 'SKU-001',
        price: price,
        cost: cost,
        quantity: quantity,
        lowStockThreshold: lowStockThreshold,
        userMobile: '9999999999',
      );
    }

    test('isLowStock is true when quantity <= lowStockThreshold', () {
      expect(makeItem(quantity: 5, lowStockThreshold: 10).isLowStock, isTrue);
      expect(makeItem(quantity: 10, lowStockThreshold: 10).isLowStock, isTrue);
    });

    test('isLowStock is false when quantity > lowStockThreshold', () {
      expect(makeItem(quantity: 11, lowStockThreshold: 10).isLowStock, isFalse);
    });

    test('totalValue equals price * quantity', () {
      final item = makeItem(quantity: 5, price: 100.0);
      expect(item.totalValue, equals(500.0));
    });

    test('toMap round-trips through fromMap', () {
      final original = makeItem();
      final map = original.toMap();
      final restored = InventoryItem.fromMap(map, original.id);

      expect(restored.name, equals(original.name));
      expect(restored.sku, equals(original.sku));
      expect(restored.price, equals(original.price));
      expect(restored.quantity, equals(original.quantity));
      expect(restored.userMobile, equals(original.userMobile));
    });

    test('copyWith returns new instance with updated fields', () {
      final original = makeItem(quantity: 20);
      final updated = original.copyWith(quantity: 5);

      expect(updated.quantity, equals(5));
      expect(updated.name, equals(original.name));
      expect(updated.id, equals(original.id));
    });

    test('fromMap handles missing optional fields gracefully', () {
      final minimal = {
        'name': 'Minimal Item',
        'sku': 'MIN-001',
        'price': 10.0,
        'cost': 5.0,
        'quantity': 3,
        'userMobile': '1234567890',
        'isActive': true,
      };

      expect(() => InventoryItem.fromMap(minimal, 'test-id'), returnsNormally);
      final item = InventoryItem.fromMap(minimal, 'test-id');
      expect(item.category, equals('Uncategorized'));
      expect(item.unit, equals('pcs'));
    });
  });
}
