import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const _customerChannelId = 'order_updates';
  static const _customerChannelName = 'Order Updates';
  static const _riderChannelId = 'new_orders';
  static const _riderChannelName = 'New Order Alerts';

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/notification_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    await _setupChannels();
  }

  static Future<void> _setupChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Customer channel — default importance
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _customerChannelId,
      _customerChannelName,
      description: 'Order status updates for customers',
      importance: Importance.defaultImportance,
      playSound: true,
    ));

    // Rider channel — MAX importance (heads-up, loud)
    await android?.createNotificationChannel(AndroidNotificationChannel(
      _riderChannelId,
      _riderChannelName,
      description: 'New pickup and delivery job alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
      enableLights: true,
      ledColor: const Color(0xFF9333EA),
    ));

    // Request Android 13+ permission
    await android?.requestNotificationsPermission();
  }

  // ─── Customer: order status update ──────────────────────────────────────

  static Future<void> showOrderUpdate({
    required String title,
    required String body,
    int id = 100,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _customerChannelId,
      _customerChannelName,
      channelDescription: 'Order status updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/notification_icon',
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(id, title, body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails));
  }

  // ─── Rider: new order / delivery job alert (heads-up + sound) ───────────

  static Future<void> showNewOrderAlert({
    required String title,
    required String body,
    int id = 200,
  }) async {
    final vibration = Int64List.fromList([0, 400, 200, 400, 200, 400]);
    final androidDetails = AndroidNotificationDetails(
      _riderChannelId,
      _riderChannelName,
      channelDescription: 'New order alerts',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@drawable/notification_icon',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibration,
      enableLights: true,
      ledColor: const Color(0xFF9333EA),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: const BigTextStyleInformation(''),
      ticker: title,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(id, title, body,
        NotificationDetails(android: androidDetails, iOS: iosDetails));
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
