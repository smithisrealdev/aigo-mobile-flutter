import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

// TODO: Add google-services.json to android/app/
// TODO: Add GoogleService-Info.plist to ios/Runner/
// TODO: Run flutterfire configure to generate firebase_options.dart

/// Top-level background message handler (must be top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(dynamic message) async {
  try {
    // Firebase must be initialized for background handlers.
    // final _ = await Firebase.initializeApp();
    debugPrint('NotificationService: Background message received');
  } catch (e) {
    debugPrint('NotificationService: Background handler error: $e');
  }
}

/// Push notification service using FCM + local notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

  /// Initialize FCM, request permissions, store token.
  Future<void> init() async {
    if (_initialized) return;
    try {
      // Import these dynamically so the app compiles without Firebase config.
      // When Firebase is configured, uncomment and use:
      //
      // final messaging = FirebaseMessaging.instance;
      //
      // // Request permission
      // final settings = await messaging.requestPermission(
      //   alert: true,
      //   badge: true,
      //   sound: true,
      // );
      // debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');
      //
      // // Get FCM token
      // final token = await messaging.getToken();
      // debugPrint('NotificationService: FCM token: $token');
      //
      // // Store token in Supabase user metadata
      // if (token != null) {
      //   await _storeFcmToken(token);
      // }
      //
      // // Listen for token refresh
      // messaging.onTokenRefresh.listen(_storeFcmToken);
      //
      // // Setup handlers
      // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      // setupForegroundHandler();
      //
      // // Handle notification that opened the app
      // final initialMessage = await messaging.getInitialMessage();
      // if (initialMessage != null) {
      //   _handleNotificationTap(initialMessage);
      // }
      //
      // FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _initialized = true;
      debugPrint('NotificationService: Initialized (Firebase not yet configured)');
    } catch (e) {
      debugPrint('NotificationService: init failed (expected without Firebase config): $e');
    }
  }

  /// Store FCM token in Supabase user metadata.
  // ignore: unused_element
  Future<void> _storeFcmToken(String token) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(data: {'fcm_token': token}),
      );
      debugPrint('NotificationService: FCM token stored in Supabase');
    } catch (e) {
      debugPrint('NotificationService: Failed to store FCM token: $e');
    }
  }

  /// Show local notification when app is in foreground.
  void setupForegroundHandler() {
    // When Firebase is configured, uncomment:
    //
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   final notification = message.notification;
    //   if (notification == null) return;
    //
    //   // Show local notification
    //   _showLocalNotification(
    //     title: notification.title ?? '',
    //     body: notification.body ?? '',
    //     payload: message.data['type'] ?? '',
    //   );
    // });
    debugPrint('NotificationService: Foreground handler ready (Firebase not configured)');
  }

  /// Handle notification tap — navigate based on type.
  // ignore: unused_element
  void _handleNotificationTap(dynamic message) {
    // When Firebase is configured, message will be RemoteMessage:
    //
    // final data = message.data;
    // final type = data['type'] as String?;
    // final tripId = data['trip_id'] as String?;
    //
    // switch (type) {
    //   case 'price_alert':
    //     // Navigate to price alerts screen
    //     debugPrint('Navigate to price alerts');
    //     break;
    //   case 'trip_reminder':
    //     // Navigate to trip detail
    //     if (tripId != null) {
    //       debugPrint('Navigate to trip: $tripId');
    //     }
    //     break;
    //   case 'collaboration':
    //     // Navigate to trip + show changes
    //     if (tripId != null) {
    //       debugPrint('Navigate to trip collaboration: $tripId');
    //     }
    //     break;
    //   default:
    //     debugPrint('Unknown notification type: $type');
    // }
    debugPrint('NotificationService: Notification tapped');
  }

  /// Show a local notification (foreground).
  // ignore: unused_element
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    // ignore: unused_element_parameter
    String? payload,
  }) async {
    // When flutter_local_notifications is configured:
    //
    // const androidDetails = AndroidNotificationDetails(
    //   'aigo_channel',
    //   'AiGo Notifications',
    //   channelDescription: 'Trip updates, price alerts, and collaboration',
    //   importance: Importance.high,
    //   priority: Priority.high,
    // );
    // const iosDetails = DarwinNotificationDetails();
    // const details = NotificationDetails(
    //   android: androidDetails,
    //   iOS: iosDetails,
    // );
    //
    // await FlutterLocalNotificationsPlugin().show(
    //   DateTime.now().millisecondsSinceEpoch ~/ 1000,
    //   title,
    //   body,
    //   details,
    //   payload: payload,
    // );
    debugPrint('NotificationService: Local notification: $title');
  }

  /// Subscribe to FCM topic for trip updates.
  Future<void> subscribeToTripUpdates(String tripId) async {
    try {
      // await FirebaseMessaging.instance.subscribeToTopic('trip_$tripId');
      debugPrint('NotificationService: Subscribed to trip_$tripId');
    } catch (e) {
      debugPrint('NotificationService: Subscribe failed: $e');
    }
  }

  /// Unsubscribe from FCM topic.
  Future<void> unsubscribeFromTripUpdates(String tripId) async {
    try {
      // await FirebaseMessaging.instance.unsubscribeFromTopic('trip_$tripId');
      debugPrint('NotificationService: Unsubscribed from trip_$tripId');
    } catch (e) {
      debugPrint('NotificationService: Unsubscribe failed: $e');
    }
  }
}

// ── Riverpod providers ──

final notificationServiceProvider =
    Provider((_) => NotificationService.instance);
