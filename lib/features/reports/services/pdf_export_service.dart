import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'pdf_common.dart' show PdfCommon;

class PdfExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _pdfCurrencyFormat = NumberFormat('#,##0.00', 'en_IN');

  String? _userName;
  String? _businessName;
  String? _location;
  String? _gstNumber;
  String? _address;

  void setUserDetailsFromProfile(Map<String, dynamic> userData) {
    _userName = userData['name']?.toString();
    _businessName = userData['businessName']?.toString() ?? 'Kadai';
    _location = userData['location']?.toString();
    // Firestore stores the GST number under the key `gst` (see
    // ProfileScreen._updateBusinessProfile), not `gstNumber`.
    _gstNumber = userData['gst']?.toString();
    _address = userData['address']?.toString();
  }

  void setUserDetails({
    String? userName,
    String? businessName,
    String? location,
    String? gstNumber,
    String? address,
  }) {
    _userName = userName;
    _businessName = businessName;
    _location = location;
    _gstNumber = gstNumber;
    _address = address;
  }

  Future<String> exportToPdf({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
    required String title,
    Map<String, dynamic>? userData,
  }) async {
    try {
      if (userData != null) setUserDetailsFromProfile(userData);

      List<Map<String, dynamic>> dataRows;
      Map<String, dynamic> summary = {};

      if (reportType == 'sales' && data is List) {
        dataRows = _parseSalesReports(data);
        summary = _calculateSalesSummary(data);
      } else if (reportType == 'purchase' && data is List) {
        dataRows = _parsePurchaseReports(data);
        summary = _calculatePurchaseSummary(data);
      } else if (reportType == 'inventory' && data is List) {
        dataRows = _parseInventoryReports(data);
      } else if (reportType == 'customer' && data is List) {
        dataRows = _parseCustomerReports(data);
      } else if (reportType == 'supplier' && data is List) {
        dataRows = _parseSupplierReports(data);
      } else if (reportType == 'profit-loss' && data is List) {
        dataRows = _parseProfitLossReports(data);
      } else {
        dataRows = _parseDataToRows(data, reportType);
        summary = _calculateSummary(dataRows, reportType);
      }

      return await _generateMobilePdf(
        dataRows: dataRows,
        summary: summary,
        title: title,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        reportType: reportType,
      );
    } catch (e) {
      return 'Error exporting PDF: $e';
    }
  }

  /// Same inputs as [exportToPdf], but returns the raw saved file path
  /// instead of a status string, and never opens the file — used by
  /// WhatsApp sharing, which needs a real path to hand to the share sheet.
  /// Returns null on web (nothing to point a share sheet at there) or if
  /// generation fails.
  Future<String?> exportToPdfFile({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
    required String title,
    Map<String, dynamic>? userData,
  }) async {
    try {
      if (userData != null) setUserDetailsFromProfile(userData);

      List<Map<String, dynamic>> dataRows;
      Map<String, dynamic> summary = {};

      if (reportType == 'sales' && data is List) {
        dataRows = _parseSalesReports(data);
        summary = _calculateSalesSummary(data);
      } else if (reportType == 'purchase' && data is List) {
        dataRows = _parsePurchaseReports(data);
        summary = _calculatePurchaseSummary(data);
      } else if (reportType == 'inventory' && data is List) {
        dataRows = _parseInventoryReports(data);
      } else if (reportType == 'customer' && data is List) {
        dataRows = _parseCustomerReports(data);
      } else if (reportType == 'supplier' && data is List) {
        dataRows = _parseSupplierReports(data);
      } else if (reportType == 'profit-loss' && data is List) {
        dataRows = _parseProfitLossReports(data);
      } else {
        dataRows = _parseDataToRows(data, reportType);
        summary = _calculateSummary(dataRows, reportType);
      }

      return await _generatePdfAndSave(
        dataRows: dataRows,
        summary: summary,
        title: title,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        reportType: reportType,
      );
    } catch (e) {
      debugPrint('Error generating PDF file: $e');
      return null;
    }
  }

  /// Builds the PDF document and writes it to disk (mobile/desktop), or
  /// triggers the browser print/save dialog (web). Returns the saved file
  /// path on mobile/desktop, or null on web — mirrors the return-path
  /// convention used by `PdfCommon.saveToFile`. Does not open the file;
  /// callers that want to open it (see [_generateMobilePdf]) do so themselves.
  Future<String?> _generatePdfAndSave({
    required List<Map<String, dynamic>> dataRows,
    required Map<String, dynamic> summary,
    required String title,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    final pdf = await _generatePdfDocument(
        dataRows, summary, title, userMobile, startDate, endDate, reportType);

    final fileName =
        '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      // Web: trigger browser print/save dialog via the printing package.
      // There's no real file on disk to share from on web.
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        name: fileName,
      );
      return null;
    }

    // Mobile / Desktop: write to disk.
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final bytes = await pdf.save();
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<String> _generateMobilePdf({
    required List<Map<String, dynamic>> dataRows,
    required Map<String, dynamic> summary,
    required String title,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    try {
      final filePath = await _generatePdfAndSave(
        dataRows: dataRows,
        summary: summary,
        title: title,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        reportType: reportType,
      );

      if (kIsWeb) {
        // Web: browser print/save dialog was already triggered above.
        return '✅ PDF download started. Check your browser downloads.';
      }
      if (filePath == null) {
        return 'Failed to generate PDF.';
      }
      await _openFile(filePath);
      return '✅ PDF saved successfully. Check your files.';
    } catch (e) {
      return 'Failed to generate PDF: $e';
    }
  }

  Future<void> _openFile(String filePath) async {
    final result = await OpenFile.open(filePath);
    debugPrint('Open file result: ${result.message}');
  }

  // ── Report parsers ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _parseInventoryReports(List<dynamic> reports) {
    final rows = <Map<String, dynamic>>[];
    for (var report in reports) {
      try {
        final m = _toMap(report);
        rows.add({
          'Name': _val(m, ['name', 'itemName']),
          'SKU': _val(m, ['sku', 'code']),
          'Category': _val(m, ['category']),
          'Quantity': _val(m, ['quantity', 'qty']),
          'Price': _amount(m, ['price']),
          'Total Value': _amount(m, ['totalValue', 'total']),
          'Status': _val(m, ['status']),
        });
      } catch (_) {}
    }
    return rows;
  }

  List<Map<String, dynamic>> _parseCustomerReports(List<dynamic> reports) {
    final rows = <Map<String, dynamic>>[];
    for (var report in reports) {
      try {
        final m = _toMap(report);
        rows.add({
          'Name': _val(m, ['name']),
          'Mobile': _val(m, ['mobile', 'phone']),
          'Total Purchases': _val(m, ['totalPurchases', 'purchaseCount']),
          'Total Spent': NumberFormat('#,##0.00').format(_amount(m, ['totalSpent', 'revenue'])),
          'Outstanding': _amount(m, ['outstandingBalance', 'due']),
        });
      } catch (_) {}
    }
    return rows;
  }

  List<Map<String, dynamic>> _parseSupplierReports(List<dynamic> reports) {
    final rows = <Map<String, dynamic>>[];
    for (var report in reports) {
      try {
        final m = _toMap(report);
        rows.add({
          'Name': _val(m, ['name']),
          'Phone': _val(m, ['phone']),
          'Address': _val(m, ['address']),
          'Total Orders': _val(m, ['totalOrders', 'orderCount']),
          'Total Purchases': _amount(m, ['totalPurchases']),
          'Pending Payment': _amount(m, ['pendingPayment']),
          'Last Order': _formatDateOnly(m, ['formattedLastOrder', 'lastOrderDate']),
        });
      } catch (_) {}
    }
    return rows;
  }

  List<Map<String, dynamic>> _parseSalesReports(List<dynamic> reports) {
    final rows = <Map<String, dynamic>>[];
    for (var report in reports) {
      try {
        final m = _toMap(report);
        final items = _items(m);
        rows.add({
          'Invoice No.': _val(m, ['invoiceNumber', 'invoiceNo', 'invoice_id']),
          'Customer': _val(m, ['customerName', 'customer', 'clientName']),
          'Mobile': _val(m, ['customerMobile', 'mobile', 'phone', 'contact']),
          'Date': _val(m, ['formattedDate', 'date', 'createdAt', 'invoiceDate']),
          'Subtotal': _amount(m, ['subtotal']),
          'GST Amount': _amount(m, ['gstAmount']),
          'Total Amount': _amount(m, ['totalAmount', 'grandTotal', 'netAmount']),
          'Amount Paid': _amount(m, ['amountPaid', 'paidAmount', 'paid']),
          'Amount Due': _amount(m, ['amountDue', 'dueAmount', 'balance']),
          'Status': _val(m, ['paymentStatus', 'status', 'payment_state']),
          '__categoryRows': _categoryRows(items),
        });
      } catch (_) {}
    }
    return rows;
  }

  List<Map<String, dynamic>> _parsePurchaseReports(List<dynamic> reports) {
    final rows = <Map<String, dynamic>>[];
    for (var report in reports) {
      try {
        final m = _toMap(report);
        final items = _items(m);
        rows.add({
          'Invoice No.': _val(m, ['invoiceNumber', 'invoiceNo', 'invoice_id']),
          'Supplier': _val(m, ['supplierName', 'supplier', 'vendorName']),
          'Mobile': _val(m, ['supplierMobile', 'mobile', 'phone', 'contact']),
          'Date': _val(m, ['formattedDate', 'date', 'createdAt', 'invoiceDate']),
          'Subtotal': _amount(m, ['subtotal']),
          'GST Amount': _amount(m, ['gstAmount']),
          'Total Amount': _amount(m, ['totalAmount', 'grandTotal', 'netAmount']),
          'Amount Paid': _amount(m, ['amountPaid', 'paidAmount', 'paid']),
          'Amount Due': _amount(m, ['amountDue', 'dueAmount', 'balance']),
          'Status': _val(m, ['paymentStatus', 'status', 'payment_state']),
          '__categoryRows': _categoryRows(items),
        });
      } catch (_) {}
    }
    return rows;
  }

  List<Map<String, dynamic>> _parseProfitLossReports(List<dynamic> reports) {
    final rows = <Map<String, dynamic>>[];
    for (var report in reports) {
      try {
        final m = _toMap(report);
        final profitMarginRaw = m['profitMargin'];
        final profitMargin = profitMarginRaw is num
            ? profitMarginRaw.toDouble()
            : double.tryParse(profitMarginRaw?.toString() ?? '') ?? 0.0;

        rows.add({
          'Period':         _val(m, ['period', 'formattedPeriod']),
          'Total Revenue':  _amount(m, ['totalRevenue']),
          'Total Cost':     _amount(m, ['totalCost']),
          'Gross Profit':   _amount(m, ['grossProfit']),
          'Expenses':       _amount(m, ['expenses']),
          'Net Profit':     _amount(m, ['netProfit']),
          'Profit Margin':  '${profitMargin.toStringAsFixed(1)}%',
        });
      } catch (_) {}
    }
    return rows;
  }

  // ── Summary calculators ────────────────────────────────────────────────────

  Map<String, dynamic> _calculateSalesSummary(List<dynamic> reports) {
    double totalAmount = 0, paidAmount = 0, pendingAmount = 0;
    int paidCount = 0, pendingCount = 0;
    for (var report in reports) {
      try {
        final m = _toMap(report);
        final total = _amount(m, ['totalAmount', 'grandTotal', 'netAmount']);
        final due = _amount(m, ['amountDue', 'dueAmount', 'balance']);
        final status = _val(m, ['paymentStatus', 'status', 'payment_state']);
        totalAmount += total;
        if (status.toLowerCase().contains('paid') || due == 0) {
          paidAmount += total;
          paidCount++;
        } else {
          pendingAmount += due;
          pendingCount++;
        }
      } catch (_) {}
    }
    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'totalCount': reports.length,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
    };
  }

  Map<String, dynamic> _calculatePurchaseSummary(List<dynamic> reports) =>
      _calculateSalesSummary(reports);

  Map<String, dynamic> _calculateSummary(
      List<Map<String, dynamic>> rows, String reportType) {
    double totalAmount = 0, paidAmount = 0, pendingAmount = 0;
    int paidCount = 0, pendingCount = 0;
    for (var row in rows) {
      try {
        final amount = _amountFromRow(row);
        totalAmount += amount;
        final status = _statusFromRow(row);
        if (status.contains('paid') || status.contains('completed')) {
          paidAmount += amount;
          paidCount++;
        } else {
          pendingAmount += amount;
          pendingCount++;
        }
      } catch (_) {}
    }
    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'totalCount': rows.length,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
    };
  }

  // ── PDF document builder (supermarket-receipt style) ───────────────────────

  Future<pw.Document> _generatePdfDocument(
    List<Map<String, dynamic>> dataRows,
    Map<String, dynamic> summary,
    String title,
    String userMobile,
    DateTime startDate,
    DateTime endDate,
    String reportType,
  ) async {
    // Load Unicode-capable fonts from assets (supports ₹ and all Indian text)
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold    = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,    // no italic variant in assets; regular as fallback
      boldItalic: bold,
    );

    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.Page(
        // Narrow, auto-height "receipt roll" format — same width a supermarket
        // counter printer uses — instead of a full A4 desktop page. Same
        // explicit margin as `BillInvoicePdfService`/`LedgerReceiptPdfService`
        // so every single- and bulk-document PDF renders at an identical
        // usable content width, not just the same nominal page format.
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _receiptHeader(title, userMobile, startDate, endDate, reportType, dataRows.length),
              _dashedLine(),
              ..._receiptItems(dataRows, reportType),
              _dashedLine(),
              if (reportType == 'sales' || reportType == 'purchase') ...[
                _receiptSummaryTable(summary, reportType),
                pw.SizedBox(height: 8),
              ],
              _receiptFooter(),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  /// A row of evenly-spaced dashes spanning the receipt width — the "- - - -"
  /// divider you'd see between sections on a real till receipt.
  /// Measures the actual available width and generates exactly enough dash
  /// segments to fill it edge-to-edge — a fixed character count doesn't
  /// reliably span the real content width across contexts (it was cutting
  /// off partway across the row before).
  pw.Widget _dashedLine() {
    const dashWidth = 2.5;
    const gapWidth = 2.0;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints?.maxWidth ?? 200;
          final count = (width / (dashWidth + gapWidth)).floor();
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => pw.Container(width: dashWidth, height: 0.75, color: PdfColors.grey500),
            ),
          );
        },
      ),
    );
  }

  /// A single label/value line, label on the left and value on the right —
  /// the standard receipt "field: value" row.
  pw.Widget _kv(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: bold ? 9 : 8,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.SizedBox(width: 6),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: bold ? 9 : 8,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  pw.Widget _receiptHeader(String title, String userMobile, DateTime startDate,
      DateTime endDate, String reportType, int recordCount) {
    final periodRows = [
      ['Period', '${formatDate(startDate)} - ${formatDate(endDate)}'],
      ['Records', '$recordCount'],
      ['Printed', formatDate(DateTime.now())],
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text(title.toUpperCase(),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 4),
        ..._businessIdentityLines(userMobile),
        pw.SizedBox(height: 6),
        if (_usesTableLayout(reportType))
          _boxedKvTable(periodRows)
        else
          for (final r in periodRows) _kv(r[0], r[1]),
      ],
    );
  }

  /// Report types that use the boxed/tabular invoice-style layout (bordered
  /// Period/Records/Printed block, bordered data table instead of plain
  /// vertical fields) — every report type.
  bool _usesTableLayout(String reportType) =>
      reportType == 'sales' ||
      reportType == 'purchase' ||
      reportType == 'inventory' ||
      reportType == 'profit-loss' ||
      reportType == 'customer' ||
      reportType == 'supplier';

  /// A bordered 2-column label/value table — used for the boxed reports'
  /// Period/Records/Printed block and the Sales/Purchase summary table,
  /// matching the reference invoice layout (boxed, not plain text rows).
  pw.Widget _boxedKvTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1.4)},
      children: rows
          .map((r) => pw.TableRow(children: [
                _tableCell(r[0], bold: true),
                _tableCell(r[1]),
              ]))
          .toList(),
    );
  }

  pw.Widget _tableCell(String text, {bool bold = false, bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: bold || header ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  /// Business-identity block — brand name plus the owner's own profile
  /// details (name/location/address/phone/GST), each only rendered when the
  /// underlying value is non-null/non-empty.
  List<pw.Widget> _businessIdentityLines(String userMobile) {
    return [
      pw.Text(PdfCommon.brandName.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if (_userName != null && _userName!.isNotEmpty)
        pw.Text(_userName!,
            textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
      if (_location != null && _location!.isNotEmpty)
        pw.Text(_location!,
            textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      if (_address != null && _address!.isNotEmpty)
        pw.Text(_address!,
            textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      pw.Text('Ph: $userMobile',
          textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      if (_gstNumber != null && _gstNumber!.isNotEmpty)
        pw.Text('GSTIN: $_gstNumber',
            textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
    ];
  }

  /// Boxed SUMMARY table — Total Sales/Purchases / Total Amount / Paid /
  /// Pending as a 4-column header row with one data row beneath it — shown
  /// after all records for the Sales and Purchase reports, matching the
  /// reference invoice layout.
  pw.Widget _receiptSummaryTable(Map<String, dynamic> summary, String reportType) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('Summary:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Total ${reportType == 'sales' ? 'Sales' : 'Purchases'}', header: true),
                _tableCell('Total Amount', header: true),
                _tableCell('Paid', header: true),
                _tableCell('Pending', header: true),
              ],
            ),
            pw.TableRow(children: [
              _tableCell('${summary['totalCount']}'),
              _tableCell(_fmtPdf(summary['totalAmount'])),
              _tableCell('${summary['paidCount']}'),
              _tableCell('${summary['pendingCount']}'),
            ]),
          ],
        ),
      ],
    );
  }

  String _fmtPdf(double amount) => '₹${_pdfCurrencyFormat.format(amount)}';

  /// Sales/Purchase render as per-record bordered category tables; Inventory
  /// renders as one continuous bordered table across every item; Profit &
  /// Loss renders as per-period boxed label/value tables; Customer/Supplier
  /// keep the original heading-line + label/value layout.
  List<pw.Widget> _receiptItems(List<Map<String, dynamic>> rows, String reportType) {
    if (rows.isEmpty) {
      return [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 12),
          child: pw.Text('No records found',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
        ),
      ];
    }

    if (reportType == 'inventory') return [_inventoryTable(rows)];
    if (reportType == 'customer') return [_customerTable(rows)];
    if (reportType == 'supplier') return [_supplierTable(rows)];

    final widgets = <pw.Widget>[];
    for (var i = 0; i < rows.length; i++) {
      pw.Widget block;
      switch (reportType) {
        case 'sales':
        case 'purchase':
          block = _transactionTableBlock(rows[i], reportType);
          break;
        case 'profit-loss':
          block = _profitLossBlock(rows[i]);
          break;
        default:
          block = _genericRecordBlock(rows[i]);
      }
      widgets.add(block);
      if (i != rows.length - 1) widgets.add(_dashedLine());
    }
    return widgets;
  }

  /// Sales/Purchase record layout: Date(left)/Bill No(right) row, party
  /// name/Mobile row (Bill To/Customer for Sales, Bill From/Supplier for
  /// Purchase), a bordered Categories/Total Items/Price-per-unit/Total
  /// Amount table (one row per category, grouping that record's line
  /// items), then Amount Paid/Amount Due beneath the table since they're
  /// record-level figures.
  pw.Widget _transactionTableBlock(Map<String, dynamic> row, String reportType) {
    final isSales = reportType == 'sales';
    String field(String key) => row[key]?.toString() ?? '';
    final categoryRows = (row['__categoryRows'] as List<Map<String, String>>?) ?? const [];
    final partyLabel = isSales ? 'Bill To' : 'Bill From';
    final partyName = isSales ? field('Customer') : field('Supplier');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_fmtPdfCell('Date', row['Date']), style: const pw.TextStyle(fontSize: 7.5)),
            pw.Text('Bill No: ${field('Invoice No.')}',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$partyLabel: $partyName',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.Text('Mobile: ${field('Mobile')}', style: const pw.TextStyle(fontSize: 7.5)),
          ],
        ),
        pw.SizedBox(height: 4),
        _categoryTable(categoryRows),
        pw.SizedBox(height: 3),
        // The category table above only sums each item's own price × qty —
        // it doesn't include GST. Showing Subtotal → GST → Total Amount
        // here (the bill's real, stored totals) is what makes Amount Due
        // reconcile with Total Amount instead of looking inflated/wrong.
        _kv('Subtotal', _fmtPdfCell('Subtotal', row['Subtotal'])),
        if ((row['GST Amount'] as double? ?? 0) > 0)
          _kv('GST', _fmtPdfCell('GST Amount', row['GST Amount'])),
        _kv('Total Amount', _fmtPdfCell('Total Amount', row['Total Amount']), bold: true),
        pw.SizedBox(height: 3),
        _kv('Amount Paid', _fmtPdfCell('Amount Paid', row['Amount Paid'])),
        _kv('Amount Due', _fmtPdfCell('Amount Due', row['Amount Due']), bold: true),
      ],
    );
  }

  /// Bordered table — # / Categories / Total Items / Price-per-unit / Total
  /// Amount — one row per category found in the sale's line items. Column
  /// widths are fixed so a large amount wraps onto a second line inside its
  /// own cell instead of overflowing the receipt width.
  pw.Widget _categoryTable(List<Map<String, String>> rows) {
    if (rows.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text('No items',
            style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(14),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.3),
        4: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('#', header: true),
            _tableCell('Categories', header: true),
            _tableCell('Total Items', header: true),
            _tableCell('Price/unit', header: true),
            _tableCell('Total Amount', header: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(children: [
            _tableCell('${i + 1}'),
            _tableCell(rows[i]['category']!),
            _tableCell(rows[i]['qty']!),
            _tableCell(rows[i]['priceUnit']!),
            _tableCell(rows[i]['amount']!),
          ]),
      ],
    );
  }

  /// One continuous bordered table across every inventory item — # / Item /
  /// Category / Qty / Price / Value, with Status as a small grey line under
  /// the item name (rather than its own column) to keep 6 columns legible
  /// at the roll80 width.
  pw.Widget _inventoryTable(List<Map<String, dynamic>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(14),
        1: pw.FlexColumnWidth(2.4),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.3),
        5: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('#', header: true),
            _tableCell('Item', header: true),
            _tableCell('Category', header: true),
            _tableCell('Qty', header: true),
            _tableCell('Price', header: true),
            _tableCell('Value', header: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(children: [
            _tableCell('${i + 1}'),
            _nameCell(_fmtPdfCell('Name', rows[i]['Name']), _val(rows[i], ['Status'])),
            _tableCell(_fmtPdfCell('Category', rows[i]['Category'])),
            _tableCell(_fmtPdfCell('Quantity', rows[i]['Quantity'])),
            _tableCell(_fmtPdfCell('Price', rows[i]['Price'])),
            _tableCell(_fmtPdfCell('Total Value', rows[i]['Total Value'])),
          ]),
      ],
    );
  }

  /// One continuous bordered table across every customer — # / Name /
  /// Mobile / Purchases / Spent / Outstanding.
  pw.Widget _customerTable(List<Map<String, dynamic>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(14),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('#', header: true),
            _tableCell('Name', header: true),
            _tableCell('Mobile', header: true),
            _tableCell('Purchases', header: true),
            _tableCell('Spent', header: true),
            _tableCell('Outstanding', header: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(children: [
            _tableCell('${i + 1}'),
            _tableCell(_fmtPdfCell('Name', rows[i]['Name'])),
            _tableCell(_fmtPdfCell('Mobile', rows[i]['Mobile'])),
            _tableCell(_fmtPdfCell('Total Purchases', rows[i]['Total Purchases'])),
            _tableCell(_fmtPdfCell('Total Spent', rows[i]['Total Spent'])),
            _tableCell(_fmtPdfCell('Outstanding', rows[i]['Outstanding'])),
          ]),
      ],
    );
  }

  /// One continuous bordered table across every supplier — # / Name(+
  /// Address as a grey sub-line) / Phone / Orders / Purchases / Pending /
  /// Last Order.
  pw.Widget _supplierTable(List<Map<String, dynamic>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(14),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(1.4),
        6: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('#', header: true),
            _tableCell('Name', header: true),
            _tableCell('Phone', header: true),
            _tableCell('Orders', header: true),
            _tableCell('Purchases', header: true),
            _tableCell('Pending', header: true),
            _tableCell('Last Order', header: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(children: [
            _tableCell('${i + 1}'),
            _nameCell(_fmtPdfCell('Name', rows[i]['Name']), _val(rows[i], ['Address'])),
            _tableCell(_fmtPdfCell('Phone', rows[i]['Phone'])),
            _tableCell(_fmtPdfCell('Total Orders', rows[i]['Total Orders'])),
            _tableCell(_fmtPdfCell('Total Purchases', rows[i]['Total Purchases'])),
            _tableCell(_fmtPdfCell('Pending Payment', rows[i]['Pending Payment'])),
            _tableCell(_fmtPdfCell('Last Order', rows[i]['Last Order'])),
          ]),
      ],
    );
  }

  /// A table cell holding a primary line plus an optional smaller grey
  /// sub-line beneath it (e.g. item name + status, supplier name + address).
  pw.Widget _nameCell(String primary, String? sub) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(primary, style: const pw.TextStyle(fontSize: 7.5)),
          if (sub != null && sub.isNotEmpty)
            pw.Text(sub, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  /// One boxed label/value table per period — Total Revenue / Total Cost /
  /// Gross Profit / Expenses / Net Profit / Profit Margin — with the period
  /// label as a bold heading line above it, mirroring the boxed style used
  /// for the Period/Records/Printed header block.
  pw.Widget _profitLossBlock(Map<String, dynamic> row) {
    final period = row['Period']?.toString() ?? '';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (period.isNotEmpty) ...[
          pw.Text(period, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
        ],
        _boxedKvTable([
          ['Total Revenue', _fmtPdfCell('Total Revenue', row['Total Revenue'])],
          ['Total Cost', _fmtPdfCell('Total Cost', row['Total Cost'])],
          ['Gross Profit', _fmtPdfCell('Gross Profit', row['Gross Profit'])],
          ['Expenses', _fmtPdfCell('Expenses', row['Expenses'])],
          ['Net Profit', _fmtPdfCell('Net Profit', row['Net Profit'])],
          ['Profit Margin', _fmtPdfCell('Profit Margin', row['Profit Margin'])],
        ]),
      ],
    );
  }

  /// First column as a bold heading line, the rest as label/value rows —
  /// used as a fallback for any report type not covered by a dedicated
  /// layout above.
  pw.Widget _genericRecordBlock(Map<String, dynamic> row) {
    final columns = row.keys.toList();
    final heading = columns.isNotEmpty ? _fmtPdfCell(columns.first, row[columns.first]) : 'Record';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(heading, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        for (final col in columns.skip(1)) _receiptField(col, row[col]),
      ],
    );
  }

  /// Short values sit on one label/value line; long values (item lists,
  /// categories, etc.) get their own wrapped line beneath the label so they
  /// aren't cut off in the narrow receipt width.
  pw.Widget _receiptField(String column, dynamic value) {
    final formatted = _fmtPdfCell(column, value);
    final label = _fmtColumnName(column);
    if (formatted.length > 18) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$label:', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
            pw.Text(formatted, style: const pw.TextStyle(fontSize: 7.5)),
          ],
        ),
      );
    }
    return _kv(label, formatted);
  }

  pw.Widget _receiptFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('Computer-generated report',
            textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.Text('Inventory Management System',
            textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.SizedBox(height: 6),
        pw.Text('* * *  THANK YOU  * * *',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
      ],
    );
  }

  String _fmtPdfCell(String column, dynamic value) {
    if (value == null) return '-';
    final col = column.toLowerCase();
    truncate(String t, int max) => t.length <= max ? t : '${t.substring(0, max - 2)}..';
    // Period (date range) — never truncate, return as-is
    if (col == 'period') return value.toString();
    if (col.contains('date') && value is String) {
      try { return DateFormat('dd/MM').format(DateTime.parse(value)); } catch (_) {}
    }
    // "Profit Margin" is a percentage, not a currency amount — excluded
    // here even though it contains "profit", so it isn't run through the
    // ₹-amount formatter below (that turned "12.3%" into "₹12.30").
    if (!col.contains('margin') &&
        (col.contains('amount') || col.contains('price') ||
         col.contains('total') || col.contains('value') ||
         col.contains('revenue') || col.contains('cost') ||
         col.contains('profit') || col.contains('expenses'))) {
      try {
        if (value is num) return _fmtPdf(value.toDouble());
        if (value is String) {
          final n = double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), ''));
          if (n != null) return _fmtPdf(n);
        }
      } catch (_) {}
      return value.toString();
    }
    if (col.contains('status')) {
      final s = value.toString().toLowerCase();
      if (s.contains('paid') || s.contains('completed')) return 'Paid';
      if (s.contains('pending') || s.contains('due')) return 'Pending';
      if (s.contains('cancel') || s.contains('void')) return 'Canceled';
      return truncate(value.toString(), 8);
    }
    if (col.contains('name')) return truncate(value.toString(), 28);
    if (col.contains('mobile') || col.contains('phone')) return truncate(value.toString(), 14);
    return truncate(value.toString(), 28);
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Map<String, dynamic> _toMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return {for (var e in data.entries) if (e.key != null) e.key.toString(): e.value};
    return {};
  }

  // Returns only the date part (dd/MM/yyyy) from a date string or timestamp,
  // stripping any time component.
  String _formatDateOnly(Map<String, dynamic> data, List<String> keys) {
    final raw = _val(data, keys);
    if (raw.isEmpty) return '-';
    // Try parsing as DateTime first
    try {
      final dt = DateTime.parse(raw);
      return _dateFormat.format(dt); // dd/MM/yyyy
    } catch (_) {}
    // Already a formatted string — strip anything after the first time separator
    // e.g. "02 Jun 2026 14:30" → "02 Jun 2026"
    final spaceIdx = raw.indexOf(' ');
    if (spaceIdx != -1) {
      // Check if the part after the first space looks like a time (HH:mm)
      final rest = raw.substring(spaceIdx + 1).trim();
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(rest)) {
        return raw.substring(0, spaceIdx);
      }
      // "02 Jun 2026 14:30" has date as first 3 space-separated tokens
      final parts = raw.split(' ');
      if (parts.length >= 3 && RegExp(r'^\d{4}$').hasMatch(parts[2])) {
        return '${parts[0]} ${parts[1]} ${parts[2]}';
      }
    }
    return raw;
  }

  String _val(Map<String, dynamic> data, List<String> keys) {
    for (var k in keys) {
      if (data.containsKey(k) && data[k] != null) return data[k].toString();
    }
    return '';
  }

  double _amount(Map<String, dynamic> data, List<String> keys) {
    for (var k in keys) {
      if (data.containsKey(k) && data[k] != null) {
        try {
          if (data[k] is num) return (data[k] as num).toDouble();
          if (data[k] is String) {
            final clean = data[k].toString().replaceAll(RegExp(r'[^\d.-]'), '');
            return double.tryParse(clean) ?? 0.0;
          }
        } catch (_) {}
      }
    }
    return 0.0;
  }

  List<dynamic> _items(Map<String, dynamic> data) {
    for (var k in ['items', 'products', 'itemList', 'lineItems']) {
      if (data.containsKey(k) && data[k] is List) return data[k];
    }
    return [];
  }

  /// Groups a sale's line items by category — summing quantity and amount
  /// per category — for the Sales report's per-record table (one row per
  /// category, not per raw line item). `Total Items` in that table is the
  /// summed quantity for the category; `Price/unit` is the category's total
  /// amount divided by its total quantity.
  List<Map<String, String>> _categoryRows(List<dynamic> items) {
    final order = <String>[];
    final qtyByCat = <String, double>{};
    final amountByCat = <String, double>{};
    final unitByCat = <String, String?>{};

    for (final item in items) {
      final m = _toMap(item);
      final cat = _val(m, ['category', 'type', 'group']);
      final key = cat.isNotEmpty ? cat : 'Uncategorized';
      final unit = _val(m, ['unit']);
      if (!qtyByCat.containsKey(key)) {
        order.add(key);
        qtyByCat[key] = 0;
        amountByCat[key] = 0;
        unitByCat[key] = unit.isNotEmpty ? unit : null;
      } else if (unitByCat[key] != (unit.isNotEmpty ? unit : null)) {
        unitByCat[key] = null;
      }
      qtyByCat[key] = qtyByCat[key]! + _amount(m, ['quantity', 'qty']);
      amountByCat[key] = amountByCat[key]! + _amount(m, ['total', 'amount', 'lineTotal']);
    }

    final rows = <Map<String, String>>[];
    for (final key in order) {
      final qty = qtyByCat[key]!;
      final amount = amountByCat[key]!;
      final unit = unitByCat[key];
      final qtyStr = qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toString();
      final priceUnit = qty > 0 ? amount / qty : amount;
      rows.add({
        'category': key,
        'qty': unit != null ? '$qtyStr $unit' : qtyStr,
        'priceUnit': _fmtPdf(priceUnit),
        'amount': _fmtPdf(amount),
      });
    }
    return rows;
  }

  List<Map<String, dynamic>> _parseDataToRows(dynamic data, String reportType) {
    final rows = <Map<String, dynamic>>[];
    try {
      if (data == null) return rows;
      if (data is List) {
        for (var item in data) { if (item is Map) rows.add(Map<String, dynamic>.from(item)); }
      } else if (data is Map) {
        rows.add(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return rows;
  }

  double _amountFromRow(Map<String, dynamic> row) {
    for (var field in ['amount', 'total', 'value', 'price', 'grandTotal', 'netAmount', 'totalAmount']) {
      if (row.containsKey(field) && row[field] != null) {
        try {
          final v = row[field];
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0.0;
        } catch (_) {}
      }
    }
    return 0.0;
  }

  String _statusFromRow(Map<String, dynamic> row) {
    for (var field in ['status', 'paymentStatus', 'state', 'paymentState']) {
      if (row.containsKey(field) && row[field] != null) return row[field].toString().toLowerCase();
    }
    return 'pending';
  }

  String _fmtColumnName(String col) => col
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
      .trim()
      .split(' ')
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '')
      .join(' ');

  String formatDate(DateTime date) => _dateFormat.format(date);
}
