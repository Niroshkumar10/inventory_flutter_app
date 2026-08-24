import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

/// Picks a product image and uploads it to Firebase Storage. Picking/upload
/// never throws — failures come back as a null value (image) or a
/// (null, message) pair (upload) so a cancellation or Storage problem never
/// blocks saving the rest of the item.
class ImageUploadService {
  final ImagePicker _picker = ImagePicker();

  /// Downscales to a consistent product-photo size on the way in, so every
  /// item image is a similar, reasonably small size regardless of what the
  /// user's camera/gallery photo originally was.
  Future<File?> pickImage({required bool fromCamera}) async {
    try {
      final xfile = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (xfile == null) return null;
      return File(xfile.path);
    } catch (e) {
      appLogger.w('⚠️ Image pick failed: $e');
      return null;
    }
  }

  /// Returns (downloadUrl, null) on success, or (null, a user-facing reason)
  /// on failure — distinguishing rules/permission problems from a missing
  /// bucket from a plain network error, so the caller can show something
  /// actionable instead of a generic "failed" message.
  Future<(String? url, String? error)> uploadItemImage({
    required File file,
    required String userMobile,
  }) async {
    try {
      final fileName = '${const Uuid().v4()}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('inventory_images')
          .child(userMobile)
          .child(fileName);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      return (url, null);
    } on FirebaseException catch (e) {
      appLogger.w('⚠️ Image upload failed [${e.code}]: ${e.message}');
      final message = switch (e.code) {
        'unauthorized' || 'permission-denied' =>
          'Storage permission denied — Firebase Storage rules need to allow this upload.',
        'object-not-found' || 'bucket-not-found' || 'unknown' =>
          'Storage isn\'t set up yet for this project — check Firebase Storage is enabled.',
        'canceled' => 'Upload was cancelled.',
        _ => 'Upload failed: ${e.message ?? e.code}',
      };
      return (null, message);
    } catch (e) {
      appLogger.w('⚠️ Image upload failed: $e');
      return (null, 'Could not upload image. Please try again.');
    }
  }
}
