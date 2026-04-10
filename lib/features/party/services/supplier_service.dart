
// lib/features/party/services/supplier_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier_model.dart';

class SupplierService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userMobile;

  SupplierService(this.userMobile);

  CollectionReference get _userSuppliersCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('suppliers');
  }

  // ✅ ADD SUPPLIER
  Future<String> addSupplier(Supplier supplier) async {
    try {
      final supplierData = supplier.toMap();
      supplierData['userMobile'] = userMobile;
      final docRef = await _userSuppliersCollection.add(supplierData);
      return docRef.id;
    } catch (e) {
      print('❌ Error adding supplier: $e');
      throw Exception('Failed to add supplier: $e');
    }
  }

  // ✅ UPDATE SUPPLIER — now saves location fields too
  Future<void> updateSupplier(Supplier supplier) async {
    try {
      if (supplier.id.isEmpty) {
        throw Exception('Supplier ID is required for update');
      }

      final Map<String, dynamic> data = {
        'name': supplier.name,
        'phone': supplier.phone,
        'email': supplier.email,
        'address': supplier.address,
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': supplier.isActive,
      };

      // Save or clear location
      if (supplier.latitude != null && supplier.longitude != null) {
        data['latitude'] = supplier.latitude;
        data['longitude'] = supplier.longitude;
        data['locationAddress'] = supplier.locationAddress ?? '';
      } else {
        data['latitude'] = FieldValue.delete();
        data['longitude'] = FieldValue.delete();
        data['locationAddress'] = FieldValue.delete();
      }

      await _userSuppliersCollection.doc(supplier.id).update(data);
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