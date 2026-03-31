// lib/core/providers/ai_provider.dart
import 'package:flutter/material.dart';
import '../../features/ai/services/sarvam_service.dart';
import '../../features/inventory/services/inventory_repo_service.dart';

class AIProvider extends ChangeNotifier {
  SarvamService? _sarvamService;
  bool _isAvailable = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  SarvamService? get sarvamService => _sarvamService;
  bool get isAvailable => _isAvailable;
  String get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  Future<void> initialize(InventoryService inventoryService) async {
    try {
      // In production, get these from environment variables
      const String apiKey = String.fromEnvironment(
        'SARVAM_API_KEY',
        defaultValue: 'sk_rjhfum72_j9h9zkNiZ9828FZJ2Y6dvQic', // Replace with actual key
      );
      
      const String baseUrl = String.fromEnvironment(
        'SARVAM_BASE_URL',
        defaultValue: 'https://api.sarvam.ai/v1',
      );

      if (apiKey != 'demo_key') {
        _sarvamService = SarvamService(
          apiKey: apiKey,
          baseUrl: baseUrl,
          inventoryRepo: inventoryService,
        );
        _isAvailable = true;
        _errorMessage = '';
        print('✅ AI Provider initialized');
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

  void disposeService() {
    _sarvamService = null;
    _isAvailable = false;
    _isInitialized = false;
    notifyListeners();
  }
}