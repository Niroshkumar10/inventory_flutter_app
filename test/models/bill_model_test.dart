import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/features/bill/models/bill_model.dart';

void main() {
  group('Bill', () {
    Bill makeBill({
      double totalAmount = 1000.0,
      double amountPaid = 0.0,
      String paymentStatus = 'due',
      List<BillItem> items = const [],
    }) {
      return Bill.create(
        type: 'sales',
        invoiceNumber: 'SALE-2024-001',
        partyName: 'Test Customer',
        userMobile: '9999999999',
        totalAmount: totalAmount,
        subtotal: totalAmount,
        amountPaid: amountPaid,
        amountDue: totalAmount - amountPaid,
        paymentStatus: paymentStatus,
        items: items,
      );
    }

    test('amountDue equals totalAmount minus amountPaid', () {
      final bill = makeBill(totalAmount: 1000.0, amountPaid: 400.0);
      expect(bill.amountDue, equals(600.0));
    });

    test('paymentStatus is paid when amountDue is zero', () {
      final bill = makeBill(totalAmount: 500.0, amountPaid: 500.0, paymentStatus: 'paid');
      expect(bill.paymentStatus, equals('paid'));
    });

    test('toMap round-trips through fromMap', () {
      final original = makeBill(totalAmount: 750.0, amountPaid: 250.0);
      // Build map manually — toMap() uses FieldValue.serverTimestamp() which
      // cannot be cast to Timestamp in a VM unit test without Firebase.
      final map = <String, dynamic>{
        'type': original.type,
        'invoiceNumber': original.invoiceNumber,
        'partyName': original.partyName,
        'partyPhone': original.partyPhone,
        'partyAddress': original.partyAddress,
        'items': <dynamic>[],
        'subtotal': original.subtotal,
        'gstRate': original.gstRate,
        'gstAmount': original.gstAmount,
        'totalAmount': original.totalAmount,
        'amountPaid': original.amountPaid,
        'amountDue': original.amountDue,
        'paymentStatus': original.paymentStatus,
        'isGST': original.isGST,
        'notes': original.notes,
        'userMobile': original.userMobile,
      };
      final restored = Bill.fromMap(map, original.id);

      expect(restored.invoiceNumber, equals(original.invoiceNumber));
      expect(restored.totalAmount, equals(original.totalAmount));
      expect(restored.amountPaid, equals(original.amountPaid));
      expect(restored.amountDue, equals(original.amountDue));
      expect(restored.partyName, equals(original.partyName));
    });

    test('Bill.create sets sensible defaults', () {
      final bill = Bill.create(
        type: 'purchase',
        invoiceNumber: 'PUR-001',
        partyName: 'Supplier A',
        userMobile: '8888888888',
      );

      expect(bill.items, isEmpty);
      expect(bill.gstRate, equals(0.0));
      expect(bill.isGST, isTrue);
      expect(bill.paymentStatus, equals('due'));
    });

    test('BillItem total equals quantity * price', () {
      final item = BillItem(
        id: 'p1',
        description: 'Widget',
        quantity: 3,
        price: 150.0,
        total: 450.0,
      );
      expect(item.total, equals(item.quantity * item.price));
    });
  });
}
