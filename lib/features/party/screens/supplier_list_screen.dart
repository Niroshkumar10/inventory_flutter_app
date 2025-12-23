import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import 'supplier_form_modal.dart';

class SupplierListScreen extends StatefulWidget {
  final String userMobile;
  
  const SupplierListScreen({Key? key, required this.userMobile}) : super(key: key);

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  late final SupplierService _supplierService;
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Initialize service with userMobile
    _supplierService = SupplierService(widget.userMobile);
    print('👤 Supplier service initialized for user: ${widget.userMobile}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),

      /// 🧭 APP BAR
      appBar: AppBar(
        title: const Text('Suppliers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      /// ➕ ADD SUPPLIER BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () => _openSupplierModal(),
      ),

      body: Column(
        children: [
          /// 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search supplier name or phone',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() => _search = value.toLowerCase());
              },
            ),
          ),

          /// 👤 USER INFO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text(
                  'User: ${widget.userMobile}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                StreamBuilder<int>(
                  stream: _supplierService.getSupplierCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Chip(
                      label: Text('$count suppliers'),
                      backgroundColor: Colors.orange.shade100,
                    );
                  },
                ),
              ],
            ),
          ),

          /// 📋 SUPPLIER LIST
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: _supplierService.getSuppliers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 50),
                        SizedBox(height: 10),
                        Text('Error: ${snapshot.error}'),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState();
                }

                final suppliers = snapshot.data!
                    .where((s) =>
                        s.name.toLowerCase().contains(_search) ||
                        s.phone.contains(_search))
                    .toList();

                if (suppliers.isEmpty) {
                  return _emptyState(search: _search);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    return _supplierCard(suppliers[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🧾 SUPPLIER CARD
  Widget _supplierCard(Supplier supplier) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: const Icon(Icons.store, color: Colors.orange),
        ),
        title: Text(
          supplier.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📞 ${supplier.phone}'),
            if (supplier.email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('✉️ ${supplier.email}'),
              ),
            if (supplier.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('📍 ${supplier.address}'),
              ),
          ],
        ),

        /// ✏️ EDIT + 🗑 DELETE
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _openSupplierModal(supplier: supplier),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(supplier),
            ),
          ],
        ),
      ),
    );
  }

  /// ➕ / ✏️ OPEN ADD–EDIT MODAL
  void _openSupplierModal({Supplier? supplier}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierFormModal(
        userMobile: widget.userMobile,
        supplier: supplier,
      ),
    );
  }

  /// 🗑 DELETE CONFIRMATION
  void _confirmDelete(Supplier supplier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete "${supplier.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _supplierService.deleteSupplier(supplier.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${supplier.name}" deleted'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// 📭 EMPTY STATE
  Widget _emptyState({String search = ''}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_mall_directory_outlined,
              size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            search.isEmpty
                ? 'No suppliers yet'
                : 'No suppliers found for "$search"',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Tap + to add your first supplier',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}