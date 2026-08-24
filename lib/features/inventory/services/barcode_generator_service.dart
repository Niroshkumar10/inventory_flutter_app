import 'dart:math';
import 'inventory_repo_service.dart';

/// Generates internal barcode values for products that don't already
/// carry a manufacturer barcode.
class BarcodeGeneratorService {
  /// Generates a unique, EAN-13-shaped internal barcode and verifies
  /// uniqueness against Firestore before returning it. Uses the GS1
  /// reserved in-store prefix range "20"-"29" so generated codes are
  /// visually distinguishable from real manufacturer barcodes.
  static Future<String> generateUnique(
    InventoryService service, {
    int maxAttempts = 5,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final candidate = _generateCandidate();
      final exists = await service.barcodeExists(candidate);
      if (!exists) return candidate;
    }
    throw Exception('Could not generate a unique barcode. Please try again.');
  }

  static String _generateCandidate() {
    final rnd = Random();
    final prefix = '2${rnd.nextInt(10)}'; // "20".."29"
    final body = List.generate(10, (_) => rnd.nextInt(10)).join();
    final digits12 = '$prefix$body';
    final checkDigit = _ean13CheckDigit(digits12);
    return '$digits12$checkDigit';
  }

  static int _ean13CheckDigit(String digits12) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final d = int.parse(digits12[i]);
      sum += (i % 2 == 0) ? d : d * 3;
    }
    return (10 - (sum % 10)) % 10;
  }
}
