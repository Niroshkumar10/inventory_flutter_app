import 'package:flutter/material.dart';
import '../../features/ai/services/sarvam_service.dart';
import '../../features/inventory/services/inventory_repo_service.dart';
import '../../features/feedback/services/feedback_service.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

class AIProvider extends ChangeNotifier {
  SarvamService? _sarvamService;
  bool _isAvailable = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  SarvamService? get sarvamService => _sarvamService;
  bool get isAvailable => _isAvailable;
  String get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  Future<void> initialize(
    InventoryService inventoryService, {
    FeedbackService? feedbackService,
    String? userMobile,
  }) async {
    try {
      // SarvamService does local rule-based matching + Firebase queries.
      // No external API key is required — always initialize it.
      _sarvamService = SarvamService(
        apiKey: '',
        baseUrl: '',
        inventoryRepo: inventoryService,
      );

      if (userMobile != null && userMobile.isNotEmpty) {
        _sarvamService!.setUserMobile(userMobile);
      }

      if (feedbackService != null) {
        _sarvamService!.setFeedbackService(feedbackService);
      }

      _isAvailable = true;
      _errorMessage = '';
      appLogger.i('✅ AI Provider initialized for user=$userMobile');
    } catch (e) {
      _isAvailable = false;
      _errorMessage = 'Failed to initialize AI: $e';
      appLogger.e('❌ AI Provider error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void updateUserMobile(String userMobile) {
    if (_sarvamService != null) {
      _sarvamService!.setUserMobile(userMobile);
      notifyListeners();
    }
  }

  void disposeService() {
    _sarvamService = null;
    _isAvailable = false;
    _isInitialized = false;
    notifyListeners();
  }
}
