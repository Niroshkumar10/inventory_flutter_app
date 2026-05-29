import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ledger_service.dart';
import '../../party/services/customer_service.dart';
import '../../party/services/supplier_service.dart';
import '../../party/models/customer_model.dart';
import '../../party/models/supplier_model.dart';
import '../models/ledger_model.dart';
import 'package:inventory_app/core/utils/app_logger.dart';
import 'package:inventory_app/core/theme/colors.dart';

const _incomeCategories = [
  'Shop Sales',
  'Rental Income',
  'Interest / Returns',
  'Refund Received',
  'Other Income',
];

const _expenseCategories = [
  'Rent',
  'Salary / Wages',
  'Electricity Bill',
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

  final _noteController     = TextEditingController();
  final _amountController   = TextEditingController();
  final _billNoController   = TextEditingController();

  String _selectedType        = 'sale';
  String _selectedPartyType   = 'customer';
  String? _selectedPartyId;
  String _selectedPartyName   = '';
  String _selectedStatus      = 'pending';
  String? _selectedCategory;
  DateTime _selectedDate      = DateTime.now();
  DateTime? _selectedDueDate;

  List<String> get _categoryOptions =>
      _selectedType == 'income' ? _incomeCategories : _expenseCategories;

  bool _isLoading      = false;
  List<dynamic> _parties = [];
  bool _loadingParties = true;

  final _dateFormat = DateFormat('dd MMM yyyy');

  bool get _isEditing => widget.entryToEdit != null;

  bool get _isPartyTransaction =>
      _selectedType == 'sale'     ||
      _selectedType == 'purchase' ||
      _selectedType == 'payment'  ||
      _selectedType == 'receipt';

  String get _typeLabel {
    switch (_selectedType) {
      case 'sale':     return 'Sold to Customer';
      case 'purchase': return 'Bought from Supplier';
      case 'payment':  return 'Customer Paid Me';
      case 'receipt':  return 'I Paid Supplier';
      case 'income':   return 'Money Came In';
      case 'expense':  return 'Money Went Out';
      default:         return 'Record Entry';
    }
  }

  Color get _typeColor {
    switch (_selectedType) {
      case 'sale':     return AppColors.success;
      case 'purchase': return AppColors.warning;
      case 'payment':  return AppColors.customerColor;
      case 'receipt':  return AppColors.ledgerColor;
      case 'income':   return AppColors.secondary;
      case 'expense':  return AppColors.error;
      default:         return AppColors.primary;
    }
  }


  String get _noteHint {
    switch (_selectedType) {
      case 'sale':     return 'What was sold? e.g. Rice, Sugar...';
      case 'purchase': return 'What did you buy? e.g. Vegetables...';
      case 'payment':  return 'e.g. Cash payment received';
      case 'receipt':  return 'e.g. Paid for April order';
      case 'income':   return 'e.g. Shop rent received';
      case 'expense':  return 'e.g. Electricity bill';
      default:         return 'Add a note';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ledgerService   = LedgerService(widget.userMobile);
    _customerService = CustomerService(widget.userMobile);
    _supplierService = SupplierService(widget.userMobile);

    if (widget.initialType != null) _selectedType = widget.initialType!;

    // Derive party type from entry type if not explicitly passed
    if (widget.initialPartyType != null) {
      _selectedPartyType = widget.initialPartyType!;
    } else {
      if (_selectedType == 'sale' || _selectedType == 'payment') {
        _selectedPartyType = 'customer';
      } else if (_selectedType == 'purchase' || _selectedType == 'receipt') {
        _selectedPartyType = 'supplier';
      }
    }

    if (widget.initialPartyId != null) {
      _selectedPartyId   = widget.initialPartyId;
      _selectedPartyName = widget.initialPartyName ?? '';
    }

    // Income/expense are always immediately paid
    if (_selectedType == 'income' || _selectedType == 'expense') {
      _selectedStatus = 'paid';
    }

    if (_isEditing) {
      final e = widget.entryToEdit!;
      _selectedType       = e.type;
      _selectedPartyType  = e.partyType.isNotEmpty ? e.partyType : 'customer';
      _selectedPartyId    = e.partyId.isNotEmpty ? e.partyId : null;
      _selectedPartyName  = e.partyName;
      _selectedStatus     = e.status;
      _selectedCategory   = e.category;
      _selectedDate       = e.date;
      _selectedDueDate    = e.dueDate;
      _noteController.text    = e.description;
      _amountController.text  = e.amount.toStringAsFixed(2);
      _billNoController.text  = e.reference;
    }

    if (_isPartyTransaction) _loadParties();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    _billNoController.dispose();
    super.dispose();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadParties() async {
    try {
      setState(() => _loadingParties = true);

      if (_selectedPartyType == 'customer') {
        final customers = await _customerService.getCustomers().first;
        setState(() {
          _parties = customers;
          if (customers.isNotEmpty && _selectedPartyId == null) {
            final c = customers.first;
            _selectedPartyId   = c.id;
            _selectedPartyName = c.name;
          } else if (_selectedPartyId != null) {
            for (final c in customers) {
              if (c.id == _selectedPartyId) {
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
            _selectedPartyId   = s.id;
            _selectedPartyName = s.name;
          } else if (_selectedPartyId != null) {
            for (final s in suppliers) {
              if (s.id == _selectedPartyId) {
                _selectedPartyName = s.name;
                break;
              }
            }
          }
        });
      }
    } catch (e) {
      appLogger.e('Error loading parties: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load parties: $e'),
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
        content: Text('Please select a ${_selectedPartyType == 'customer' ? 'customer' : 'supplier'}'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;

      double debit = 0, credit = 0;
      switch (_selectedType) {
        case 'sale':     debit  = amount; break;
        case 'purchase': credit = amount; break;
        case 'payment':  credit = amount; break;
        case 'receipt':  debit  = amount; break;
        case 'income':   debit  = amount; break;
        case 'expense':  credit = amount; break;
      }

      // Income/expense are always paid immediately
      final finalStatus = _isPartyTransaction ? _selectedStatus : 'paid';

      LedgerEntry entry;

      if (_isEditing) {
        entry = widget.entryToEdit!.copyWith(
          type:        _selectedType,
          partyId:     _selectedPartyId ?? '',
          partyType:   _isPartyTransaction ? _selectedPartyType : '',
          partyName:   _selectedPartyName,
          date:        _selectedDate,
          description: _noteController.text.trim(),
          debit:       debit,
          credit:      credit,
          reference:   _billNoController.text.trim(),
          notes:       '',
          status:      finalStatus,
          category:    _selectedCategory,
          dueDate:     _selectedDueDate,
          clearDueDate: _selectedDueDate == null,
        );
        await _ledgerService.updateLedgerEntry(entry);
      } else {
        entry = LedgerEntry.create(
          type:        _selectedType,
          partyId:     _selectedPartyId ?? '',
          partyType:   _isPartyTransaction ? _selectedPartyType : '',
          partyName:   _selectedPartyName,
          description: _noteController.text.trim(),
          debit:       debit,
          credit:      credit,
          reference:   _billNoController.text.trim(),
          notes:       '',
          userMobile:  widget.userMobile,
          status:      finalStatus,
          category:    _selectedCategory,
          date:        _selectedDate,
          dueDate:     _selectedDueDate,
        );
        await _ledgerService.addLedgerEntry(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Entry updated' : 'Entry saved'),
          backgroundColor: _typeColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = _typeColor;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Entry' : _typeLabel,
          style: TextStyle(
              color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: cs.surface,
        iconTheme: IconThemeData(color: cs.onSurface),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: color),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.onSurface),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── Amount header ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHighest : const Color(0xFFF5F6FA),
                border: Border(left: BorderSide(color: color, width: 4)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹',
                        style: TextStyle(
                            fontSize: 30,
                            color: color,
                            fontWeight: FontWeight.w300),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            inputDecorationTheme: const InputDecorationTheme(
                              filled: false,
                            ),
                          ),
                          child: TextFormField(
                            controller: _amountController,
                            autofocus: !_isEditing,
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            cursorColor: color,
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.25),
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              errorStyle: TextStyle(color: cs.error),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter the amount';
                              }
                              final a = double.tryParse(v);
                              if (a == null || a <= 0) return 'Enter a valid amount';
                              return null;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Enter amount',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 12),
                  ),
                ],
              ),
            ),

            // ── Scrollable form body ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Party selector
                    if (_isPartyTransaction) ...[
                      _label('Who is this with?'),
                      const SizedBox(height: 8),
                      _partyPicker(cs, isDark, color),
                      const SizedBox(height: 22),
                    ],

                    // Note / description
                    _label('Note'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteController,
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                      decoration: _inputDeco(cs, isDark, color, hint: _noteHint)
                          .copyWith(
                        prefixIcon: Icon(Icons.edit_note_rounded,
                            size: 22,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please add a note'
                          : null,
                    ),

                    const SizedBox(height: 22),

                    // Date
                    _label('Date'),
                    const SizedBox(height: 8),
                    _datePicker(cs, isDark, color),

                    const SizedBox(height: 22),

                    // Category (income / expense only)
                    if (!_isPartyTransaction) ...[
                      _label('Category'),
                      const SizedBox(height: 8),
                      _categoryPicker(cs, isDark, color),
                      const SizedBox(height: 22),
                    ],

                    // Payment status (party transactions only)
                    if (_isPartyTransaction) ...[
                      _label('Payment status'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _statusButton(
                              label: 'Already Paid',
                              icon: Icons.check_circle_outline,
                              active: _selectedStatus == 'paid',
                              activeColor: AppColors.success,
                              cs: cs,
                              isDark: isDark,
                              onTap: () => setState(() {
                                _selectedStatus  = 'paid';
                                _selectedDueDate = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statusButton(
                              label: 'Pending',
                              icon: Icons.access_time_outlined,
                              active: _selectedStatus == 'pending',
                              activeColor: AppColors.warning,
                              cs: cs,
                              isDark: isDark,
                              onTap: () => setState(
                                  () => _selectedStatus = 'pending'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Due date
                    if (_selectedStatus == 'pending' && _isPartyTransaction) ...[
                      const SizedBox(height: 18),
                      _label('Due date (optional)'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _dueDatePicker(cs, isDark)),
                          if (_selectedDueDate != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: cs.error, size: 20),
                              onPressed: () =>
                                  setState(() => _selectedDueDate = null),
                            ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Bill / Invoice No.
                    _label('Bill / Invoice No. (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _billNoController,
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                      decoration: _inputDeco(cs, isDark, color,
                              hint: 'e.g. INV-001')
                          .copyWith(
                        prefixIcon: Icon(Icons.receipt_outlined,
                            size: 20,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _isEditing ? 'Update Entry' : 'Save Entry',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  Widget _label(String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.55),
            letterSpacing: 0.2));
  }

  InputDecoration _inputDeco(
      ColorScheme cs, bool isDark, Color accentColor,
      {required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 14, color: cs.onSurface.withValues(alpha: 0.38)),
      filled: true,
      fillColor: isDark ? cs.surfaceContainerHighest : Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.35))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.35))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 2)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _categoryPicker(ColorScheme cs, bool isDark, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedCategory != null
              ? color.withValues(alpha: 0.6)
              : cs.outline.withValues(alpha: 0.35),
          width: _selectedCategory != null ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor:
              isDark ? cs.surfaceContainerHighest : Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: color, size: 22),
          hint: Row(
            children: [
              Icon(Icons.category_outlined,
                  size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 10),
              Text(
                'Select a category',
                style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
          style:
              TextStyle(fontSize: 15, color: cs.onSurface),
          items: _categoryOptions
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(Icons.label_outline,
                          size: 18,
                          color: _selectedCategory == c
                              ? color
                              : cs.onSurface.withValues(alpha: 0.45)),
                      const SizedBox(width: 10),
                      Text(c,
                          style: TextStyle(
                              fontWeight: _selectedCategory == c
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _selectedCategory == c
                                  ? color
                                  : cs.onSurface)),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
      ),
    );
  }

  Widget _datePicker(ColorScheme cs, bool isDark, Color color) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.calendar_today, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              _dateFormat.format(_selectedDate),
              style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.edit_outlined,
                size: 15, color: cs.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }

  Widget _dueDatePicker(ColorScheme cs, bool isDark) {
    final hasDate = _selectedDueDate != null;
    return InkWell(
      onTap: _pickDueDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? AppColors.warning.withValues(alpha: 0.7)
                : cs.outline.withValues(alpha: 0.35),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: (hasDate ? AppColors.warning : cs.onSurface)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.event_outlined,
                  size: 16,
                  color: hasDate
                      ? AppColors.warning
                      : cs.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(width: 12),
            Text(
              hasDate
                  ? _dateFormat.format(_selectedDueDate!)
                  : 'Tap to set due date',
              style: TextStyle(
                  fontSize: 15,
                  color: hasDate
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.4),
                  fontWeight:
                      hasDate ? FontWeight.w500 : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required ColorScheme cs,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.1)
              : (isDark ? cs.surfaceContainerHighest : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? activeColor : cs.outline.withValues(alpha: 0.35),
            width: active ? 2 : 1,
          ),
          boxShadow: (!active && !isDark)
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              active
                  ? (icon == Icons.check_circle_outline
                      ? Icons.check_circle
                      : Icons.access_time)
                  : icon,
              color: active
                  ? activeColor
                  : cs.onSurface.withValues(alpha: 0.35),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.bold : FontWeight.w500,
                    color: active
                        ? activeColor
                        : cs.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  Widget _partyPicker(ColorScheme cs, bool isDark, Color color) {
    if (_loadingParties) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color)),
            const SizedBox(width: 12),
            Text('Loading...',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 14)),
          ],
        ),
      );
    }

    if (_parties.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              _selectedPartyType == 'customer'
                  ? Icons.person_outline
                  : Icons.store_outlined,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Text(
              'No ${_selectedPartyType == 'customer' ? 'customers' : 'suppliers'} found.\nAdd them from the Parties menu.',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedPartyId != null
              ? color.withValues(alpha: 0.6)
              : cs.outline.withValues(alpha: 0.35),
          width: _selectedPartyId != null ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPartyId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: isDark ? cs.surfaceContainerHighest : Colors.white,
          menuMaxHeight: 360,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: color, size: 22),
          hint: Text(
            'Select ${_selectedPartyType == 'customer' ? 'customer' : 'supplier'}',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4), fontSize: 15),
          ),
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface),
          items: _parties.map<DropdownMenuItem<String>>((dynamic party) {
            final name = party.name as String;
            final contact = _selectedPartyType == 'customer'
                ? (party as Customer).mobile
                : (party as Supplier).phone;
            final isSelected = _selectedPartyId == party.id as String;
            return DropdownMenuItem<String>(
              value: party.id as String,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Center(
                      child: Text(name[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(contact,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5)),
                            maxLines: 1),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded, color: color, size: 16),
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
                      _selectedPartyName = (party as Customer).name;
                    } else {
                      _selectedPartyName = (party as Supplier).name;
                    }
                    break;
                  }
                }
              }
            });
          },
        ),
      ),
    );
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  void _confirmDelete() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete this entry?',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'This cannot be undone. The entry will be removed permanently.',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _deleteEntry();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
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
          content: const Text('Entry deleted'),
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
