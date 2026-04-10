// // lib/core/providers/ai_provider.dart
// import 'package:flutter/material.dart';
// import '../../features/ai/services/sarvam_service.dart';
// import '../../features/inventory/services/inventory_repo_service.dart';

// class AIProvider extends ChangeNotifier {
//   SarvamService? _sarvamService;
//   bool _isAvailable = false;
//   String _errorMessage = '';
//   bool _isInitialized = false;

//   SarvamService? get sarvamService => _sarvamService;
//   bool get isAvailable => _isAvailable;
//   String get errorMessage => _errorMessage;
//   bool get isInitialized => _isInitialized;

//   Future<void> initialize(InventoryService inventoryService) async {
//     try {
//       // In production, get these from environment variables
//       const String apiKey = String.fromEnvironment(
//         'SARVAM_API_KEY',
//         defaultValue: 'sk_rjhfum72_j9h9zkNiZ9828FZJ2Y6dvQic', // Replace with actual key
//       );
      
//       const String baseUrl = String.fromEnvironment(
//         'SARVAM_BASE_URL',
//         defaultValue: 'https://api.sarvam.ai/v1',
//       );

//       if (apiKey != 'demo_key') {
//         _sarvamService = SarvamService(
//           apiKey: apiKey,
//           baseUrl: baseUrl,
//           inventoryRepo: inventoryService,
//         );
//         _isAvailable = true;
//         _errorMessage = '';
//         print('✅ AI Provider initialized');
//       } else {
//         _isAvailable = false;
//         _errorMessage = 'Sarvam API key not configured';
//         print('⚠️ AI Provider: API key not configured');
//       }
//     } catch (e) {
//       _isAvailable = false;
//       _errorMessage = 'Failed to initialize AI: $e';
//       print('❌ AI Provider error: $e');
//     } finally {
//       _isInitialized = true;
//       notifyListeners();
//     }
//   }

//   void disposeService() {
//     _sarvamService = null;
//     _isAvailable = false;
//     _isInitialized = false;
//     notifyListeners();
//   }
// }
// lib/core/providers/ai_provider.dart
import 'package:flutter/material.dart';
import '../../features/ai/services/sarvam_service.dart';
import '../../features/inventory/services/inventory_repo_service.dart';
import '../../features/feedback/services/feedback_service.dart';

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
      const String apiKey = String.fromEnvironment(
        'SARVAM_API_KEY',
        defaultValue: 'sk_rjhfum72_j9h9zkNiZ9828FZJ2Y6dvQic',
      );
      
      const String baseUrl = String.fromEnvironment(
        'SARVAM_BASE_URL',
        defaultValue: 'https://api.sarvam.ai/v1',
      );

      if (apiKey.isNotEmpty && apiKey != 'demo_key') {
        _sarvamService = SarvamService(
          apiKey: apiKey,
          baseUrl: baseUrl,
          inventoryRepo: inventoryService,
        );
        
        // ✅ CRITICAL: Set user mobile for parties access
        if (userMobile != null && userMobile.isNotEmpty) {
          _sarvamService!.setUserMobile(userMobile);
          print('✅ AI Provider: User mobile set to $userMobile');
        } else {
          print('⚠️ AI Provider: No user mobile provided');
        }
        
        // ✅ CRITICAL: Set feedback service
        if (feedbackService != null) {
          _sarvamService!.setFeedbackService(feedbackService);
          print('✅ AI Provider: Feedback service connected');
        } else {
          print('⚠️ AI Provider: No feedback service provided');
        }
        
        _isAvailable = true;
        _errorMessage = '';
        print('✅ AI Provider initialized with Customers, Suppliers, Expiry & Feedback');
      } else {
        _isAvailable = false;
        _errorMessage = 'Sarvam API key not configured';
        print('⚠️ AI Provider: API key not configured');
      }
    } catch (e) {
      _isAvailable = false;
      _errorMessage = 'Failed to initialize AI: $e';
      print('❌ AI Provider error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ✅ Add method to update user mobile after initialization (for login changes)
  void updateUserMobile(String userMobile) {
    if (_sarvamService != null) {
      _sarvamService!.setUserMobile(userMobile);
      print('✅ AI Provider: User mobile updated to $userMobile');
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