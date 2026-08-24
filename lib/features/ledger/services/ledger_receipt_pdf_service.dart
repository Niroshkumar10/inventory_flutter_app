// lib/features/ledger/services/ledger_receipt_pdf_service.dart
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/ledger_model.dart';
import '../../../core/services/csv_common.dart';
import '../../reports/services/pdf_common.dart';

/// Minimal party-contact bundle for the receipt/voucher PDF. Kept as plain
/// primitives (rather than importing the Customer/Supplier models) so this
/// service doesn't need to know how the caller resolved the party.
class LedgerPartyInfo {
  final String name;
  final String? phone;
  final String? address;

  const LedgerPartyInfo({required this.name, this.phone, this.address});
}

/// Builds a compact "Payment Receipt" (party sale/purchase/payment/receipt
/// entries) or "Receipt/Payment Voucher" (Cash Book income/expense entries)
/// PDF for a single [LedgerEntry] as a narrow "supermarket receipt" style
/// document — same `roll80` page format and dashed-divider look as the
/// bulk-report PDFs (`PdfExportService`), via the shared
/// `PdfCommon.dashedLine()`/`PdfCommon.kv()` helpers. Opens with the shared
/// `PdfCommon.letterhead()` business-identity block before the transaction
/// data and, where relevant, the counterparty's own details.
class LedgerReceiptPdfService {
  static final _amountFmt = NumberFormat('#,##0.00', 'en_IN');
  static final _dateFmt = DateFormat('dd MMM yyyy');

  /// Builds the PDF and either opens it (mobile/desktop) or triggers a
  /// browser download (web). Returns the saved file path, or null on web.
  Future<String?> generateAndOpen(
    LedgerEntry entry,
    BusinessProfile profile, {
    String? title,
    LedgerPartyInfo? partyInfo,
  }) async {
    final pdf = await _build(entry, profile, title: title, partyInfo: partyInfo);
    return PdfCommon.saveAndOpen(pdf, _fileName(entry));
  }

  /// Builds the PDF and saves it to disk without opening it — used to hand
  /// the file path straight to a share sheet (e.g. WhatsApp). Returns null
  /// on web (there's no file to share there — the browser's print/save
  /// dialog has already been shown instead).
  Future<String?> generateToFile(
    LedgerEntry entry,
    BusinessProfile profile, {
    String? title,
    LedgerPartyInfo? partyInfo,
  }) async {
    final pdf = await _build(entry, profile, title: title, partyInfo: partyInfo);
    return PdfCommon.saveToFile(pdf, _fileName(entry));
  }

  String _fileName(LedgerEntry entry) {
    final id = entry.id.isNotEmpty ? entry.id : DateTime.now().millisecondsSinceEpoch.toString();
    return '${entry.type}_$id.pdf';
  }

  /// Generates a CSV ("Excel Spreadsheet") export of the entry's fields
  /// (plus party details, if resolved) — the Excel/CSV counterpart to
  /// [generateAndOpen] for the same [LedgerEntry].
  Future<String?> generateExcelAndOpen(
    LedgerEntry entry, {
    LedgerPartyInfo? partyInfo,
  }) async {
    final lines = <String>[
      CsvCommon.row(['Date', _dateFmt.format(entry.date)]),
      CsvCommon.row(['Type', entry.typeLabel]),
      CsvCommon.row(['Amount', entry.amount]),
      if (entry.reference.isNotEmpty) CsvCommon.row(['Reference', entry.reference]),
      CsvCommon.row(['Status', entry.statusLabel]),
      if (entry.category != null && entry.category!.isNotEmpty)
        CsvCommon.row(['Category', entry.category!]),
      if (entry.dueDate != null) CsvCommon.row(['Due Date', _dateFmt.format(entry.dueDate!)]),
      if (entry.description.isNotEmpty) CsvCommon.row(['Description', entry.description]),
      if (entry.notes.isNotEmpty) CsvCommon.row(['Notes', entry.notes]),
      if (partyInfo != null) ...[
        '',
        CsvCommon.row(['Party Name', partyInfo.name]),
        if (partyInfo.phone != null && partyInfo.phone!.isNotEmpty)
          CsvCommon.row(['Party Phone', partyInfo.phone!]),
        if (partyInfo.address != null && partyInfo.address!.isNotEmpty)
          CsvCommon.row(['Party Address', partyInfo.address!]),
      ],
    ];

    final id = entry.id.isNotEmpty ? entry.id : DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = '${entry.type}_${id}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return CsvCommon.saveAndOpen(lines.join('\n'), fileName);
  }

