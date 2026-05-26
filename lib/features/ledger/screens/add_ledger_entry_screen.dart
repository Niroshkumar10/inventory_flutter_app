import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ledger_service.dart';
import '../../party/services/customer_service.dart';
import '../../party/services/supplier_service.dart';
import '../../party/models/customer_model.dart';
import '../../party/models/supplier_model.dart';
import '../models/ledger_model.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

const _incomeCategories = [
  'Sales Revenue',
  'Rental Income',
  'Interest / Returns',
  'Refund Received',
  'Other Income',
];

const _expenseCategories = [
  'Rent',
  'Salary / Wages',
  'Utilities',
  'Transport',
  'Maintenance',
  'Supplies',
  'Other Expense',
];

class AddLedgerEntryScreen extends StatefulWidget {
  final String userMobile;
  final String? initialType;
  final String? initialPartyType;
  final String? initialPartyId;
  final String? initialPartyName;
  final LedgerEntry? entryToEdit;

  const AddLedgerEntryScreen({
    super.key,
    required this.userMobile,
    this.initialType,
    this.initialPartyType,
    this.initialPartyId,
    this.initialPartyName,
    this.entryToEdit,
  });

  @override
  State<AddLedgerEntryScreen> createState() => _AddLedgerEntryScreenState();
}

