// lib/features/reports/services/export_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// Import universal_html for web
import 'package:universal_html/html.dart' as html;

// Import for mobile file operations
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// Import PDF packages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _pdfCurrencyFormat = NumberFormat('#,##0.00', 'en_IN');

  // Export to PDF
  Future<String> exportToPdf({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
    required String title,
  }) async {
    try {
      print('📄 Starting PDF export for $reportType...');
      
      // Process real data
      final dataRows = _parseDataToRows(data, reportType);
      final summary = _calculateSummary(dataRows, reportType);
      
      if (kIsWeb) {
        // ============ WEB VERSION ============
        final pdf = _generatePdfDocument(dataRows, summary, title, userMobile, startDate, endDate, reportType);
        final bytes = await pdf.save();
        final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final success = await _downloadPdfWeb(bytes, fileName);
        
        if (success) {
          return '✅ PDF file downloaded! Check your downloads folder.';
        } else {
          return '❌ PDF download failed. Check browser console for details.';
        }
      } else {
        // ============ MOBILE VERSION ============
        return await _generateMobilePdf(
          dataRows: dataRows,
          summary: summary,
          title: title,
          userMobile: userMobile,
          startDate: startDate,
          endDate: endDate,
          reportType: reportType,
        );
      }
    } catch (e) {
      print('❌ PDF Export Error: $e');
      return 'Error exporting PDF: $e';
    }
  }

  // Export to Excel/CSV
  Future<String> exportToExcel({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
  }) async {
    try {
      print('📊 Starting Excel export for $reportType...');
      
      final csvContent = _createCsvContent(
        reportType: reportType,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        data: data,
      );
      
      if (kIsWeb) {
        // ============ WEB VERSION ============
        final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
        final success = await _realWebDownload(csvContent, fileName, 'text/csv');
        
        if (success) {
          return '✅ Excel (CSV) file downloaded! Check your downloads folder.';
        } else {
          return '❌ Download failed. Check browser console for details.';
        }
      } else {
        // ============ MOBILE VERSION ============
        return await _saveCsvToMobile(csvContent, reportType);
      }
    } catch (e) {
      print('❌ Excel Export Error: $e');
      return 'Error exporting Excel: $e';
    }
  }

  // ============ PDF GENERATION ============

  pw.Document _generatePdfDocument(
    List<Map<String, dynamic>> dataRows,
    Map<String, dynamic> summary,
    String title,
    String userMobile,
    DateTime startDate,
    DateTime endDate,
    String reportType,
  ) {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(10), // Reduced margin for mobile
        build: (pw.Context context) {
          return [
            // Header
            _buildPdfHeader(title, userMobile, startDate, endDate, reportType, dataRows.length),
            
            // Summary
            pw.SizedBox(height: 12), // Reduced spacing
            _buildPdfSummary(summary, reportType),
            
            // Data table
            pw.SizedBox(height: 12), // Reduced spacing
            _buildPdfDataTable(dataRows, reportType, context),
            
            // Footer
            pw.SizedBox(height: 20), // Reduced spacing
            _buildPdfFooter(),
          ];
        },
      ),
    );
    
    return pdf;
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
      final pdf = _generatePdfDocument(dataRows, summary, title, userMobile, startDate, endDate, reportType);
      
      // Save PDF to file on mobile
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      // Save the PDF
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      
      print('📄 PDF saved to: $filePath');
      
      // Open the file
      await openFile(filePath);
      
      return '✅ PDF saved to: $filePath';
    } catch (e) {
      print('❌ Mobile PDF generation error: $e');
      return 'Failed to generate PDF: $e';
    }
  }

  // ============ PDF WIDGET BUILDERS (WITH REDUCED FONT SIZES) ============

  pw.Widget _buildPdfHeader(
    String title,
    String userMobile,
    DateTime startDate,
    DateTime endDate,
    String reportType,
    int recordCount,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 18, // Reduced from 24
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3), // Reduced
        pw.Text(
          'Inventory Management System',
          style: pw.TextStyle(
            fontSize: 8, // Reduced from 10
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          'Generated on: ${formatDate(DateTime.now())} at ${DateFormat('HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 8, // Reduced from 10
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 12), // Reduced from 20
        pw.Container(
          padding: const pw.EdgeInsets.all(8), // Reduced from 10
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4), // Reduced from 5
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('User ID:', userMobile),
                  _buildInfoRow('Period:', '${formatDate(startDate)} to ${formatDate(endDate)}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Type:', reportType.toUpperCase()),
                  _buildInfoRow('Records:', recordCount.toString()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8, // Reduced from 10
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 3), // Reduced from 5
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 8), // Reduced from 10
        ),
      ],
    );
  }

  pw.Widget _buildPdfSummary(Map<String, dynamic> summary, String reportType) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8), // Reduced from 10
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(4), // Reduced from 5
        border: pw.Border.all(color: PdfColors.blue200, width: 0.8), // Reduced from 1
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              fontSize: 11, // Reduced from 14
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 6), // Reduced from 10
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blue100, width: 0.5), // Reduced width
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced from 5
                    child: pw.Text('Total ${reportType == 'sales' ? 'Sales' : 'Purchases'}:',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('${summary['totalCount']}',
                      style: pw.TextStyle(fontSize: 8)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('Total Amount:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text(_formatAmountForPdf(summary['totalAmount']),
                      style: pw.TextStyle(fontSize: 8), // Reduced font
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('Paid:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('${summary['paidCount']}',
                      style: pw.TextStyle(fontSize: 8)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('Paid Amount:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text(_formatAmountForPdf(summary['paidAmount']),
                      style: pw.TextStyle(fontSize: 8), // Reduced font
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('Pending:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('${summary['pendingCount']}',
                      style: pw.TextStyle(fontSize: 8)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text('Pending Amount:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), // Reduced font
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4), // Reduced
                    child: pw.Text(_formatAmountForPdf(summary['pendingAmount']),
                      style: pw.TextStyle(fontSize: 8), // Reduced font
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmountForPdf(double amount) {
    return 'Rs. ${_pdfCurrencyFormat.format(amount)}';
  }

  pw.Widget _buildPdfDataTable(List<Map<String, dynamic>> rows, String reportType, pw.Context context) {
    if (rows.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No data available',
          style: pw.TextStyle(
            fontSize: 11, // Reduced from 14
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      );
    }
    
    // Get columns from first row
    final columns = rows.first.keys.toList();
    
    // Prepare table data
    final tableData = <List<String>>[
      // Header row
      columns.map((col) => _formatColumnName(col)).toList(),
      // Data rows
      ...rows.map((row) => 
        columns.map((col) => _formatPdfCellValue(col, row[col])).toList()
      ),
    ];
    
    return pw.Column(
      children: [
        pw.Text(
          '${reportType == 'sales' ? 'Sales' : 'Purchase'} Details',
          style: pw.TextStyle(
            fontSize: 13, // Reduced from 16
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6), // Reduced from 10
        pw.TableHelper.fromTextArray(
          context: context,
          data: tableData,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5), // Reduced width
          headerStyle: pw.TextStyle(
            fontSize: 8, // Reduced font
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.blue700,
          ),
          cellStyle: pw.TextStyle(fontSize: 7), // Reduced from 10 to 7
          cellPadding: const pw.EdgeInsets.all(3), // Reduced from 5
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: _getMobileColumnWidths(columns), // Use mobile-optimized column widths
        ),
      ],
    );
  }

  // Define column widths for mobile optimization
  Map<int, pw.TableColumnWidth> _getMobileColumnWidths(List<String> columns) {
    final widths = <int, pw.TableColumnWidth>{};
    
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i].toLowerCase();
      
      if (col.contains('amount') || col.contains('price') || col.contains('total')) {
        widths[i] = const pw.FixedColumnWidth(35); // Compact for mobile
      } else if (col.contains('status')) {
        widths[i] = const pw.FixedColumnWidth(20);
      } else if (col.contains('date')) {
        widths[i] = const pw.FixedColumnWidth(35);
      } else if (col.contains('mobile') || col.contains('phone')) {
        widths[i] = const pw.FixedColumnWidth(40);
      } else if (col.contains('name')) {
        widths[i] = const pw.FixedColumnWidth(45);
      } else if (col.contains('id') || col.contains('number')) {
        widths[i] = const pw.FixedColumnWidth(40);
      } else {
        widths[i] = const pw.FixedColumnWidth(40);
      }
    }
    
    return widths;
  }

String _formatPdfCellValue(String column, dynamic value) {
  if (value == null) return '-';
  
  final lowerColumn = column.toLowerCase();
  
  if (lowerColumn.contains('date') && value is String) {
    try {
      final date = DateTime.parse(value);
      return DateFormat('dd/MM').format(date); // Shorter date format for mobile
    } catch (e) {
      return value.toString();
    }
  }
  
  if (lowerColumn.contains('amount') || 
      lowerColumn.contains('price') || 
      lowerColumn.contains('total') ||
      lowerColumn.contains('value')) {
    try {
      if (value is num) return _formatAmountForPdf(value.toDouble());
      if (value is String) {
        final numValue = double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), ''));
        if (numValue != null) return _formatAmountForPdf(numValue);
      }
    } catch (e) {
      // Fall through
    }
    return value.toString();
  }
  
  // Truncate long text for mobile
  String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 2)}..';
  }
  
  // ============ FIXED: Replace symbols with clear text ============
  if (lowerColumn.contains('status')) {
    final status = value.toString().toLowerCase();
    
    // Check for different status indicators
    if (status.contains('paid') || 
        status.contains('completed') || 
        status == 'true' ||
        status.contains('✓') ||
        status.contains('✅') ||
        status == '1') {
      return 'Paid';  // Clear text instead of symbol
    } else if (status.contains('pending') || 
               status.contains('due') ||
               status.contains('⏳') ||
               status.contains('📄') ||
               status.contains('invoice')) {
      return 'Pending';  // Clear text instead of symbol
    } else if (status.contains('cancel') || status.contains('void')) {
      return 'Canceled';
    } else {
      // Capitalize first letter of status
      if (status.isNotEmpty) {
        return status[0].toUpperCase() + status.substring(1);
      }
      return truncate(value.toString(), 8);
    }
  }
  // ============ END FIX ============
  
  if (lowerColumn.contains('name')) {
    return truncate(value.toString(), 12);
  }
  
  if (lowerColumn.contains('mobile') || lowerColumn.contains('phone')) {
    return truncate(value.toString(), 10);
  }
  
  return truncate(value.toString(), 15);
}
  pw.Widget _buildPdfFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8), // Reduced from 10
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5), // Reduced width
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Note: Computer-generated report. No signature required.',
            style: pw.TextStyle(
              fontSize: 7, // Reduced from 10
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 3), // Reduced from 5
          pw.Text(
            'Generated by Inventory Management System',
            style: pw.TextStyle(
              fontSize: 7, // Reduced from 10
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 3), // Reduced from 5
          pw.Text(
            '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} | Page 1/1',
            style: pw.TextStyle(
              fontSize: 7, // Reduced from 10
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  // ============ FILE OPERATIONS ============

  Future<void> openFile(String filePath) async {
    if (!kIsWeb) {
      final result = await OpenFile.open(filePath);
      print('📂 Open file result: ${result.message}');
    } else {
      print('📂 On web, files are downloaded directly to browser');
    }
  }

  Future<String> _saveCsvToMobile(String csvContent, String reportType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsString(csvContent);
      
      // Open the file
      await openFile(filePath);
      
      return '✅ CSV saved to: $filePath';
    } catch (e) {
      print('❌ Error saving CSV: $e');
      return 'Failed to save CSV file: $e';
    }
  }

  // ============ WEB DOWNLOAD METHODS ============
  
  Future<bool> _downloadPdfWeb(Uint8List pdfBytes, String fileName) async {
    try {
      if (!kIsWeb) return false;
      
      // Create blob from PDF bytes
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create download link
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      // Add to DOM and click
      html.document.body?.append(anchor);
      anchor.click();
      
      // Clean up
      Future.delayed(Duration(milliseconds: 100), () {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      });
      
      print('✅ PDF download initiated: $fileName');
      return true;
    } catch (e) {
      print('❌ PDF download failed: $e');
      return false;
    }
  }

  Future<bool> _realWebDownload(String content, String fileName, String mimeType) async {
    try {
      if (!kIsWeb) return false;
      
      // Method 1: Try using universal_html package
      final success = await _downloadWithUniversalHtml(content, fileName, mimeType);
      if (success) return true;
      
      // Method 2: Try using data URI
      return await _downloadWithDataUri(content, fileName);
    } catch (e) {
      print('❌ Real web download error: $e');
      return false;
    }
  }

  Future<bool> _downloadWithUniversalHtml(String content, String fileName, String mimeType) async {
    try {
      // Use universal_html package
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create download link
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      // Add to DOM and click
      html.document.body?.append(anchor);
      anchor.click();
      
      // Clean up
      Future.delayed(Duration(milliseconds: 100), () {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      });
      
      print('✅ Download initiated via universal_html: $fileName');
      return true;
    } catch (e) {
      print('❌ Universal HTML download failed: $e');
      return false;
    }
  }

  Future<bool> _downloadWithDataUri(String content, String fileName) async {
    try {
      // Create data URI
      final dataUri = 'data:text/plain;charset=utf-8,${Uri.encodeComponent(content)}';
      
      // Create download link
      final downloadLink = '''
        <a href="$dataUri" download="$fileName" id="downloadLink" style="display:none;">
          Download $fileName
        </a>
        <script>
          document.getElementById('downloadLink').click();
        </script>
      ''';
      
      // Inject HTML to trigger download
      _injectHtml(downloadLink);
      
      print('✅ Download attempted via data URI: $fileName');
      return true;
    } catch (e) {
      print('❌ Data URI download failed: $e');
      return false;
    }
  }

  void _injectHtml(String htmlString) {
    if (kIsWeb) {
      // Create a div element with the HTML
      final div = html.DivElement()
        ..style.display = 'none'
        ..innerHtml = htmlString;
      
      // Add to body
      html.document.body?.append(div);
      
      // Remove after a short delay
      Future.delayed(Duration(milliseconds: 100), () {
        div.remove();
      });
    }
  }

  // ============ CSV CONTENT CREATION ============
  
  String _createCsvContent({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
  }) {
    // Process real data
    final dataRows = _parseDataToRows(data, reportType);
    
    // Create CSV content
    String csv = '"${reportType.toUpperCase()} REPORT"\n\n';
    
    // Metadata
    csv += '"METADATA"\n';
    csv += '"User","$userMobile"\n';
    csv += '"Start Date","${formatDate(startDate)}"\n';
    csv += '"End Date","${formatDate(endDate)}"\n';
    csv += '"Generated","${formatDate(DateTime.now())}"\n';
    csv += '"Total Records","${dataRows.length}"\n\n';
    
    // Data headers - use actual data columns
    if (dataRows.isNotEmpty) {
      final headers = dataRows.first.keys.toList();
      csv += '"REPORT DATA"\n';
      csv += headers.map((h) => '"${_formatColumnName(h)}"').join(',') + '\n';
      
      // Add data rows
      for (var row in dataRows) {
        final rowData = headers.map((h) => '"${_formatCsvCellValue(h, row[h])}"').join(',');
        csv += rowData + '\n';
      }
    } else {
      // No data
      csv += '"REPORT DATA"\n';
      csv += '"No data available for the selected period"\n';
    }
    
    csv += '\n"Generated by Inventory Management System"';
    
    return csv;
  }

  // ============ HELPER METHODS ============
  
  List<Map<String, dynamic>> _parseDataToRows(dynamic data, String reportType) {
    final List<Map<String, dynamic>> rows = [];
    
    try {
      if (data == null) return rows;
      
      if (data is List) {
        for (var item in data) {
          if (item is Map) {
            rows.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (data is Map) {
        rows.add(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      print('❌ Error parsing data: $e');
    }
    
    return rows;
  }

  Map<String, dynamic> _calculateSummary(List<Map<String, dynamic>> rows, String reportType) {
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    
    for (var row in rows) {
      try {
        final amount = _extractAmount(row);
        totalAmount += amount;
        
        final status = _extractStatus(row);
        if (status.toLowerCase().contains('paid') || status.toLowerCase().contains('completed')) {
          paidAmount += amount;
          paidCount++;
        } else {
          pendingAmount += amount;
          pendingCount++;
        }
      } catch (e) {
        continue;
      }
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

  double _extractAmount(Map<String, dynamic> row) {
    final amountFields = ['amount', 'total', 'value', 'price', 'grandTotal', 'netAmount', 'totalAmount'];
    
    for (var field in amountFields) {
      if (row.containsKey(field) && row[field] != null) {
        try {
          final value = row[field];
          if (value is num) return value.toDouble();
          if (value is String) {
            final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
            return double.tryParse(cleanValue) ?? 0.0;
          }
        } catch (e) {
          continue;
        }
      }
    }
    return 0.0;
  }

  String _extractStatus(Map<String, dynamic> row) {
    final statusFields = ['status', 'paymentStatus', 'state', 'paymentState'];
    
    for (var field in statusFields) {
      if (row.containsKey(field) && row[field] != null) {
        final value = row[field].toString().toLowerCase();
        return value;
      }
    }
    return 'pending';
  }

  String _formatColumnName(String columnName) {
    return columnName
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '')
        .join(' ');
  }

String _formatCsvCellValue(String column, dynamic value) {
  if (value == null) return '';
  
  final lowerColumn = column.toLowerCase();
  
  if (lowerColumn.contains('date') && value is String) {
    try {
      final date = DateTime.parse(value);
      return formatDate(date);
    } catch (e) {
      return value.toString();
    }
  }
  
  if (lowerColumn.contains('amount') || 
      lowerColumn.contains('price') || 
      lowerColumn.contains('total') ||
      lowerColumn.contains('value')) {
    try {
      if (value is num) return _currencyFormat.format(value);
      if (value is String) {
        final numValue = double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), ''));
        if (numValue != null) return _currencyFormat.format(numValue);
      }
    } catch (e) {
      // Fall through
    }
  }
  
  // ============ ADDED: Status formatting for CSV ============
  if (lowerColumn.contains('status')) {
    final status = value.toString().toLowerCase();
    
    if (status.contains('paid') || 
        status.contains('completed') || 
        status == 'true' ||
        status.contains('✓') ||
        status.contains('✅') ||
        status == '1') {
      return 'Paid';
    } else if (status.contains('pending') || 
               status.contains('due') ||
               status.contains('⏳') ||
               status.contains('📄') ||
               status.contains('invoice')) {
      return 'Pending';
    } else if (status.contains('cancel') || status.contains('void')) {
      return 'Canceled';
    }
  }
  // ============ END ADDITION ============
  
  return value.toString();
}

  // Format date helper
  String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
}