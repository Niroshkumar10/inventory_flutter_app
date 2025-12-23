import 'package:shared_preferences/shared_preferences.dart';

class SessionServiceNew {
  static const _mobileKey = 'logged_in_mobile';

  static Future<void> saveLogin(String mobile) async {
    print('💾 Saving login for mobile: $mobile');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mobileKey, mobile);
    print('✅ Mobile saved successfully');
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString(_mobileKey) ?? '';
    print('🔍 Retrieved mobile from storage: $mobile');
    return mobile;
  }

  static Future<void> logout() async {
    print('🚪 Logging out...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mobileKey);
    print('✅ Logout complete');
  }
}