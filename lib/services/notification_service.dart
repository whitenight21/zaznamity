// Add these imports at the top of lib/services/notification_service.dart:
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    tz.initializeTimeZones(); // Initialize timezone database for zoned scheduling

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
      icon: 'zaznamity_logo',
    );
    const details = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(0, title, body, details);
  }

  // ADD THIS METHOD for scheduling bill/transaction reminders:
  static Future<void> scheduleTransactionReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required int daysBefore,
    required int hoursBefore,
  }) async {
    // Calculate the notification trigger time
    DateTime triggerTime = scheduledDate
        .subtract(Duration(days: daysBefore))
        .copyWith(hour: hoursBefore, minute: 0, second: 0, millisecond: 0);

    // Only schedule if the trigger time is in the future
    if (triggerTime.isAfter(DateTime.now())) {
      const androidDetails = AndroidNotificationDetails(
        'zaznamity_channel', 
        'Zaznamity Reminders', 
        importance: Importance.max, 
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(triggerTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}