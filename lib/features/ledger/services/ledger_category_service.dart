// lib/features/ledger/services/ledger_category_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ledger_category_model.dart';

/// Default category names/icons — kept identical to the categories that
/// used to be hardcoded in AddLedgerEntryScreen so existing users see the
/// exact same list the first time their categories are loaded from
/// Firestore instead of the old const lists.
const List<Map<String, String>> _kDefaultIncomeCategories = [
  {'name': 'Shop Sales', 'icon': 'storefront'},
  {'name': 'Rental Income', 'icon': 'home'},
  {'name': 'Interest / Returns', 'icon': 'interest'},
  {'name': 'Refund Received', 'icon': 'refund'},
  {'name': 'Other Income', 'icon': 'other'},
];

const List<Map<String, String>> _kDefaultExpenseCategories = [
  {'name': 'Rent', 'icon': 'rent'},
  {'name': 'Salary / Wages', 'icon': 'salary'},
  {'name': 'Electricity Bill', 'icon': 'electricity'},
  {'name': 'Transport', 'icon': 'transport'},
  {'name': 'Maintenance', 'icon': 'maintenance'},
  {'name': 'Supplies', 'icon': 'supplies'},
  {'name': 'Other Expense', 'icon': 'other'},
];

class LedgerCategoryService {
  final String userMobile;

  LedgerCategoryService(this.userMobile);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's ledger-categories collection reference
  CollectionReference get _categoriesCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('ledgerCategories');
  }

  // Marker doc tracking which types have already been seeded, so deleting
  // every category of a type intentionally doesn't cause it to silently
  // refill with defaults on the next app launch.
  DocumentReference get _metaDoc => _categoriesCollection.doc('_meta');

  // ✅ GET CATEGORIES (filtered by type, ordered by sortOrder then name)
  Stream<List<LedgerCategory>> getCategories({required String type}) {
    return _categoriesCollection
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
      final categories = snapshot.docs
          .where((doc) => doc.id != '_meta')
          .map((doc) => LedgerCategory.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      categories.sort((a, b) {
        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) return sortCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return categories;
    });
  }

  // ✅ ADD CATEGORY
  Future<void> addCategory(LedgerCategory category) async {
    try {
      await _categoriesCollection.add(category.toMap());
    } catch (e) {
      throw Exception('Failed to add category: $e');
    }
  }

  // ✅ UPDATE CATEGORY
  Future<void> updateCategory(LedgerCategory category) async {
    try {
      if (category.id.isEmpty) {
        throw Exception('Category ID is required for update');
      }
      await _categoriesCollection.doc(category.id).update(category.toMap());
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  // ✅ DELETE CATEGORY
  Future<void> deleteCategory(String id) async {
    try {
      await _categoriesCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // ✅ SEED DEFAULTS — runs once per type. Existing users relied on the old
  // hardcoded lists, so the very first time a user's category collection is
  // touched for a given type we backfill it with the same default names.
  // A `seeded` marker on the `_meta` doc makes sure this only ever happens
  // once per type — if the user later deletes every category on purpose,
  // it will NOT come back.
  Future<void> seedDefaultsIfEmpty(String type) async {
    try {
      final metaSnap = await _metaDoc.get();
      final metaData =
          metaSnap.exists ? metaSnap.data() as Map<String, dynamic>? : null;
      final seeded =
          Map<String, dynamic>.from(metaData?['seeded'] as Map? ?? {});

      if (seeded[type] == true) return; // already seeded — never re-seed

      final existing = await _categoriesCollection
          .where('type', isEqualTo: type)
          .limit(1)
          .get();

      final batch = _firestore.batch();

      if (existing.docs.isEmpty) {
        final defaults =
            type == 'income' ? _kDefaultIncomeCategories : _kDefaultExpenseCategories;
        for (var i = 0; i < defaults.length; i++) {
          final docRef = _categoriesCollection.doc();
          final category = LedgerCategory.create(
            name: defaults[i]['name']!,
            type: type,
            icon: defaults[i]['icon']!,
            userMobile: userMobile,
            sortOrder: i,
          );
          batch.set(docRef, category.toMap());
        }
      }

      seeded[type] = true;
      batch.set(_metaDoc, {'seeded': seeded}, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to seed default categories: $e');
    }
  }
}
