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
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // Helper method to format dates
  String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  // Export to PDF with REAL data
  Future<String> exportToPdf({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data, // This should contain your real data
    required String title,
  }) async {
    try {
      print('📄 Starting PDF export for $reportType...');
      
      if (kIsWeb) {
        // ============ WEB VERSION ============
        final content = await _createPdfHtmlContent(
          reportType: reportType,
          userMobile: userMobile,
          startDate: startDate,
          endDate: endDate,
          title: title,
          data: data, // Pass real data here
        );
        
        final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.html';
        final success = await _realWebDownload(content, fileName, 'text/html');
        
        if (success) {
          return '✅ PDF file downloaded! Check your downloads folder.';
        } else {
          return '❌ Download failed. Check browser console for details.';
        }
      } else {
        // ============ MOBILE VERSION ============
        return await _generateMobilePdf(
          reportType: reportType,
          userMobile: userMobile,
          startDate: startDate,
          endDate: endDate,
          title: title,
          data: data,
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
        return await _saveCsvToFile(
          csvContent: csvContent,
          reportType: reportType,
        );
      }
    } catch (e) {
      print('❌ Excel Export Error: $e');
      return 'Error exporting Excel: $e';
    }
  }

  // Open file - for mobile
  Future<void> openFile(String filePath) async {
    if (!kIsWeb) {
      final result = await OpenFile.open(filePath);
      print('📂 Open file result: ${result.message}');
    } else {
      print('📂 On web, files are downloaded directly to browser');
    }
  }

  // ============ MOBILE PDF GENERATION ============
  
  Future<String> _generateMobilePdf({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required String title,
    required dynamic data,
  }) async {
    try {
      // Parse data
      final dataRows = _parseDataToRows(data, reportType);
      final summary = _calculateSummary(dataRows, reportType);
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Add report header
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Header
              _buildPdfHeader(title, userMobile, startDate, endDate, reportType, dataRows.length),
              
              // Summary section
              _buildPdfSummary(summary, reportType),
              
              // Data table
              _buildPdfDataTable(dataRows, reportType, context),
              
              // Footer
              _buildPdfFooter(),
            ];
          },
        ),
      );
      
      // Save PDF to file
      final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = await _savePdfToFile(pdf, fileName);
      
      // Open the file
      await openFile(filePath);
      
      return '✅ PDF saved to: $filePath';
    } catch (e) {
      print('❌ Mobile PDF generation error: $e');
      return 'Failed to generate PDF: $e';
    }
  }

  // Build PDF header
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
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Inventory Management System',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          'Generated on: ${formatDate(DateTime.now())} at ${DateFormat('HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('User ID:', userMobile),
                  _buildInfoRow('Report Period:', '${formatDate(startDate)} to ${formatDate(endDate)}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Report Type:', reportType.toUpperCase()),
                  _buildInfoRow('Total Records:', recordCount.toString()),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  // Build PDF summary
  pw.Widget _buildPdfSummary(Map<String, dynamic> summary, String reportType) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.blue200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blue100),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Total ${reportType == 'sales' ? 'Sales' : 'Purchases'}:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('${summary['totalCount']}'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Total Amount:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(_currencyFormat.format(summary['totalAmount']),
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Paid:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('${summary['paidCount']}'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Paid Amount:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(_currencyFormat.format(summary['paidAmount']),
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Pending:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('${summary['pendingCount']}'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Pending Amount:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(_currencyFormat.format(summary['pendingAmount']),
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

  // Build PDF data table
  pw.Widget _buildPdfDataTable(List<Map<String, dynamic>> rows, String reportType, pw.Context context) {
    if (rows.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No data available',
          style: pw.TextStyle(
            fontSize: 14,
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
        pw.SizedBox(height: 20),
        pw.Text(
          '${reportType == 'sales' ? 'Sales' : 'Purchase'} Details',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          data: tableData,
          border: pw.TableBorder.all(color: PdfColors.grey300),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.blue700,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
          columnWidths: {
            for (var i = 0; i < columns.length; i++)
              i: const pw.FlexColumnWidth(1.0),
          },
        ),
      ],
    );
  }

  String _formatPdfCellValue(String column, dynamic value) {
    if (value == null) return '-';
    
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
    
    return value.toString();
  }

  // Build PDF footer
  pw.Widget _buildPdfFooter() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 30),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Note: This is a computer-generated report. No signature required.',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Generated by Inventory Management System • ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Page 1 of 1',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // Save PDF to file on mobile
  Future<String> _savePdfToFile(pw.Document pdf, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    
    // Save the PDF
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
    
    print('📄 PDF saved to: $filePath');
    return filePath;
  }

  // ============ MOBILE CSV SAVING ============
  
  Future<String> _saveCsvToFile({
    required String csvContent,
    required String reportType,
  }) async {
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
  
  Future<bool> _realWebDownload(String content, String fileName, String mimeType) async {
    try {
      if (!kIsWeb) return false;
      
      // Method 1: Direct download with data URI
      final success = await _downloadWithDataUri(content, fileName, mimeType);
      if (success) return true;
      
      // Method 2: Fallback to simpler method
      return _downloadWithSimpleDataUri(content, fileName);
    } catch (e) {
      print('❌ Real web download error: $e');
      return false;
    }
  }

  Future<bool> _downloadWithDataUri(String content, String fileName, String mimeType) async {
    try {
      // Encode content for data URI
      final encodedContent = Uri.encodeComponent(content);
      final dataUri = 'data:$mimeType;charset=utf-8,$encodedContent';
      
      // Create anchor element
      final anchor = html.AnchorElement(href: dataUri)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      // Add to DOM
      html.document.body?.append(anchor);
      
      // Trigger download
      anchor.click();
      
      // Remove anchor after download is triggered
      Future.delayed(const Duration(milliseconds: 100), () {
        anchor.remove();
      });
      
      print('✅ Download initiated: $fileName');
      return true;
    } catch (e) {
      print('❌ Data URI download failed: $e');
      return false;
    }
  }

  bool _downloadWithSimpleDataUri(String content, String fileName) {
    try {
      // Create data URI
      final encodedContent = Uri.encodeComponent(content);
      final dataUri = 'data:text/html;charset=utf-8,$encodedContent';
      
      // Create download link HTML
      final downloadLink = '''
        <a href="$dataUri" download="$fileName" id="downloadLink" style="display:none;">
          Download $fileName
        </a>
      ''';
      
      // Create a temporary element
      final div = html.DivElement()..innerHtml = downloadLink;
      html.document.body?.append(div);
      
      // Get the link and click it
      final link = html.document.getElementById('downloadLink') as html.AnchorElement?;
      link?.click();
      
      // Clean up
      Future.delayed(const Duration(milliseconds: 100), () {
        div.remove();
      });
      
      print('✅ Download initiated via simple method: $fileName');
      return true;
    } catch (e) {
      print('❌ Simple download failed: $e');
      return false;
    }
  }

  // ============ HTML CONTENT CREATION (For Web) ============
  
  Future<String> _createPdfHtmlContent({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required String title,
    required dynamic data,
  }) async {
    try {
      // Parse real data based on report type
      final dataRows = _parseDataToRows(data, reportType);
      final summary = _calculateSummary(dataRows, reportType);
      
      return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$title</title>
    <style>
        @page {
            margin: 20mm;
            size: A4 portrait;
        }
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 0;
            color: #333;
            line-height: 1.4;
        }
        .header {
            text-align: center;
            margin-bottom: 25px;
            border-bottom: 3px solid #2c3e50;
            padding-bottom: 15px;
        }
        .header h1 {
            color: #2c3e50;
            margin: 0 0 10px 0;
            font-size: 24px;
        }
        .company-info {
            font-size: 12px;
            color: #666;
            margin-bottom: 5px;
        }
        .info-box {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 5px;
            padding: 15px;
            margin: 20px 0;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 10px;
        }
        .info-item {
            margin: 5px 0;
        }
        .info-label {
            font-weight: bold;
            color: #495057;
        }
        .summary-box {
            background: #e7f3ff;
            border: 1px solid #b6d4fe;
            border-radius: 5px;
            padding: 15px;
            margin: 20px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            font-size: 12px;
            page-break-inside: avoid;
        }
        th {
            background-color: #3498db;
            color: white;
            padding: 10px 8px;
            text-align: left;
            border: 1px solid #2980b9;
            font-weight: bold;
        }
        td {
            padding: 8px;
            border: 1px solid #ddd;
            vertical-align: top;
        }
        tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        .amount {
            text-align: right;
            font-family: 'Courier New', monospace;
        }
        .total-row {
            background-color: #e8f5e8 !important;
            font-weight: bold;
            border-top: 2px solid #27ae60;
        }
        .status-paid {
            color: #27ae60;
            font-weight: bold;
        }
        .status-pending {
            color: #e74c3c;
            font-weight: bold;
        }
        .footer {
            margin-top: 30px;
            padding-top: 15px;
            border-top: 1px solid #ddd;
            text-align: center;
            color: #666;
            font-size: 10px;
        }
        .page-break {
            page-break-before: always;
        }
        .no-data {
            text-align: center;
            padding: 40px;
            color: #7f8c8d;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>$title</h1>
        <div class="company-info">Inventory Management System</div>
        <div class="company-info">Generated on: ${formatDate(DateTime.now())} at ${DateFormat('HH:mm').format(DateTime.now())}</div>
    </div>
    
    <div class="info-box">
        <div class="info-item">
            <span class="info-label">User ID:</span> $userMobile
        </div>
        <div class="info-item">
            <span class="info-label">Report Period:</span> ${formatDate(startDate)} to ${formatDate(endDate)}
        </div>
        <div class="info-item">
            <span class="info-label">Report Type:</span> ${reportType.toUpperCase()}
        </div>
        <div class="info-item">
            <span class="info-label">Total Records:</span> ${dataRows.length}
        </div>
    </div>
    
    <div class="summary-box">
        <h3 style="margin-top: 0;">Summary</h3>
        ${_generateSummaryHtml(summary, reportType)}
    </div>
    
    ${_generateDataTableHtml(dataRows, reportType)}
    
    <div class="footer">
        <p><strong>Note:</strong> This is a computer-generated report. No signature required.</p>
        <p>Generated by Inventory Management System • ${DateFormat('dd MMMM yyyy').format(DateTime.now())}</p>
        <p>Page 1 of 1</p>
    </div>
    
    <script type="text/javascript">
        // Auto trigger print dialog for PDF save
        window.onload = function() {
            setTimeout(function() {
                window.print();
            }, 500);
        };
    </script>
</body>
</html>
      ''';
    } catch (e) {
      print('❌ Error creating PDF content: $e');
      return _createSimplePdfContent(
        reportType: reportType,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        title: title,
        data: data,
      );
    }
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
    final amountFields = ['amount', 'total', 'value', 'price', 'grandTotal', 'netAmount'];
    
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

  String _generateSummaryHtml(Map<String, dynamic> summary, String reportType) {
    return '''
    <table style="width: 100%; margin: 0;">
      <tr>
        <td><strong>Total ${reportType == 'sales' ? 'Sales' : 'Purchases'}:</strong></td>
        <td>${summary['totalCount']}</td>
        <td><strong>Total Amount:</strong></td>
        <td class="amount">${_currencyFormat.format(summary['totalAmount'])}</td>
      </tr>
      <tr>
        <td><strong>Paid:</strong></td>
        <td>${summary['paidCount']}</td>
        <td><strong>Paid Amount:</strong></td>
        <td class="amount">${_currencyFormat.format(summary['paidAmount'])}</td>
      </tr>
      <tr>
        <td><strong>Pending:</strong></td>
        <td>${summary['pendingCount']}</td>
        <td><strong>Pending Amount:</strong></td>
        <td class="amount">${_currencyFormat.format(summary['pendingAmount'])}</td>
      </tr>
    </table>
    ''';
  }

  String _generateDataTableHtml(List<Map<String, dynamic>> rows, String reportType) {
    if (rows.isEmpty) {
      return '''
      <div class="no-data">
        <h3>No Data Available</h3>
        <p>No ${reportType} records found for the selected period.</p>
      </div>
      ''';
    }
    
    final firstRow = rows.first;
    final columns = firstRow.keys.toList();
    
    String tableHtml = '''
    <h3>${reportType == 'sales' ? 'Sales' : 'Purchase'} Details</h3>
    <table>
      <thead>
        <tr>
    ''';
    
    for (var column in columns) {
      tableHtml += '<th>${_formatColumnName(column)}</th>';
    }
    tableHtml += '</tr></thead><tbody>';
    
    for (var row in rows) {
      tableHtml += '<tr>';
      for (var column in columns) {
        final value = row[column];
        final cellClass = _getCellClass(column, value);
        tableHtml += '<td class="$cellClass">${_formatCellValue(column, value)}</td>';
      }
      tableHtml += '</tr>';
    }
    
    tableHtml += '</tbody></table>';
    return tableHtml;
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

  String _formatCellValue(String column, dynamic value) {
    if (value == null) return '-';
    
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
    
    if (lowerColumn.contains('status')) {
      final status = value.toString().toLowerCase();
      if (status.contains('paid') || status.contains('completed')) {
        return '<span class="status-paid">${value.toString().toUpperCase()}</span>';
      } else {
        return '<span class="status-pending">${value.toString().toUpperCase()}</span>';
      }
    }
    
    return value.toString();
  }

  String _getCellClass(String column, dynamic value) {
    final lowerColumn = column.toLowerCase();
    
    if (lowerColumn.contains('amount') || 
        lowerColumn.contains('price') || 
        lowerColumn.contains('total') ||
        lowerColumn.contains('value')) {
      return 'amount';
    }
    
    return '';
  }

  String _createSimplePdfContent({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required String title,
    required dynamic data,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$title</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        .header { text-align: center; margin-bottom: 20px; }
        .info { margin: 15px 0; padding: 10px; background: #f0f0f0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$title</h1>
    </div>
    <div class="info">
        <div><strong>User:</strong> $userMobile</div>
        <div><strong>Period:</strong> ${formatDate(startDate)} - ${formatDate(endDate)}</div>
        <div><strong>Generated:</strong> ${formatDate(DateTime.now())}</div>
    </div>
    <h3>Report Data</h3>
    <p>Total Records: ${data is List ? data.length : 1}</p>
    <p><em>Note: Data formatting may be simplified. View CSV export for full details.</em></p>
</body>
</html>
    ''';
  }

  String _createCsvContent({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
  }) {
    // Create CSV content
    String csv = '"${reportType.toUpperCase()} REPORT"\n\n';
    
    // Metadata
    csv += '"METADATA"\n';
    csv += '"User","$userMobile"\n';
    csv += '"Start Date","${formatDate(startDate)}"\n';
    csv += '"End Date","${formatDate(endDate)}"\n';
    csv += '"Generated","${formatDate(DateTime.now())}"\n';
    csv += '"Total Records","${_countRecords(data)}"\n\n';
    
    // Data headers
    csv += '"REPORT DATA"\n';
    
    // Add actual data if available
    if (data is List && data.isNotEmpty) {
      // Add headers from first item if it's a Map
      if (data.first is Map) {
        final firstItem = data.first as Map;
        final headers = firstItem.keys.toList();
        csv += headers.map((h) => '"$h"').join(',') + '\n';
        
        // Add data rows
        for (var item in data) {
          final map = item as Map;
          final row = headers.map((h) => '"${map[h]?.toString() ?? ""}"').join(',');
          csv += row + '\n';
        }
      } else {
        // Simple list
        csv += '"Data"\n';
        for (var item in data) {
          csv += '"${item.toString()}"\n';
        }
      }
    } else {
      // Sample data (fallback)
      if (reportType == 'sales') {
        csv += '"Invoice No","Customer","Date","Amount","Status"\n';
        csv += '"INV-001","John Doe","${formatDate(startDate)}","1000.00","Paid"\n';
        csv += '"INV-002","Jane Smith","${formatDate(endDate)}","2000.00","Pending"\n';
        csv += '"","","","3000.00",""\n';
      }
    }
    
    csv += '\n"Generated by Inventory Management System"';
    
    return csv;
  }

  int _countRecords(dynamic data) {
    if (data == null) return 0;
    if (data is List) return data.length;
    return 1;
  }
}