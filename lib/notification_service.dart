import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NOTIF] Background FCM: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _localReady = false;

  // The icon name must match an actual file in android/app/src/main/res/mipmap-*/
  static const _iconName = '@mipmap/app_logo';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (kIsWeb) return;
    debugPrint('[NOTIF] init() started');

    try {
      // ── Step 1: Create notification channel ──────────────────────────────
      debugPrint('[NOTIF] Creating notification channel...');
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      debugPrint('[NOTIF] Channel created ✓');

      // ── Step 2: Initialize local notifications ───────────────────────────
      debugPrint('[NOTIF] Initializing flutter_local_notifications...');
      final bool? initialized = await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings(_iconName),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );
      debugPrint('[NOTIF] flutter_local_notifications initialized=$initialized ✓');

      // ── Step 3: Request Android 13+ notification permission ──────────────
      debugPrint('[NOTIF] Requesting Android notification permission...');
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('[NOTIF] Notification permission granted=$granted');
      } else {
        debugPrint('[NOTIF] androidPlugin is null — skipping permission request');
      }

      _localReady = true;
      debugPrint('[NOTIF] _localReady=true ✓');

      // ── Step 4: Test notification to verify the pipeline ─────────────────
      await _sendTestNotification();

    } catch (e, st) {
      debugPrint('[NOTIF] ❌ Local notification init FAILED: $e\n$st');
    }

    // ── Step 5: FCM setup ─────────────────────────────────────────────────
    try {
      debugPrint('[NOTIF] Requesting FCM permission...');
      final settings = await _fcm.requestPermission(
          alert: true, badge: true, sound: true);
      debugPrint('[NOTIF] FCM authorizationStatus=${settings.authorizationStatus}');

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            _details(),
            payload: message.data['route'],
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data['route']);
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data['route']);
      }

      final token = await _fcm.getToken();
      debugPrint('[NOTIF] FCM Token: $token');
    } catch (e, st) {
      debugPrint('[NOTIF] ❌ FCM setup FAILED: $e\n$st');
    }

    debugPrint('[NOTIF] init() complete');
  }

  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: _iconName,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Returns false when the user has turned notifications OFF in Settings.
  Future<bool> _notificationsAllowed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_settings');
      if (raw == null) return true;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['notifications'] as bool? ?? true;
    } catch (_) {
      return true; // default to ON if anything goes wrong
    }
  }

  Future<void> _sendTestNotification() async {
    if (!await _notificationsAllowed()) {
      debugPrint('[NOTIF] Notifications OFF — skipping test notification');
      return;
    }
    debugPrint('[NOTIF] Sending test notification...');
    try {
      await _localNotifications.show(
        9999,
        '🔔 Kadai Notifications Active',
        'Notifications are working! Expiry alerts will appear here.',
        _details(),
      );
      debugPrint('[NOTIF] Test notification sent ✓');
    } catch (e) {
      debugPrint('[NOTIF] ❌ Test notification FAILED: $e');
    }
  }

  void _handleNotificationTap(String? route) {
    if (route == null) return;
    debugPrint('[NOTIF] Tapped → navigate to: $route');
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;
    return _fcm.getToken();
  }

  /// Shows a local notification. Waits up to 5 s for init to finish.
  /// Silently skips if the user has disabled notifications in Settings.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    if (!await _notificationsAllowed()) {
      debugPrint('[NOTIF] Notifications OFF — skipping id=$id');
      return;
    }

    debugPrint('[NOTIF] showLocalNotification(id=$id) _localReady=$_localReady');

    int waited = 0;
    while (!_localReady && waited < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }

    if (!_localReady) {
      debugPrint('[NOTIF] ❌ Gave up waiting — local notifications not ready');
      return;
    }

    try {
      await _localNotifications.show(id, title, body, _details(),
          payload: payload);
      debugPrint('[NOTIF] showLocalNotification(id=$id) sent ✓');
    } catch (e) {
      debugPrint('[NOTIF] ❌ showLocalNotification FAILED: $e');
    }
  }

  Future<void> showExpiryAlert({
    required String title,
    required String body,
  }) =>
      showLocalNotification(id: 1001, title: title, body: body);
}