  String _titleFor(LedgerEntry entry, String? title) {
    if (title != null && title.isNotEmpty) return title;
    if (entry.type == 'income') return 'Receipt Voucher';
    if (entry.type == 'expense') return 'Payment Voucher';
    return 'Payment Receipt';
  }

  Future<pw.Document> _build(
    LedgerEntry entry,
    BusinessProfile profile, {
    String? title,
    LedgerPartyInfo? partyInfo,
  }) async {
    final theme = await PdfCommon.loadTheme();
    final pdf = pw.Document(theme: theme);
    final docTitle = _titleFor(entry, title);

    pdf.addPage(
      pw.Page(
        // Narrow, auto-height "receipt roll" format — matches the bulk-report
        // PDFs instead of a full A5 desktop page.
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Align(
                alignment: pw.Alignment.topRight,
                child: pw.Text(
                  docTitle,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              PdfCommon.letterhead(profile),
              PdfCommon.dashedLine(),
              _buildMetaRow(entry),
              if (partyInfo != null) _partyBlock(entry, partyInfo),
              PdfCommon.dashedLine(),
              _fieldsBlock(entry),
              PdfCommon.dashedLine(),
              PdfCommon.kv('Amount', '₹${_amountFmt.format(entry.amount)}', bold: true),
              PdfCommon.dashedLine(),
              PdfCommon.footer(),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  /// Date on the left, a receipt/reference number on the right, same row —
  /// mirrors the Bill invoice's Date/Bill-No meta row exactly.
  pw.Widget _buildMetaRow(LedgerEntry entry) {
    final refLabel = entry.reference.isNotEmpty ? entry.reference : entry.id;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_dateFmt.format(entry.date), style: const pw.TextStyle(fontSize: 7.5)),
          if (refLabel.isNotEmpty)
            pw.Text('Ref No: $refLabel',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// "Received From:"/"Paid To:"-style label (mirroring the Bill invoice's
  /// "Bill To:"/"Bill From:") followed by the counterparty's address/phone —
  /// chosen from the entry's type so the label reads naturally either way.
  pw.Widget _partyBlock(LedgerEntry entry, LedgerPartyInfo party) {
    final label = switch (entry.type) {
      'payment' => 'Received From',
      'receipt' => 'Paid To',
      'purchase' => 'Bill From',
      _ => 'Bill To',
    };
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('$label: ${party.name}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        if (party.address != null && party.address!.isNotEmpty)
          pw.Text('Address: ${party.address}', style: const pw.TextStyle(fontSize: 7.5)),
        if (party.phone != null && party.phone!.isNotEmpty)
          pw.Text('Phone Number: ${party.phone}', style: const pw.TextStyle(fontSize: 7.5)),
      ],
    );
  }

  pw.Widget _fieldsBlock(LedgerEntry entry) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        PdfCommon.kv('Type', entry.typeLabel),
        PdfCommon.kv('Status', entry.statusLabel),
        if (entry.category != null && entry.category!.isNotEmpty)
          PdfCommon.kv('Category', entry.category!),
        if (entry.dueDate != null) PdfCommon.kv('Due Date', _dateFmt.format(entry.dueDate!)),
        if (entry.description.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text('Description:', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.Text(entry.description, style: const pw.TextStyle(fontSize: 7.5)),
        ],
        if (entry.notes.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text('Notes:', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.Text(entry.notes, style: const pw.TextStyle(fontSize: 7.5)),
        ],
      ],
    );
  }
}
