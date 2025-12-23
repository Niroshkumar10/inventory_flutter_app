import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier_model.dart';

class SupplierService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userMobile; // Current logged-in user

  SupplierService(this.userMobile);

  // Get user's suppliers subcollection reference
  CollectionReference get _userSuppliersCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('suppliers');
  }

  // ✅ ADD SUPPLIER
  Future<String> addSupplier(Supplier supplier) async {
    try {
      // Ensure supplier belongs to current user
      final supplierData = supplier.toMap();
      supplierData['userMobile'] = userMobile;
      
      final docRef = await _userSuppliersCollection.add(supplierData);
      return docRef.id;
    } catch (e) {
      print('❌ Error adding supplier: $e');
      throw Exception('Failed to add supplier: $e');
    }
  }

  // ✅ UPDATE SUPPLIER
  Future<void> updateSupplier(Supplier supplier) async {
    try {
      if (supplier.id.isEmpty) {
        throw Exception('Supplier ID is required for update');
      }
      
      await _userSuppliersCollection.doc(supplier.id).update({
        'name': supplier.name,
        'phone': supplier.phone,
        'email': supplier.email,
        'address': supplier.address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating supplier: $e');
      throw Exception('Failed to update supplier: $e');
    }
  }

  // ✅ DELETE SUPPLIER
  Future<void> deleteSupplier(String id) async {
    try {
      await _userSuppliersCollection.doc(id).delete();
    } catch (e) {
      print('❌ Error deleting supplier: $e');
      throw Exception('Failed to delete supplier: $e');
    }
  }

  // ✅ GET ALL SUPPLIERS (Stream)
  Stream<List<Supplier>> getSuppliers() {
    return _userSuppliersCollection
        .orderBy('name')
        .snapshots()
        .handleError((error) {
          print('❌ Stream error: $error');
        })
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return [];
          
          return snapshot.docs.map((doc) {
            return Supplier.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  // ✅ GET SUPPLIER BY ID
  Future<Supplier> getSupplierById(String id) async {
    try {
      final doc = await _userSuppliersCollection.doc(id).get();
      if (doc.exists) {
        return Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      throw Exception('Supplier not found');
    } catch (e) {
      print('❌ Error getting supplier: $e');
      rethrow;
    }
  }

  // ✅ SEARCH SUPPLIERS
  Stream<List<Supplier>> searchSuppliers(String query) {
    if (query.isEmpty) return getSuppliers();
    
    return _userSuppliersCollection
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final phone = (data['phone'] ?? '').toString().toLowerCase();
              return name.contains(query.toLowerCase()) || 
                     phone.contains(query.toLowerCase());
            })
            .map((doc) => Supplier.fromMap(
                  doc.data() as Map<String, dynamic>, 
                  doc.id,
                ))
            .toList());
  }

  // ✅ GET SUPPLIER COUNT
  Stream<int> getSupplierCount() {
    return _userSuppliersCollection
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}