import 'package:flutter/material.dart';
import '../services/purchase_service.dart';
import '../services/sale_service.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import 'purchase_entry_screen.dart';
import 'sales_entry_screen.dart';

class BillingDashboard extends StatefulWidget {
  @override
  State<BillingDashboard> createState() => _BillingDashboardState();
}

class _BillingDashboardState extends State<BillingDashboard> {
  final _purchaseService = PurchaseService();
  final _salesService = SalesService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ===== SUMMARY CARDS =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryCard(
                    'Total Sales', Colors.green, _salesService.getSales()),
                _summaryCard(
                    'Total Purchases', Colors.orange, _purchaseService.getPurchases()),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dueCard('Due Receivables', Colors.blue, _salesService.getSales()),
                _dueCard('Due Payments', Colors.red, _purchaseService.getPurchases()),
              ],
            ),
            const SizedBox(height: 20),

            /// ===== QUICK ADD BUTTONS =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SalesEntryScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Sale'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PurchaseEntryScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Purchase'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 20),

            /// ===== RECENT TRANSACTIONS =====
            Expanded(
              child: StreamBuilder<List<dynamic>>(
                stream: _combinedTransactions(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final transactions = snapshot.data!;
                  if (transactions.isEmpty)
                    return const Center(child: Text('No transactions found'));

                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            t is Purchase ? Icons.shopping_cart : Icons.sell,
                            color: t is Purchase ? Colors.orange : Colors.green,
                          ),
                          title: Text(t is Purchase
                              ? t.supplierName
                              : t.customerName),
                          subtitle: Text(
                              'Total: ₹${t.totalAmount.toStringAsFixed(2)} | Paid: ₹${t.paidAmount.toStringAsFixed(2)}'),
                          trailing: Text(
                              'Due: ₹${(t.totalAmount - t.paidAmount).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===== SUMMARY CARD =====
  Widget _summaryCard(String title, Color color, Stream<List<dynamic>> stream) {
    return StreamBuilder<List<dynamic>>(
      stream: stream,
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          total = snapshot.data!
              .map((e) => e.totalAmount as double)
              .fold(0, (a, b) => a + b);
        }
        return Container(
          width: MediaQuery.of(context).size.width / 2 - 24,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              Text('₹ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
        );
      },
    );
  }

  /// ===== DUE CARD =====
  Widget _dueCard(String title, Color color, Stream<List<dynamic>> stream) {
    return StreamBuilder<List<dynamic>>(
      stream: stream,
      builder: (context, snapshot) {
        double due = 0;
        if (snapshot.hasData) {
          due = snapshot.data!
              .map((e) => e.totalAmount - e.paidAmount)
              .fold(0, (a, b) => a + b);
        }
        return Container(
          width: MediaQuery.of(context).size.width / 2 - 24,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              Text('₹ ${due.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
        );
      },
    );
  }

  /// ===== COMBINED STREAM =====
  Stream<List<dynamic>> _combinedTransactions() async* {
    final salesStream = _salesService.getSales();
    final purchaseStream = _purchaseService.getPurchases();

    await for (final sales in salesStream) {
      await for (final purchases in purchaseStream) {
       final combined = <dynamic>[...sales, ...purchases];
        combined.sort((a, b) {
          DateTime dateA = a is Sale ? a.date : (a as Purchase).date;
          DateTime dateB = b is Sale ? b.date : (b as Purchase).date;
          return dateB.compareTo(dateA);
        });

        yield combined;
      }
    }
  }
}
