import 'package:flutter/material.dart';
import '../../party/models/supplier_model.dart';
import '../../party/services/supplier_service.dart';
import '../models/purchase_model.dart';
import '../services/purchase_service.dart';

class PurchaseEntryScreen extends StatefulWidget {
  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final _purchaseService = PurchaseService();
  final _supplierService = SupplierService();

  Supplier? selectedSupplier;
  final totalCtrl = TextEditingController();
  final paidCtrl = TextEditingController();

  double get due {
    final total = double.tryParse(totalCtrl.text) ?? 0;
    final paid = double.tryParse(paidCtrl.text) ?? 0;
    return total - paid;
  }

  void _save() async {
    if (selectedSupplier == null || totalCtrl.text.isEmpty) return;

    final purchase = Purchase(
      id: '',
      supplierId: selectedSupplier!.id,
      supplierName: selectedSupplier!.name,
      totalAmount: double.parse(totalCtrl.text),
      paidAmount: double.tryParse(paidCtrl.text) ?? 0,
      date: DateTime.now(),
    );

    await _purchaseService.addPurchase(purchase);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Light blue background
      appBar: AppBar(
        title: const Text('Purchase Entry'),
        centerTitle: true,
        backgroundColor: Colors.lightBlue, // AppBar color
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'New Purchase',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue[800],
                ),
              ),
            ),

            /// Supplier Dropdown
            StreamBuilder<List<Supplier>>(
              stream: _supplierService.getSuppliers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final suppliers = snapshot.data!;

                if (selectedSupplier != null) {
                  final match = suppliers.firstWhere(
                    (s) => s.id == selectedSupplier!.id,
                    orElse: () => suppliers.first,
                  );
                  selectedSupplier = match;
                }

                return DropdownButtonFormField<Supplier>(
                  decoration: InputDecoration(
                    labelText: 'Select Supplier',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: selectedSupplier,
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedSupplier = v),
                );
              },
            ),

            const SizedBox(height: 16),

            _field(totalCtrl, 'Total Amount'),
            _field(paidCtrl, 'Paid Amount'),

            const SizedBox(height: 16),

            /// Due Card
            Card(
              color: Colors.lightBlue[100],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Due Amount',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '₹ ${due.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: const Text(
                  'SAVE PURCHASE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
