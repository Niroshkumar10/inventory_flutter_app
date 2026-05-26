// lib/features/session/session_service_new.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

class SessionServiceNew {
  static const _mobileKey = 'logged_in_mobile';

  static Future<void> saveLogin(String mobile) async {
    appLogger.d('💾 Saving login for mobile: $mobile');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mobileKey, mobile);
    appLogger.i('✅ Mobile saved successfully');
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString(_mobileKey) ?? '';
    appLogger.d('🔍 Retrieved mobile from storage: $mobile');
    return mobile;
  }

  static Future<void> logout() async {
    appLogger.d('🚪 Logging out...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mobileKey);
    appLogger.i('✅ Logout complete');
  }
}
