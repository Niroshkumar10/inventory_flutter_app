// lib/features/bill/screens/view_bill_screen.dart
import 'package:flutter/material.dart';
import 'add_edit_bill_screen.dart';
import '../services/bill_service.dart';
import '../services/bill_invoice_pdf_service.dart';
import '../models/bill_model.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/widgets/document_export_dialog.dart';
import '../../reports/services/pdf_common.dart';

class ViewBillScreen extends StatelessWidget {
  final String billId;
  final String userMobile;

  const ViewBillScreen({
    super.key,
    required this.billId,
    required this.userMobile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final billService = BillService(userMobile);
    
    return StreamBuilder<Bill>(
      stream: billService.getBillStream(billId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
            ),
            body: Center(
              child: Text(
                'Bill not found',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          );
        }
        
        final bill = snapshot.data!;
        return _BillDetailScreen(bill: bill);
      },
    );
  }
}

class _BillDetailScreen extends StatefulWidget {
  final Bill bill;

  const _BillDetailScreen({required this.bill});

  @override
  State<_BillDetailScreen> createState() => __BillDetailScreenState();
}

class __BillDetailScreenState extends State<_BillDetailScreen> {
  late BillService billService;
  
  @override
  void initState() {
    super.initState();
    billService = BillService(widget.bill.userMobile);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSales = widget.bill.type == 'sales';

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          widget.bill.invoiceNumber,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded, color: colorScheme.onSurface),
            tooltip: 'Download',
            onPressed: () => _showExportOptions(context),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppProviders(
                    userMobile: widget.bill.userMobile,
                    child: AddEditBillScreen(
                      type: widget.bill.type,
                      userMobile: widget.bill.userMobile,
                      billToEdit: widget.bill,
                      billService: billService,
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.payment, color: colorScheme.onSurface),
            onPressed: () => _showAddPaymentDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: colorScheme.error),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Bill Header
            Card(
              elevation: isDark ? 4 : 3,
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bill.isGST ? 'TAX INVOICE' : 'BILL',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invoice #: ${widget.bill.invoiceNumber}',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              'Date: ${_formatDate(widget.bill.date)}',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              'Type: ${widget.bill.type.toUpperCase()}',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isSales ? colorScheme.secondary : colorScheme.tertiary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isSales ? Icons.shopping_cart : Icons.inventory,
                            size: 40,
                            color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Party Details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Card(
                            color: (isSales ? colorScheme.secondary : colorScheme.tertiary).withOpacity(0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSales ? 'CUSTOMER:' : 'SUPPLIER:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.bill.partyName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (widget.bill.partyPhone.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Phone: ${widget.bill.partyPhone}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                  if (widget.bill.partyAddress.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.bill.partyAddress,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Items Table
            Card(
              color: colorScheme.surface,
              elevation: isDark ? 4 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                  border: TableBorder.all(
                    color: colorScheme.outline,
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Qty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Rate',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Amount',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...widget.bill.items.map((item) {
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              item.description,
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              item.quantity.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              '₹${item.price.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              '₹${item.total.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Totals
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 300,
                child: Card(
                  color: colorScheme.primary.withOpacity(0.1),
                  elevation: isDark ? 4 : 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildTotalRow('Subtotal:', widget.bill.subtotal),
                        if (widget.bill.isGST)
                          _buildTotalRow('GST (${widget.bill.gstRate}%):', widget.bill.gstAmount),
                        Divider(color: colorScheme.outline),
                        _buildTotalRow('Total Amount:', widget.bill.totalAmount, isTotal: true),
                        if (widget.bill.amountPaid > 0)
                          _buildTotalRow('Amount Paid:', widget.bill.amountPaid),
                        _buildTotalRow(
                          'Amount Due:',
                          widget.bill.amountDue,
                          isDue: widget.bill.amountDue > 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (widget.bill.notes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                color: colorScheme.surface,
                elevation: isDark ? 4 : 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_alt_outlined,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          widget.bill.notes,
                          style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.8),
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Payment Status
            Card(
              color: colorScheme.surface,
              elevation: isDark ? 4 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Status:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.bill.paymentStatus),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.bill.paymentStatus.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false, bool isDue = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDue ? colorScheme.error : colorScheme.onSurface,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isDue ? colorScheme.error : isTotal ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (status.toLowerCase()) {
      case 'paid':
        return colorScheme.secondary;
      case 'partial':
        return colorScheme.tertiary;
      case 'due':
        return colorScheme.error;
      default:
        return colorScheme.onSurface.withOpacity(0.5);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ── Export options dialog (PDF / Excel / WhatsApp) ──────────────────────
  void _showExportOptions(BuildContext context) {
    showDocumentExportDialog(
      context: context,
      title: 'Export Invoice',
      subtitle: 'Choose how to export this invoice',
      onPdf: () async => _downloadInvoice(context),
      onExcel: () async => _downloadInvoiceExcel(context),
      onWhatsApp: () async => _shareViaWhatsApp(context),
    );
  }

  // ── Download invoice PDF ────────────────────────────────────────────────
  void _downloadInvoice(BuildContext context) async {
    final bill = widget.bill;
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Generating invoice PDF...'),
          ],
        ),
        backgroundColor: cs.primary,
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final profile = await BusinessProfile.fetch(bill.userMobile);
      await BillInvoicePdfService().generateAndOpen(bill, profile);
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Invoice downloaded successfully'),
            backgroundColor: cs.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoice: $e'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Download invoice spreadsheet (CSV/Excel) ────────────────────────────
  void _downloadInvoiceExcel(BuildContext context) async {
    final bill = widget.bill;
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Generating invoice spreadsheet...'),
          ],
        ),
        backgroundColor: cs.primary,
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await BillInvoicePdfService().generateExcelAndOpen(bill);
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Invoice spreadsheet downloaded successfully'),
            backgroundColor: cs.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to generate spreadsheet: $e'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── WhatsApp share (PDF only) ───────────────────────────────────────────
  void _shareViaWhatsApp(BuildContext context) async {
    final bill = widget.bill;
    final cs   = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Preparing invoice PDF...'),
          ],
        ),
        backgroundColor: cs.primary,
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    String? filePath;
    try {
      final profile = await BusinessProfile.fetch(bill.userMobile);
      filePath = await BillInvoicePdfService().generateToFile(bill, profile);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoice PDF: $e'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;

    // Web has no local file to hand to a share sheet — the browser's
    // print/save dialog was already shown by generateToFile above.
    if (filePath == null) return;
    final resolvedPath = filePath;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.chat, color: Color(0xFF25D366), size: 28),
                  const SizedBox(width: 12),
                  Text('Share Invoice PDF via WhatsApp',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ],
              ),
              const SizedBox(height: 16),
              // Send to customer directly if phone available
              if (bill.partyPhone.isNotEmpty)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: Color(0xFF25D366)),
                  ),
                  title: Text('Send to ${bill.partyName}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Choose WhatsApp from the share sheet',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await WhatsAppService.instance
                        .shareFile(resolvedPath, caption: 'Invoice ${bill.invoiceNumber}');
                    if (context.mounted) result.showSnackBar(context);
                  },
                ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.share, color: cs.primary),
                ),
                title: const Text('Share to any contact',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Choose WhatsApp from the share sheet'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await WhatsAppService.instance
                      .shareFile(resolvedPath, caption: 'Invoice ${bill.invoiceNumber}');
                  if (context.mounted) result.showSnackBar(context);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(Icons.ios_share, color: cs.onSurface),
                ),
                title: const Text('Share via other apps',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('SMS, Email, Drive…'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await WhatsAppService.instance
                      .shareFile(resolvedPath, caption: 'Invoice ${bill.invoiceNumber}');
                  if (context.mounted) result.showSnackBar(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.bill.amountDue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No amount due'),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amountController = TextEditingController(
      text: widget.bill.amountDue.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Add Payment',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Remaining Due',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              Text(
                '₹${widget.bill.amountDue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Payment Amount',
                  labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: colorScheme.onSurface),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark 
                      ? colorScheme.surfaceContainerHighest 
                      : Colors.white,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || amount > widget.bill.amountDue) return;

                try {
                  await billService.addPayment(widget.bill.id, amount);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Payment recorded successfully'),
                        backgroundColor: colorScheme.secondary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Make Payment'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    final colorScheme = Theme.of(context).colorScheme;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Delete Transaction',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'Are you sure you want to delete this transaction?',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // close dialog immediately
                try {
                  await billService.deleteBill(widget.bill.id);
                  nav.pop(); // go back to bills list
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Transaction deleted'),
                      backgroundColor: colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}