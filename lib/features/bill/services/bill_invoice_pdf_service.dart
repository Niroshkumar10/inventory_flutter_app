// lib/features/bill/services/bill_invoice_pdf_service.dart
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/csv_common.dart';
import '../../reports/services/pdf_common.dart';
import '../models/bill_model.dart';

/// Builds the Tax Invoice / Bill PDF for a single [Bill] as a narrow
/// "supermarket receipt" style document — same `roll80` page format and
/// dashed-divider look as the bulk-report PDFs (`PdfExportService`), via the
/// shared `PdfCommon.dashedLine()`/`PdfCommon.kv()` helpers. Opens with the
/// shared `PdfCommon.letterhead()` business-identity block before the
/// invoice details themselves.
class BillInvoicePdfService {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _currencyFormat = NumberFormat('#,##0.00', 'en_IN');

  static String _fmt(double amount) => '₹${_currencyFormat.format(amount)}';

  /// Generates the invoice PDF, saves it and opens it (or triggers a
  /// browser download on web). Returns the saved file path, or null on web.
  Future<String?> generateAndOpen(Bill bill, BusinessProfile profile) async {
    final pdf = await _buildDocument(bill, profile);
    return PdfCommon.saveAndOpen(pdf, _fileName(bill));
  }

  /// Generates the invoice PDF and saves it to disk without opening it —
  /// used when the caller wants to hand the file straight to a share sheet.
  /// Returns null on web (there's no file to share there — the browser's
  /// print/save dialog has already been shown instead).
  Future<String?> generateToFile(Bill bill, BusinessProfile profile) async {
    final pdf = await _buildDocument(bill, profile);
    return PdfCommon.saveToFile(pdf, _fileName(bill));
  }

  String _fileName(Bill bill) {
    final safeInvoiceNumber =
        bill.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'Invoice_${safeInvoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }

  /// Generates a CSV ("Excel Spreadsheet") export of the bill's key fields
  /// plus a line-item breakdown, saves it and opens it — the Excel/CSV
  /// counterpart to [generateAndOpen] for the same [Bill].
  Future<String?> generateExcelAndOpen(Bill bill) async {
    final lines = <String>[
      CsvCommon.row(['Invoice Number', bill.invoiceNumber]),
      CsvCommon.row(['Date', _dateFormat.format(bill.date)]),
      CsvCommon.row(['Type', bill.type.toUpperCase()]),
      CsvCommon.row(['Party Name', bill.partyName]),
      CsvCommon.row(['Party Phone', bill.partyPhone]),
      CsvCommon.row(['Party Address', bill.partyAddress]),
      CsvCommon.row(['Subtotal', bill.subtotal]),
      if (bill.isGST) ...[
        CsvCommon.row(['GST Rate (%)', bill.gstRate]),
        CsvCommon.row(['GST Amount', bill.gstAmount]),
      ],
      CsvCommon.row(['Total Amount', bill.totalAmount]),
      CsvCommon.row(['Amount Paid', bill.amountPaid]),
      CsvCommon.row(['Amount Due', bill.amountDue]),
      CsvCommon.row(['Payment Status', bill.paymentStatus]),
      '',
      CsvCommon.row(['Description', 'Quantity', 'Unit', 'Rate', 'Amount']),
      ...bill.items.map((item) => CsvCommon.row(
            [item.itemName, item.quantity, item.unit ?? '', item.price, item.total],
          )),
    ];

    final safeInvoiceNumber =
        bill.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final fileName =
        'Invoice_${safeInvoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return CsvCommon.saveAndOpen(lines.join('\n'), fileName);
  }

  Future<pw.Document> _buildDocument(Bill bill, BusinessProfile profile) async {
    final theme = await PdfCommon.loadTheme();
    final pdf = pw.Document(theme: theme);
    final isSales = bill.type == 'sales';

    pdf.addPage(
      pw.Page(
        // Narrow, auto-height "receipt roll" format — matches the bulk-report
        // PDFs instead of a full A4 desktop page. `roll80`'s height is
        // infinite by design (a continuous roll, not a fixed page), which is
        // only valid with a single `pw.Page` that grows to fit its content —
        // `pw.MultiPage` requires a finite height to paginate and asserts
        // otherwise, so it can't be used with this page format.
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildTitle(bill),
            PdfCommon.letterhead(profile),
            PdfCommon.dashedLine(),
            _buildInvoiceMeta(bill),
            _buildPartyBlock(bill, isSales),
            PdfCommon.dashedLine(),
            _buildItemsHeader(),
            PdfCommon.dashedLine(),
            ..._buildItems(bill),
            PdfCommon.dashedLine(),
            _buildTotals(bill),
            if (bill.notes.isNotEmpty) ...[
              PdfCommon.dashedLine(),
              _buildNotes(bill),
            ],
            PdfCommon.dashedLine(),
            PdfCommon.footer(),
          ],
        ),
      ),
    );

