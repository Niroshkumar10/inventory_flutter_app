import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';

class CustomerService {
  final String userMobile;
  
  CustomerService(this.userMobile);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's customers subcollection reference
  CollectionReference get _userCustomersCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('customers');
  }

  // Add customer
  Future<String> addCustomer(Customer customer) async {
    try {
      // Don't include id field - Firestore will auto-generate
      final customerData = {
        'name': customer.name,
        'mobile': customer.mobile,
        'address': customer.address,
        'userMobile': customer.userMobile,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _userCustomersCollection.add(customerData);
      return docRef.id;
    } catch (e) {
      print('❌ Error adding customer: $e');
      throw Exception('Failed to add customer: $e');
    }
  }

  // Update customer
  Future<void> updateCustomer(Customer customer) async {
    try {
      if (customer.id.isEmpty) {
        throw Exception('Customer ID is required for update');
      }
      
      final customerData = {
        'name': customer.name,
        'mobile': customer.mobile,
        'address': customer.address,
        'userMobile': customer.userMobile,
      };
      
      await _userCustomersCollection.doc(customer.id).update(customerData);
    } catch (e) {
      print('❌ Error updating customer: $e');
      throw Exception('Failed to update customer: $e');
    }
  }

  // Delete customer
  Future<void> deleteCustomer(String id) async {
    try {
      await _userCustomersCollection.doc(id).delete();
    } catch (e) {
      print('❌ Error deleting customer: $e');
      throw Exception('Failed to delete customer: $e');
    }
  }

  // Get all customers (stream)
  Stream<List<Customer>> getCustomers() {
    return _userCustomersCollection
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return [];
          
          return snapshot.docs.map((doc) {
            return Customer.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  // Get customer count
  Stream<int> getCustomerCount() {
    return _userCustomersCollection
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}