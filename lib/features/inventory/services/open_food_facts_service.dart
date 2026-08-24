import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

enum OffLookupStatus { found, notFound, networkError }

class OffProduct {
  final String? name;
  final String? brand;
  final String? packSize;
  final String? category;

  const OffProduct({
    this.name,
    this.brand,
    this.packSize,
    this.category,
  });

  // Note: deliberately does not surface Open Food Facts' `image_front_url`.
  // Many OFF listings only have a photo of the barcode/label rather than the
  // actual product, so product images always come from the user's own
  // camera/gallery instead — see _applyOffProduct in add_edit_item_screen.dart.
  factory OffProduct.fromJson(Map<String, dynamic> json) {
    String? firstCategory(dynamic categories) {
      final text = categories?.toString();
      if (text == null || text.isEmpty) return null;
      return text.split(',').first.trim();
    }

    return OffProduct(
      name: json['product_name']?.toString(),
      brand: json['brands']?.toString(),
      packSize: json['quantity']?.toString(),
      category: firstCategory(json['categories']),
    );
  }
}

class OffLookupResult {
  final OffLookupStatus status;
  final OffProduct? product;
  final String? errorMessage;

  const OffLookupResult._(this.status, this.product, this.errorMessage);

  factory OffLookupResult.found(OffProduct product) =>
      OffLookupResult._(OffLookupStatus.found, product, null);
  factory OffLookupResult.notFound() =>
      const OffLookupResult._(OffLookupStatus.notFound, null, null);
  factory OffLookupResult.networkError(String message) =>
      OffLookupResult._(OffLookupStatus.networkError, null, message);
}

/// Looks up product info from Open Food Facts by barcode. This is a public,
/// read-only, unauthenticated API — no credentials needed.
class OpenFoodFactsService {
  static const _userAgent = 'InventoryApp - Flutter - Version 1.1.0';

  Future<OffLookupResult> lookup(String barcode) async {
    try {
      final uri = Uri.parse('https://world.openfoodfacts.org/api/v3/product/$barcode.json');
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        return OffLookupResult.notFound();
      }
      if (response.statusCode != 200) {
        return OffLookupResult.networkError('Unexpected response (${response.statusCode})');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'];
      final productData = data['product'];
      final found = (status == 1 || status == 'success' || status == 'found') &&
          productData is Map<String, dynamic>;

      if (!found) {
        return OffLookupResult.notFound();
      }

      return OffLookupResult.found(OffProduct.fromJson(productData));
    } on TimeoutException {
      return OffLookupResult.networkError('Request timed out');
    } on SocketException {
      return OffLookupResult.networkError('No internet connection');
    } catch (e) {
      return OffLookupResult.networkError('Could not reach the product database');
    }
  }
}