class _AddLedgerEntryScreenState extends State<AddLedgerEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LedgerService _ledgerService;
  late final CustomerService _customerService;
  late final SupplierService _supplierService;

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'sale';
  String _selectedPartyType = 'customer';
  String? _selectedPartyId;
  String _selectedPartyName = '';
  String _selectedPartyContact = '';
  String _selectedStatus = 'pending';
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedDueDate;

  bool _isLoading = false;
  List<dynamic> _parties = [];
  bool _loadingParties = true;

  final _dateFormat = DateFormat('dd MMM yyyy');

  bool get _isEditing => widget.entryToEdit != null;

  // income/expense don't need a party
  bool get _isPartyTransaction =>
      _selectedType == 'sale' ||
      _selectedType == 'purchase' ||
      _selectedType == 'payment' ||
      _selectedType == 'receipt';

  List<String> get _categoryOptions =>
      _selectedType == 'income' ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _customerService = CustomerService(widget.userMobile);
    _supplierService = SupplierService(widget.userMobile);

    if (widget.initialType != null) _selectedType = widget.initialType!;
    if (widget.initialPartyType != null) {
      _selectedPartyType = widget.initialPartyType!;
    }
    if (widget.initialPartyId != null) {
      _selectedPartyId = widget.initialPartyId;
      _selectedPartyName = widget.initialPartyName ?? '';
    }

    if (_isEditing) {
      final e = widget.entryToEdit!;
      _selectedType = e.type;
      _selectedPartyType = e.partyType.isNotEmpty ? e.partyType : 'customer';
      _selectedPartyId = e.partyId.isNotEmpty ? e.partyId : null;
      _selectedPartyName = e.partyName;
      _selectedStatus = e.status;
      _selectedDate = e.date;
      _selectedDueDate = e.dueDate;
      _selectedCategory = e.category;
      _descriptionController.text = e.description;
      _amountController.text = e.amount.toStringAsFixed(2);
      _referenceController.text = e.reference;
      _notesController.text = e.notes;
    }

    if (_isPartyTransaction) _loadParties();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    try {
      setState(() => _loadingParties = true);

      if (_selectedPartyType == 'customer') {
        final customers = await _customerService.getCustomers().first;
        setState(() {
          _parties = customers;
          if (customers.isNotEmpty && _selectedPartyId == null) {
            final c = customers.first;
            _selectedPartyId = c.id;
            _selectedPartyName = c.name;
            _selectedPartyContact = c.mobile;
          } else if (_selectedPartyId != null) {
            // Restore contact for pre-selected party
            for (final c in customers) {
              if (c.id == _selectedPartyId) {
                _selectedPartyContact = c.mobile;
                _selectedPartyName = c.name;
                break;
              }
            }
          }
        });
      } else {
        final suppliers = await _supplierService.getSuppliers().first;
        setState(() {
          _parties = suppliers;
          if (suppliers.isNotEmpty && _selectedPartyId == null) {
            final s = suppliers.first;
            _selectedPartyId = s.id;
            _selectedPartyName = s.name;
            _selectedPartyContact = s.phone;
          } else if (_selectedPartyId != null) {
            for (final s in suppliers) {
              if (s.id == _selectedPartyId) {
                _selectedPartyContact = s.phone;
                _selectedPartyName = s.name;
                break;
              }
            }
          }
        });
      }
    } catch (e) {
      appLogger.e('❌ Error loading parties: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error loading parties: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingParties = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? _selectedDate,
      firstDate: _selectedDate,
      lastDate: DateTime(2100),
      helpText: 'SELECT DUE DATE',
    );
    if (picked != null) setState(() => _selectedDueDate = picked);
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isPartyTransaction &&
        (_selectedPartyId == null || _selectedPartyId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a party'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;

      double debit = 0;
      double credit = 0;

      switch (_selectedType) {
        case 'sale':
          debit = amount;
          break;
        case 'purchase':
          credit = amount;
          break;
        case 'payment':
          credit = amount;
          break;
        case 'receipt':
          debit = amount;
          break;
        case 'income':
          debit = amount;
          break;
        case 'expense':
          credit = amount;
          break;
      }

      LedgerEntry entry;

      if (_isEditing) {
        entry = widget.entryToEdit!.copyWith(
          type: _selectedType,
          partyId: _selectedPartyId ?? '',
          partyType: _isPartyTransaction ? _selectedPartyType : '',
          partyName: _selectedPartyName,
          date: _selectedDate,
          description: _descriptionController.text.trim(),
          debit: debit,
          credit: credit,
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          status: _selectedStatus,
          category: _selectedCategory,
          dueDate: _selectedDueDate,
          clearDueDate: _selectedDueDate == null,
        );
        await _ledgerService.updateLedgerEntry(entry);
      } else {
        entry = LedgerEntry.create(
          type: _selectedType,
          partyId: _selectedPartyId ?? '',
          partyType: _isPartyTransaction ? _selectedPartyType : '',
          partyName: _selectedPartyName,
          description: _descriptionController.text.trim(),
          debit: debit,
          credit: credit,
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          userMobile: widget.userMobile,
          status: _selectedStatus,
          category: _selectedCategory,
          date: _selectedDate,
          dueDate: _selectedDueDate,
        );
        await _ledgerService.addLedgerEntry(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Entry updated successfully'
              : 'Entry added successfully'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? cs.surface : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Entry' : 'Add Ledger Entry',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        backgroundColor: cs.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete, color: cs.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Transaction Type ─────────────────────────────────────
              _buildSectionCard(
                icon: Icons.swap_horiz,
                title: 'Transaction Type',
                color: cs.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select transaction type',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _typeChip('sale', 'Sale', Icons.trending_up,
                              cs.secondary),
                          const SizedBox(width: 8),
                          _typeChip('purchase', 'Purchase',
                              Icons.shopping_cart, cs.tertiary),
                          const SizedBox(width: 8),
                          _typeChip('payment', 'Received', Icons.download,
                              Colors.purple),
                          const SizedBox(width: 8),
                          _typeChip(
                              'receipt', 'Paid', Icons.upload, cs.error),
                          const SizedBox(width: 8),
                          _typeChip('income', 'Income', Icons.trending_up,
                              Colors.teal),
                          const SizedBox(width: 8),
                          _typeChip('expense', 'Expense', Icons.trending_down,
                              Colors.deepOrange),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Party section (only for party transactions) ──────────
              if (_isPartyTransaction) ...[
                _buildSectionCard(
                  icon: Icons.people,
                  title: 'Party Type',
                  color: Colors.teal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select party type',
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _partyTypeChip(
                                'customer', 'Customer', Icons.person,
                                cs.secondary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _partyTypeChip(
                                'supplier', 'Supplier', Icons.store,
                                cs.tertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  icon: Icons.list,
                  title: 'Select Party',
                  color: Colors.purple,
                  child: _buildPartySelector(cs, isDark),
                ),
                const SizedBox(height: 16),
              ],

              // ── Category (income/expense only) ───────────────────────
              if (!_isPartyTransaction) ...[
                _buildSectionCard(
                  icon: Icons.category_outlined,
                  title: 'Category',
                  color: _selectedType == 'income'
                      ? Colors.teal
                      : Colors.deepOrange,
                  child: _buildCategorySelector(cs, isDark),
                ),
                const SizedBox(height: 16),
              ],

              // ── Transaction Date ──────────────────────────────────────
              _buildSectionCard(
                icon: Icons.calendar_today,
                title: 'Transaction Date',
                color: Colors.blueGrey,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.surfaceContainerHighest
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event,
                            size: 20,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 12),
                        Text(
                          _dateFormat.format(_selectedDate),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_calendar,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Transaction Details ───────────────────────────────────
              _buildSectionCard(
                icon: Icons.receipt,
                title: 'Transaction Details',
                color: cs.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status
                    _fieldLabel('Status', cs),
                    const SizedBox(height: 6),
                    _buildDropdownContainer(
                      cs: cs,
                      isDark: isDark,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          icon: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                color: cs.secondary, size: 24),
                          ),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface),
                          dropdownColor: isDark
                              ? cs.surfaceContainerHighest
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Row(children: [
                                Icon(Icons.pending_actions_rounded,
                                    size: 18, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Pending'),
                              ]),
                            ),
                            DropdownMenuItem(
                              value: 'paid',
                              child: Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 18, color: Colors.green),
                                SizedBox(width: 10),
                                Text('Paid'),
                              ]),
                            ),
                            DropdownMenuItem(
                              value: 'cancelled',
                              child: Row(children: [
                                Icon(Icons.cancel_rounded,
                                    size: 18, color: Colors.red),
                                SizedBox(width: 10),
                                Text('Cancelled'),
                              ]),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedStatus = v!;
                            // Clear due date when status changes away from pending
                            if (v != 'pending') _selectedDueDate = null;
                          }),
                        ),
                      ),
                    ),

                    // Due date (pending only, party transactions only)
                    if (_selectedStatus == 'pending' && _isPartyTransaction) ...[
                      const SizedBox(height: 16),
                      _fieldLabel('Due Date (optional)', cs),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickDueDate,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? cs.surfaceContainerHighest
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_busy,
                                        size: 20,
                                        color: _selectedDueDate != null
                                            ? Colors.orange
                                            : cs.onSurface
                                                .withValues(alpha: 0.4)),
                                    const SizedBox(width: 12),
                                    Text(
                                      _selectedDueDate != null
                                          ? _dateFormat
                                              .format(_selectedDueDate!)
                                          : 'Set due date',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: _selectedDueDate != null
                                              ? cs.onSurface
                                              : cs.onSurface
                                                  .withValues(alpha: 0.4)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_selectedDueDate != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.close, color: cs.error),
                              onPressed: () =>
                                  setState(() => _selectedDueDate = null),
                            ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Description
                    _fieldLabel('Description', cs),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: _inputDecoration(
                          cs, isDark, Icons.description_outlined,
                          hint: 'Enter description'),
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter description'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Amount
                    _fieldLabel('Amount', cs),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: _inputDecoration(
                          cs, isDark, Icons.currency_rupee,
                          hint: '0.00'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final a = double.tryParse(v);
                        if (a == null || a <= 0) {
                          return 'Please enter valid amount';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Reference
                    _fieldLabel('Reference No.', cs),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _referenceController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: _inputDecoration(
                          cs, isDark, Icons.numbers,
                          hint: 'Invoice / Payment number'),
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    _fieldLabel('Notes', cs),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: _inputDecoration(
                          cs, isDark, Icons.note_outlined,
                          hint: 'Additional notes'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Save Button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isEditing ? cs.primary : cs.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: isDark ? 4 : 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isEditing ? 'Update Entry' : 'Add Entry',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPartySelector(ColorScheme cs, bool isDark) {
    if (_loadingParties) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
            const SizedBox(width: 12),
            Text('Loading parties...',
                style: TextStyle(color: cs.onSurface)),
          ],
        ),
      );
    }

    if (_parties.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            Icon(
              _selectedPartyType == 'customer'
                  ? Icons.person_outline
                  : Icons.store_outlined,
              size: 48,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text('No ${_selectedPartyType}s found',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Please add customers/suppliers first',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose from your list',
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 12),
        _buildDropdownContainer(
          height: 52,
          cs: cs,
          isDark: isDark,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPartyId,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Select ${_selectedPartyType == 'customer' ? 'Customer' : 'Supplier'}',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontSize: 15),
                ),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.purple, size: 24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface),
              dropdownColor:
                  isDark ? cs.surfaceContainerHighest : Colors.white,
              borderRadius: BorderRadius.circular(12),
              menuMaxHeight: 400,
              items: _parties.map<DropdownMenuItem<String>>((dynamic party) {
                final partyName = party.name as String;
                final contact = _selectedPartyType == 'customer'
                    ? (party as Customer).mobile
                    : (party as Supplier).phone;
                final isSelected = _selectedPartyId == party.id;

                return DropdownMenuItem<String>(
                  value: party.id as String,
                  child: Row(
                    children: [
                      Icon(
                        _selectedPartyType == 'customer'
                            ? Icons.person_outline_rounded
                            : Icons.store_outlined,
                        size: 18,
                        color: isSelected
                            ? Colors.purple
                            : cs.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(partyName,
                            style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 14,
                                color: isSelected
                                    ? Colors.purple
                                    : cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? cs.surfaceContainerHighest
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(contact,
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                    cs.onSurface.withValues(alpha: 0.7)),
                            maxLines: 1),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.check_rounded,
                              size: 16, color: Colors.purple),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedPartyId = v;
                  if (v != null) {
                    for (final party in _parties) {
                      if (party.id == v) {
                        if (_selectedPartyType == 'customer') {
                          final c = party as Customer;
                          _selectedPartyName = c.name;
                          _selectedPartyContact = c.mobile;
                        } else {
                          final s = party as Supplier;
                          _selectedPartyName = s.name;
                          _selectedPartyContact = s.phone;
                        }
                        break;
                      }
                    }
                  }
                });
              },
            ),
          ),
        ),
        if (_selectedPartyId != null && _selectedPartyName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.purple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected: $_selectedPartyName',
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.purple,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (_selectedPartyContact.isNotEmpty)
                        Text(_selectedPartyContact,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple.withValues(alpha: 0.8)),
                            maxLines: 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySelector(ColorScheme cs, bool isDark) {
    final accent =
        _selectedType == 'income' ? Colors.teal : Colors.deepOrange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a category',
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 12),
        _buildDropdownContainer(
          height: 52,
          cs: cs,
          isDark: isDark,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Select category',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 15)),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: accent, size: 24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface),
              dropdownColor:
                  isDark ? cs.surfaceContainerHighest : Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: _categoryOptions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _typeChip(
      String type, String label, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedType == type;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected
                  ? color
                  : cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedType = type;
          // Reset category when switching types
          if (type == 'income' || type == 'expense') {
            _selectedCategory = null;
          }
        });
        if (_isPartyTransaction) _loadParties();
      },
      backgroundColor: isDark
          ? cs.surfaceContainerHighest
          : Colors.grey.shade100,
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected
            ? color
            : cs.onSurface.withValues(alpha: 0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: isSelected ? color : cs.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _partyTypeChip(
      String type, String label, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedPartyType == type;

    return FilterChip(
      label: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected
                  ? color
                  : cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedPartyType = type;
          _selectedPartyId = null;
          _selectedPartyName = '';
          _selectedPartyContact = '';
        });
        _loadParties();
      },
      backgroundColor: isDark
          ? cs.surfaceContainerHighest
          : Colors.grey.shade100,
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected
            ? color
            : cs.onSurface.withValues(alpha: 0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: isSelected ? color : cs.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildDropdownContainer({
    required ColorScheme cs,
    required bool isDark,
    required Widget child,
    double height = 48,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline, width: 1),
        borderRadius: BorderRadius.circular(10),
        color: isDark ? cs.surfaceContainerHighest : Colors.white,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(
      ColorScheme cs, bool isDark, IconData prefixIcon,
      {required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 15, color: cs.onSurface.withValues(alpha: 0.4)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.secondary, width: 1.5)),
      filled: true,
      fillColor:
          isDark ? cs.surfaceContainerHighest : Colors.grey.shade50,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: Icon(prefixIcon,
          size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
    );
  }

  Widget _fieldLabel(String text, ColorScheme cs) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }

  void _confirmDelete() {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: cs.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete, color: cs.error, size: 32),
              ),
              const SizedBox(height: 20),
              Text('Delete Entry',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Are you sure you want to delete this entry?',
                  style:
                      TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: cs.outline),
                        foregroundColor: cs.onSurface,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteEntry();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntry() async {
    final cs = Theme.of(context).colorScheme;
    try {
      setState(() => _isLoading = true);
      await _ledgerService.deleteLedgerEntry(widget.entryToEdit!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Entry deleted successfully'),
          backgroundColor: cs.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
