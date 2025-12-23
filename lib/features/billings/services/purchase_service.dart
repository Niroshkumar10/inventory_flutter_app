import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_model.dart';

class PurchaseService {
  final _ref = FirebaseFirestore.instance.collection('purchases');

  Future<void> addPurchase(Purchase purchase) async {
    await _ref.add(purchase.toMap());
  }

  Stream<List<Purchase>> getPurchases() {
    return _ref.orderBy('date', descending: true).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Purchase.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }
}
