// lib/features/settings/services/settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save settings to Firebase
  Future<void> saveSettings(String userMobile, Map<String, dynamic> settings) async {
    try {
      await _firestore
          .collection('users')
          .doc(userMobile)
          .collection('settings')
          .doc('preferences')
          .set({
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also save to local SharedPreferences for offline access
      await _saveToLocal(settings);
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }

  // Load settings from Firebase
  Future<Map<String, dynamic>> loadSettings(String userMobile) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userMobile)
          .collection('settings')
          .doc('preferences')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Save to local for offline access
        await _saveToLocal(data);
        return data;
      } else {
        // Return default settings if no document exists
        return _getDefaultSettings();
      }
    } catch (e) {
      print('Error loading settings: $e');
      // Try to load from local storage if Firebase fails
      return await _loadFromLocal() ?? _getDefaultSettings();
    }
  }

  // Save to SharedPreferences
  Future<void> _saveToLocal(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_settings', jsonEncode(settings));
  }

  // Load from SharedPreferences
  Future<Map<String, dynamic>?> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsString = prefs.getString('user_settings');
    if (settingsString != null) {
      return jsonDecode(settingsString) as Map<String, dynamic>;
    }
    return null;
  }

  // Get default settings
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'notifications': true,
      'darkMode': false,
      'autoSync': true,
      'biometric': false,
      'language': 'English',
      'currency': '₹ (INR)',
      'dateFormat': 'DD/MM/YYYY',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Clear local cache
  Future<void> clearLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear app cache (you can add more items here)
      await prefs.remove('cached_data');
      // Add other cache clearing logic here
    } catch (e) {
      print('Error clearing cache: $e');
      rethrow;
    }
  }
}