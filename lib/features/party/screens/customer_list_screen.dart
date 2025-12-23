import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';
import 'add_edit_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final String userMobile;
  
  const CustomerListScreen({Key? key, required this.userMobile}) : super(key: key);

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late final CustomerService _customerService;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService(widget.userMobile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        title: const Text('Customers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () => _openCustomerModal(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer name or mobile',
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
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _customerService.getCustomers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState();
                }
                final customers = snapshot.data!
                    .where((c) =>
                        c.name.toLowerCase().contains(_search) ||
                        c.mobile.contains(_search))
                    .toList();
                if (customers.isEmpty) {
                  return _emptyState(search: _search);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    return _customerCard(customers[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(Customer customer) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.person, color: Colors.blue),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📞 ${customer.mobile}'),
            if (customer.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('📍 ${customer.address}'),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _openCustomerModal(customer: customer),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(customer),
            ),
          ],
        ),
      ),
    );
  }

  void _openCustomerModal({Customer? customer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditCustomerScreen(
        userMobile: widget.userMobile,
        customer: customer,
      ),
    );
  }

  void _confirmDelete(Customer customer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _customerService.deleteCustomer(customer.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${customer.name}" deleted'),
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

  Widget _emptyState({String search = ''}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            search.isEmpty
                ? 'No customers yet'
                : 'No customers found for "$search"',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Tap + to add your first customer',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}