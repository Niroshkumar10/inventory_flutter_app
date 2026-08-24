import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// The business-identity fields shown on every single-document PDF
/// (invoice/receipt/voucher letterhead) — read from the user's Firestore
/// profile document (`users/{mobile}`).
///
/// Field-name note: the Firestore document stores the GST number under the
/// key `gst` (see `ProfileScreen._updateBusinessProfile`), not `gstNumber` —
/// only this Dart-side class/parameter is named `gstNumber`. Always map it
/// from `data['gst']`.
class BusinessProfile {
  final String userName;
  final String businessName;
  final String? location;
  final String? address;
  final String? gstNumber;
  final String mobile;

  const BusinessProfile({
    required this.userName,
    required this.businessName,
    this.location,
    this.address,
    this.gstNumber,
    required this.mobile,
  });

  /// Fetches the business profile for [userMobile] from
  /// `users/{userMobile}` in Firestore. Missing fields fall back to sane
  /// defaults ("Kadai" — this app's own name — for a blank business name)
  /// so a document with an incomplete "Business Information" card doesn't
  /// crash PDF generation.
  static Future<BusinessProfile> fetch(String userMobile) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userMobile)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    return BusinessProfile(
      userName: data['name']?.toString() ?? '',
      businessName: data['businessName']?.toString() ?? 'Kadai',
      location: data['location']?.toString(),
      address: data['address']?.toString(),
      gstNumber: data['gst']?.toString(),
      mobile: userMobile,
    );
  }
}

/// Shared PDF building blocks for the single-document (invoice/receipt/
/// voucher) PDF family — distinct from `PdfExportService`, which owns the
/// separate bulk multi-record roll80 report family. Both families read the
/// same fonts/business-profile shape but render very differently, so they
/// intentionally don't share a base class — just these free helpers.
class PdfCommon {
  static Future<pw.ThemeData> loadTheme() async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
  }

  /// A row of evenly-spaced dashes spanning the full available width — the
  /// "- - - -" divider between sections. Uses `LayoutBuilder` to measure the
  /// actual content width and generate exactly enough dash segments to fill
  /// it edge-to-edge, rather than a fixed character count (a fixed count of
  /// `'-'` characters doesn't reliably span the real width across different
  /// contexts — it was cutting off partway across the row before).
  static pw.Widget dashedLine({PdfColor color = PdfColors.grey500}) {
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
              (_) => pw.Container(width: dashWidth, height: 0.75, color: color),
            ),
          );
        },
      ),
    );
  }

  /// A single label/value line, label on the left and value on the right —
  /// the standard receipt "field: value" row. Mirrors
  /// `PdfExportService._kv()` pixel-for-pixel.
  static pw.Widget kv(String label, String value, {bool bold = false}) {
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

  /// The app's own brand name — shown as the business name on every
  /// letterhead regardless of whatever's stored in a user's profile
  /// document (some accounts still have the old literal "My Business"
  /// placeholder saved from before this field had a real default).
  static const String brandName = 'Kadai';

  /// The business-identity block shown at the top of every single-document
  /// PDF — business name (bold, larger), then centered smaller lines for
  /// address, location, phone and GSTIN, each only rendered when the
  /// underlying value is non-null/non-empty.
  static pw.Widget letterhead(BusinessProfile profile) {
    final lines = <String>[];
    if (profile.address != null && profile.address!.isNotEmpty) {
      lines.add(profile.address!);
    }
    if (profile.location != null &&
        profile.location!.isNotEmpty &&
        profile.location != profile.address) {
      lines.add(profile.location!);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          brandName,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        for (final line in lines) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            line,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ],
        if (profile.mobile.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            'Phone : ${profile.mobile}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ],
        if (profile.gstNumber != null && profile.gstNumber!.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            'GSTIN : ${profile.gstNumber}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ],
      ],
    );
  }

  /// Fixed 5-column item-table header — `#` / `Item` / `Qty` / `Price/unit`
  /// / `Amount` — shared by every single- or bulk-document PDF that lists
  /// line items (the Bill invoice, and each sale/purchase record inside a
  /// Report PDF), so they all render an identical table shape.
  static pw.Widget itemTableHeader() {
    return itemTableRow(num: '#', item: 'Item', qty: 'Qty', price: 'Price/unit', amount: 'Amount', bold: true);
  }

  /// One column-aligned row in the shared item table. Column positions stay
  /// fixed regardless of item-name length or item count — long names wrap
  /// within the Item column instead of shifting the numeric columns out of
  /// alignment.
  static pw.Widget itemTableRow({
    required String num,
    required String item,
    required String qty,
    required String price,
    required String amount,
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: 8,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 14, child: pw.Text(num, style: style)),
        pw.Expanded(child: pw.Text(item, style: style)),
        pw.SizedBox(
          width: 34,
          child: pw.Text(qty, textAlign: pw.TextAlign.center, style: style),
        ),
        pw.SizedBox(
          width: 40,
          child: pw.Text(price, textAlign: pw.TextAlign.right, style: style),
        ),
        pw.SizedBox(
          width: 44,
          child: pw.Text(amount, textAlign: pw.TextAlign.right, style: style),
        ),
      ],
    );
  }

  static pw.Widget footer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          'Computer-generated document — no signature required',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }

  /// Saves [pdf] and either opens it (mobile/desktop) or triggers a browser
  /// download (web). Returns the saved file path on mobile/desktop, or null
  /// on web (nothing to point a share-sheet at there).
  static Future<String?> saveAndOpen(pw.Document pdf, String fileName) async {
    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) => pdf.save(), name: fileName);
      return null;
    }
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final bytes = await pdf.save();
    await File(filePath).writeAsBytes(bytes);
    final result = await OpenFile.open(filePath);
    debugPrint('Open file result: ${result.message}');
    return filePath;
  }

  /// Saves [pdf] to disk without opening it — used when the caller wants to
  /// hand the file path straight to a share sheet instead. There's no real
  /// filesystem to share a file from on web, so this falls back to the same
  /// browser print/save dialog as [saveAndOpen] and returns null — callers
  /// must treat a null result as "already handled, nothing left to share".
  static Future<String?> saveToFile(pw.Document pdf, String fileName) async {
    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) => pdf.save(), name: fileName);
      return null;
    }
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final bytes = await pdf.save();
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }
}
