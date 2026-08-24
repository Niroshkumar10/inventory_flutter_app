// lib/features/ledger/screens/ledger_entry_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ledger_model.dart';
import '../services/ledger_receipt_pdf_service.dart';
import '../../party/services/customer_service.dart';
import '../../party/services/supplier_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/widgets/document_export_dialog.dart';
import '../../reports/services/pdf_common.dart';

/// Read-only detail screen for a single [LedgerEntry] — reached by tapping a
/// transaction-history card on the Dues & Borrowing screen (party
/// sale/purchase/payment/receipt entries) or the Cash Book screen (non-party
/// income/expense entries). Shows a "Payment Receipt" (party transactions)
/// or "Receipt/Payment Voucher" (Cash Book) styled summary with a PDF
/// download button and PDF-only share action.
class LedgerEntryDetailScreen extends StatefulWidget {
  final LedgerEntry entry;
  final String userMobile;

  const LedgerEntryDetailScreen({
    super.key,
    required this.entry,
    required this.userMobile,
  });

  @override
  State<LedgerEntryDetailScreen> createState() => _LedgerEntryDetailScreenState();
}

class _LedgerEntryDetailScreenState extends State<LedgerEntryDetailScreen> {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _amountFmt = NumberFormat('#,##0.00', 'en_IN');
  final _pdfService = LedgerReceiptPdfService();

  LedgerPartyInfo? _partyInfo;
  bool _loadingParty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadParty();
  }

  Future<void> _loadParty() async {
    final entry = widget.entry;
    if (!entry.isPartyTransaction || entry.partyId.isEmpty) return;

    setState(() => _loadingParty = true);
    try {
      if (entry.partyType == 'customer') {
        final customer = await CustomerService(widget.userMobile).getCustomerById(entry.partyId);
        if (!mounted) return;
        final address = customer.locationAddress != null && customer.locationAddress!.isNotEmpty
            ? customer.locationAddress
            : customer.address;
        setState(() {
          _partyInfo = LedgerPartyInfo(
            name: customer.name.isNotEmpty ? customer.name : entry.partyName,
            phone: customer.mobile,
            address: address,
          );
        });
      } else if (entry.partyType == 'supplier') {
        final supplier = await SupplierService(widget.userMobile).getSupplierById(entry.partyId);
        if (!mounted) return;
        final address = supplier.locationAddress != null && supplier.locationAddress!.isNotEmpty
            ? supplier.locationAddress
            : supplier.address;
        setState(() {
          _partyInfo = LedgerPartyInfo(
            name: supplier.name.isNotEmpty ? supplier.name : entry.partyName,
            phone: supplier.phone,
            address: address,
          );
        });
      }
    } catch (_) {
      // Party record missing/deleted — just skip the party card, no error UI.
    } finally {
      if (mounted) setState(() => _loadingParty = false);
    }
  }

  LedgerPartyInfo? get _fallbackPartyInfo {
    if (_partyInfo != null) return _partyInfo;
    if (widget.entry.isPartyTransaction && widget.entry.partyName.isNotEmpty) {
      return LedgerPartyInfo(name: widget.entry.partyName);
    }
    return null;
  }

  Future<void> _downloadPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final profile = await BusinessProfile.fetch(widget.userMobile);
      await _pdfService.generateAndOpen(widget.entry, profile, partyInfo: _fallbackPartyInfo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadExcel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _pdfService.generateExcelAndOpen(widget.entry, partyInfo: _fallbackPartyInfo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate spreadsheet: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showExportOptions() {
    showDocumentExportDialog(
      context: context,
      title: 'Export Document',
      subtitle: 'Choose how to export this record',
      onPdf: () async => _downloadPdf(),
      onExcel: () async => _downloadExcel(),
      onWhatsApp: () async => _sharePdf(),
    );
  }

  Future<void> _sharePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final profile = await BusinessProfile.fetch(widget.userMobile);
      final path = await _pdfService.generateToFile(widget.entry, profile, partyInfo: _fallbackPartyInfo);
      // Web has no local file to hand to a share sheet — the browser's
      // print/save dialog was already shown by generateToFile above.
      if (path == null) return;
      final result = await WhatsAppService.instance.shareFile(
        path,
        caption: '${widget.entry.typeLabel} • ₹${_amountFmt.format(widget.entry.amount)}',
      );
      if (mounted) result.showSnackBar(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entry = widget.entry;
    final party = _fallbackPartyInfo;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(entry.typeLabel,
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: cs.onSurface),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download',
              onPressed: _showExportOptions,
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card ──────────────────────────────────────────────
          Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: entry.typeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(entry.typeIcon, color: entry.typeColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.typeLabel,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        if (party != null) ...[
                          const SizedBox(height: 2),
                          Text(party.name,
                              style: TextStyle(
                                  fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
                        ],
                        const SizedBox(height: 2),
                        Text(_dateFmt.format(entry.date),
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurface.withValues(alpha: 0.45))),
                      ],
                    ),
                  ),
                  Text(
                    '₹${_amountFmt.format(entry.amount)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: entry.typeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Party info card ──────────────────────────────────────────
          if (_loadingParty) ...[
            const SizedBox(height: 12),
            const Center(child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )),
          ],
          if (!_loadingParty && party != null) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          entry.partyType == 'customer' ? Icons.person_outline : Icons.local_shipping_outlined,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.partyType == 'customer' ? 'CUSTOMER' : 'SUPPLIER',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(party.name,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    if (party.phone != null && party.phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Ph: ${party.phone}',
                          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
                    ],
                    if (party.address != null && party.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(party.address!,
                          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // ── Details card ─────────────────────────────────────────────
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Details',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  _detailRow(context, 'Date', _dateFmt.format(entry.date)),
                  if (entry.description.isNotEmpty)
                    _detailRow(context, 'Description', entry.description),
                  if (entry.reference.isNotEmpty)
                    _detailRow(context, 'Reference', entry.reference),
                  _detailRow(context, 'Status', entry.statusLabel, valueColor: entry.statusColor),
                  if (entry.category != null && entry.category!.isNotEmpty)
                    _detailRow(context, 'Category', entry.category!),
                  if (entry.dueDate != null)
                    _detailRow(context, 'Due Date', _dateFmt.format(entry.dueDate!)),
                  if (entry.notes.isNotEmpty)
                    _detailRow(context, 'Notes', entry.notes),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? cs.onSurface)),
          ),
        ],
      ),
    );
  }
}
