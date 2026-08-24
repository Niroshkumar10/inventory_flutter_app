import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Shared save/open helper for single-document "Excel" (CSV, opens fine in
/// Excel/Sheets — same lightweight approach `CsvExportService` already uses
/// for bulk reports) exports of one record: a Bill invoice or a Ledger
/// entry receipt/voucher. Mirrors `PdfCommon.saveAndOpen`'s shape so the two
/// single-document export families (PDF via `PdfCommon`, Excel via this)
/// behave the same way from the caller's point of view.
class CsvCommon {
  static Future<String> saveAndOpen(String csvContent, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    await File(filePath).writeAsString(csvContent);
    await OpenFile.open(filePath);
    return filePath;
  }

  /// Wraps a value for a CSV cell — quotes it and escapes embedded quotes.
  static String cell(Object? value) {
    final s = (value ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  static String row(List<Object?> values) => values.map(cell).join(',');
}