    return pdf;
  }

  // ── Sections ────────────────────────────────────────────────────────────

  pw.Widget _buildTitle(Bill bill) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Align(
        alignment: pw.Alignment.topRight,
        child: pw.Text(
          bill.isGST ? 'Tax Invoice' : 'Bill',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  /// Date/time on the left, Bill No / Invoice # on the right, same row.
  pw.Widget _buildInvoiceMeta(Bill bill) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${_dateFormat.format(bill.date)}  ${_timeFormat.format(bill.date)}',
            style: const pw.TextStyle(fontSize: 7.5),
          ),
          pw.Text(
            'Bill No: ${bill.invoiceNumber}',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPartyBlock(Bill bill, bool isSales) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          '${isSales ? 'Bill To' : 'Bill From'}: ${bill.partyName}',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        if (bill.partyAddress.isNotEmpty)
          pw.Text('Address: ${bill.partyAddress}', style: const pw.TextStyle(fontSize: 7.5)),
        if (bill.partyPhone.isNotEmpty)
          pw.Text('Phone Number: ${bill.partyPhone}', style: const pw.TextStyle(fontSize: 7.5)),
      ],
    );
  }

  /// Fixed 5-column header — `#` / `Item` / `Qty` / `Price/unit` / `Amount` —
  /// matching the reference invoice's table layout exactly. Column widths
  /// are shared with [PdfCommon.itemTableRow] so the header and every row
  /// line up, and so every other PDF that lists items (e.g. the per-record
  /// tables inside Report PDFs) renders an identical table shape.
  pw.Widget _buildItemsHeader() => PdfCommon.itemTableHeader();

  /// One real column-aligned row per line item — bold, with an optional
  /// indented "GST X%  HSN: Y" sub-line beneath it when that item carries
  /// GST/HSN data. The app doesn't track per-item GST/HSN today (only a
  /// single combined GST rate for the whole bill, applied in [_buildTotals])
  /// so this sub-line never renders yet — it's structured to pick it up
  /// automatically if per-item tax fields are ever added to [BillItem].
  List<pw.Widget> _buildItems(Bill bill) {
    if (bill.items.isEmpty) {
      return [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 12),
          child: pw.Text('No items',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
        ),
      ];
    }

    final widgets = <pw.Widget>[];
    for (var i = 0; i < bill.items.length; i++) {
      final item = bill.items[i];
      widgets.add(
        PdfCommon.itemTableRow(
          num: '${i + 1}',
          item: item.itemName,
          qty: _formatQuantity(item.quantity, item.unit),
          price: _fmt(item.price),
          amount: _fmt(item.total),
        ),
      );
      if (i != bill.items.length - 1) widgets.add(pw.SizedBox(height: 6));
    }
    return widgets;
  }

  String _formatQuantity(double quantity, String? unit) {
    final qtyStr = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toString();
    return unit != null && unit.isNotEmpty ? '$qtyStr $unit' : qtyStr;
  }

  /// Full totals block — Sub Total / Taxable Amount / CGST / SGST / Discount
  /// / Total Amount / Received Amount / Due Balance. The app doesn't track a
  /// separate discount amount on a [Bill] today, so that row always shows
  /// ₹0.00 rather than being hidden — Taxable Amount is therefore always
  /// equal to the subtotal, since there's nothing on top of it to adjust
  /// for yet.
  pw.Widget _buildTotals(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        PdfCommon.kv('Sub Total', _fmt(bill.subtotal)),
        PdfCommon.dashedLine(),
        PdfCommon.kv('Taxable Amount', _fmt(bill.subtotal)),
        if (bill.isGST) ...[
          PdfCommon.kv('CGST (${_trimZero(bill.gstRate / 2)}%)', _fmt(bill.gstAmount / 2)),
          PdfCommon.kv('SGST (${_trimZero(bill.gstRate / 2)}%)', _fmt(bill.gstAmount / 2)),
        ],
        PdfCommon.kv('Discount', _fmt(0)),
        PdfCommon.dashedLine(),
        PdfCommon.kv('Total Amount', _fmt(bill.totalAmount), bold: true),
        PdfCommon.dashedLine(),
        PdfCommon.kv('Received Amount', _fmt(bill.amountPaid)),
        PdfCommon.kv('Due Balance', _fmt(bill.amountDue), bold: true),
      ],
    );
  }

  String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  pw.Widget _buildNotes(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('NOTES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(bill.notes, style: const pw.TextStyle(fontSize: 7.5)),
      ],
    );
  }
}
