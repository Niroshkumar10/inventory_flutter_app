import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_model.dart';

class SalesService {
  final CollectionReference salesCollection =
      FirebaseFirestore.instance.collection('sales');

  Stream<List<Sale>> getSales() {
    return salesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Sale.fromMap(doc.id, data);
      }).toList();
    });
  }

  Future<void> addSale(Sale sale) async {
    await salesCollection.add(sale.toMap());
  }

  Future<void> updateSale(Sale sale) async {
    await salesCollection.doc(sale.id).update(sale.toMap());
  }

  Future<void> deleteSale(String id) async {
    await salesCollection.doc(id).delete();
  }
}
