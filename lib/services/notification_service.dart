import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    // Use positional argument for version 17.x
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
  }

  static Future<void> showInstantNotification({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'zaznamity_channel', 
      'Zaznamity Reminders', 
      importance: Importance.max, 
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    
    // Use positional arguments for version 17.x
    await _notificationsPlugin.show(
      0, 
      title, 
      body, 
      details,
    );
  }

  static Future<void> cancelNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}