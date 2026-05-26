import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_app/features/session/session_service_new.dart';

class AuthNotifier extends ChangeNotifier {
  String? _userMobile;
  bool _initialized = false;
  bool _splashDone = false;
  bool _isFirstTime = true;

  String? get userMobile => _userMobile;
  bool get isAuthenticated => _userMobile != null && _userMobile!.isNotEmpty;
  bool get initialized => _initialized;
  bool get splashDone => _splashDone;
  bool get isFirstTime => _isFirstTime;

  Future<void> init() async {
    try {
      _userMobile = await SessionServiceNew.getUserId();
    } catch (_) {
      _userMobile = null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _isFirstTime = prefs.getBool('isFirstTime') ?? true;
    } catch (_) {
      _isFirstTime = true;
    }
    _initialized = true;
    debugPrint('[AuthNotifier] init() — mobile="$_userMobile" isAuth=$isAuthenticated isFirstTime=$_isFirstTime');
    notifyListeners();
  }

  void markSplashDone() {
    if (_splashDone) return;
    _splashDone = true;
    notifyListeners();
  }

  void setUser(String mobile) {
    _userMobile = mobile;
    _initialized = true;
    debugPrint('[AuthNotifier] setUser("$mobile") — isAuth=$isAuthenticated');
    notifyListeners();
  }

  void clearUser() {
    debugPrint('[AuthNotifier] clearUser() called — was "$_userMobile"');
    _userMobile = null;
    notifyListeners();
  }
}
