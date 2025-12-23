import 'package:flutter/material.dart';
import '../../party/models/customer_model.dart';
import '../../party/services/customer_service.dart';
import '../models/sale_model.dart';
import '../services/sale_service.dart';

class SalesEntryScreen extends StatefulWidget {
  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final _saleService = SalesService();
  final _customerService = CustomerService();

  Customer? selectedCustomer;
  final totalCtrl = TextEditingController();
  final paidCtrl = TextEditingController();

  double get due {
    final total = double.tryParse(totalCtrl.text) ?? 0;
    final paid = double.tryParse(paidCtrl.text) ?? 0;
    return total - paid;
  }

  void _save() async {
    if (selectedCustomer == null || totalCtrl.text.isEmpty) return;

    final sale = Sale(
      id: '',
      customerId: selectedCustomer!.id,
      customerName: selectedCustomer!.name,
      totalAmount: double.parse(totalCtrl.text),
      paidAmount: double.tryParse(paidCtrl.text) ?? 0,
      date: DateTime.now(),
    );

    await _saleService.addSale(sale);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Light blue background
      appBar: AppBar(
        title: const Text('Sales Entry'),
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
                'New Sale',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue[800],
                ),
              ),
            ),

            /// Customer Dropdown
            StreamBuilder<List<Customer>>(
              stream: _customerService.getCustomers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final customers = snapshot.data!;

                if (selectedCustomer != null) {
                  final match = customers.firstWhere(
                    (c) => c.id == selectedCustomer!.id,
                    orElse: () => customers.first,
                  );
                  selectedCustomer = match;
                }

                return DropdownButtonFormField<Customer>(
                  decoration: InputDecoration(
                    labelText: 'Select Customer',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: selectedCustomer,
                  items: customers
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedCustomer = v),
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
                  'SAVE SALE',
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
