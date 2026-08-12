import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
    _businessName = userData['businessName']?.toString() ?? 'My Business';
    _location = userData['location']?.toString();
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
      final pdf = await _generatePdfDocument(
          dataRows, summary, title, userMobile, startDate, endDate, reportType);

      final fileName =
          '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        // Web: trigger browser print/save dialog via the printing package
        await Printing.layoutPdf(
          onLayout: (_) => pdf.save(),
          name: fileName,
        );
        return '✅ PDF download started. Check your browser downloads.';
      } else {
        // Mobile / Desktop: write to disk then open with the system viewer
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final bytes = await pdf.save();
        await File(filePath).writeAsBytes(bytes);
        await _openFile(filePath);
        return '✅ PDF saved successfully. Check your files.';
      }
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
          'Categories': _uniqueCategories(items),
          'Items': _itemsSummary(items),
          'Total Items': _val(m, ['totalItems', 'itemsCount', 'quantity']),
          'Total Amount': _amount(m, ['totalAmount', 'grandTotal', 'netAmount']),
          'Amount Paid': _amount(m, ['amountPaid', 'paidAmount', 'paid']),
          'Amount Due': _amount(m, ['amountDue', 'dueAmount', 'balance']),
          'Status': _val(m, ['paymentStatus', 'status', 'payment_state']),
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
          'Categories': _uniqueCategories(items),
          'Items': _itemsSummary(items),
          'Total Amount': _amount(m, ['totalAmount', 'grandTotal', 'netAmount']),
          'Amount Paid': _amount(m, ['amountPaid', 'paidAmount', 'paid']),
          'Amount Due': _amount(m, ['amountDue', 'dueAmount', 'balance']),
          'Status': _val(m, ['paymentStatus', 'status', 'payment_state']),
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

  // ── PDF document builder ──────────────────────────────────────────────────

  String _getTableTitle(String reportType) {
    switch (reportType) {
      case 'sales':       return 'Sales Details';
      case 'purchase':    return 'Purchase Details';
      case 'profit-loss': return 'Profit & Loss Summary';
      case 'inventory':   return 'Inventory Details';
      case 'customer':    return 'Customer Reports';
      case 'supplier':    return 'Supplier Reports';
      default:            return 'Report Details';
    }
  }

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
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[
            _buildPdfHeader(title, userMobile, startDate, endDate, reportType, dataRows.length),
          ];
          if (reportType == 'sales' || reportType == 'purchase') {
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(_buildPdfSummary(summary, reportType));
          }
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(_buildPdfDataTable(dataRows, reportType, context));
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(_buildPdfFooter());
          return widgets;
        },
      ),
    );
    return pdf;
  }

  pw.Widget _buildPdfHeader(String title, String userMobile,
      DateTime startDate, DateTime endDate, String reportType, int recordCount) {
    return pw.Column(children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_businessName ?? 'My Business',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                if (_userName != null && _userName!.isNotEmpty)
                  pw.Text(_userName!, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if (_location != null && _location!.isNotEmpty)
                  pw.Text(_location!, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700), maxLines: 1),
                if (_address != null && _address!.isNotEmpty)
                  pw.Text(_address!, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600), maxLines: 1),
                if (_gstNumber != null && _gstNumber!.isNotEmpty)
                  pw.Text('GST: $_gstNumber', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Row(children: [
                  pw.Text('Phone: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(userMobile, style: pw.TextStyle(fontSize: 9)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            flex: 7,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                    textAlign: pw.TextAlign.right),
                pw.Text('Inventory Management System',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    textAlign: pw.TextAlign.right),
                pw.Text('Generated: ${formatDate(DateTime.now())} ${DateFormat('HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                    textAlign: pw.TextAlign.right),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _buildInfoRow('Report Type:', reportType.toUpperCase()),
              _buildInfoRow('Period:', '${formatDate(startDate)} to ${formatDate(endDate)}'),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _buildInfoRow('Records:', recordCount.toString()),
              _buildInfoRow('Report ID:',
                  'RPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'),
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ]);
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(width: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 8)),
      ]),
    );
  }

  pw.Widget _buildPdfSummary(Map<String, dynamic> summary, String reportType) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('SUMMARY',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blue100, width: 0.5),
          children: [
            _buildSummaryRow(
                'Total ${reportType == 'sales' ? 'Sales' : 'Purchases'}:', '${summary['totalCount']}',
                'Total Amount:', _fmtPdf(summary['totalAmount'])),
            _buildSummaryRow('Paid:', '${summary['paidCount']}',
                'Paid Amount:', _fmtPdf(summary['paidAmount'])),
            _buildSummaryRow('Pending:', '${summary['pendingCount']}',
                'Pending Amount:', _fmtPdf(summary['pendingAmount'])),
          ],
        ),
      ]),
    );
  }

  pw.TableRow _buildSummaryRow(String l1, String v1, String l2, String v2) {
    cell(String text, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );
    return pw.TableRow(children: [cell(l1, bold: true), cell(v1), cell(l2, bold: true), cell(v2)]);
  }

  String _fmtPdf(double amount) => '₹${_pdfCurrencyFormat.format(amount)}';

  pw.Widget _buildPdfDataTable(
      List<Map<String, dynamic>> rows, String reportType, pw.Context context) {
    if (rows.isEmpty) {
      return pw.Center(
          child: pw.Text('No data available',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)));
    }
    final columns = rows.first.keys.toList();
    final tableData = <List<String>>[
      columns.map(_fmtColumnName).toList(),
      ...rows.map((row) => columns.map((col) => _fmtPdfCell(col, row[col])).toList()),
    ];
    return pw.Column(children: [
      pw.Text(_getTableTitle(reportType),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.TableHelper.fromTextArray(
        context: context,
        data: tableData,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: pw.TextStyle(fontSize: 6.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        cellAlignment: pw.Alignment.centerLeft,
        columnWidths: _columnWidths(columns),
      ),
    ]);
  }

  Map<int, pw.TableColumnWidth> _columnWidths(List<String> columns) {
    final widths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i].toLowerCase();
      if (col == 'period') {
        // Date-range string like "03 May 2026 - 02 Jun 2026" needs ample space
        widths[i] = const pw.FixedColumnWidth(110);
      } else if (col.contains('invoice') || col.contains('number')) {
        widths[i] = const pw.FixedColumnWidth(40);
      } else if (col.contains('customer') || col.contains('supplier')) {
        widths[i] = const pw.FixedColumnWidth(50);
      } else if (col.contains('mobile') || col.contains('phone')) {
        widths[i] = const pw.FixedColumnWidth(35);
      } else if (col.contains('date')) {
        widths[i] = const pw.FixedColumnWidth(30);
      } else if (col.contains('categories')) {
        widths[i] = const pw.FixedColumnWidth(50);
      } else if (col.contains('items')) {
        widths[i] = const pw.FixedColumnWidth(70);
      } else if (col.contains('amount') || col.contains('price') || col.contains('total')) {
        widths[i] = const pw.FixedColumnWidth(40);
      } else if (col.contains('status')) {
        widths[i] = const pw.FixedColumnWidth(25);
      } else if (col.contains('quantity')) {
        widths[i] = const pw.FixedColumnWidth(20);
      } else if (col.contains('unit')) {
        widths[i] = const pw.FixedColumnWidth(20);
      } else {
        widths[i] = const pw.FixedColumnWidth(40);
      }
    }
    return widths;
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
    if (col.contains('amount') || col.contains('price') ||
        col.contains('total') || col.contains('value') ||
        col.contains('revenue') || col.contains('cost') ||
        col.contains('profit') || col.contains('expenses')) {
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
    if (col.contains('name')) return truncate(value.toString(), 12);
    if (col.contains('mobile') || col.contains('phone')) return truncate(value.toString(), 10);
    return truncate(value.toString(), 15);
  }

  pw.Widget _buildPdfFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Note: Computer-generated report.',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Authorized Signature: _________________',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Generated by Inventory Management System',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('(Authorized Person)',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          pw.Text('Page 1/1', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        ]),
      ]),
    );
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

  String _uniqueCategories(List<dynamic> items) {
    final cats = <String>{};
    for (var item in items) {
      final m = _toMap(item);
      final cat = _val(m, ['category', 'type', 'group']);
      cats.add(cat.isNotEmpty ? cat : 'Uncategorized');
    }
    return cats.isEmpty ? 'No categories' : cats.join(', ');
  }

  String _itemsSummary(List<dynamic> items) {
    if (items.isEmpty) return 'No items';
    final summaries = <String>[];
    for (var item in items) {
      final m = _toMap(item);
      final name = _val(m, ['name', 'productName', 'itemName']);
      final qty = _val(m, ['quantity', 'qty', 'amount']);
      if (name.isNotEmpty && qty.isNotEmpty) summaries.add('$name ×$qty');
    }
    if (summaries.isEmpty) return '${items.length} item(s)';
    final s = summaries.join(', ');
    return s.length > 50 ? '${s.substring(0, 47)}...' : s;
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
