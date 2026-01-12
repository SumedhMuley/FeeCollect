import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../database/database_helper.dart';

/// Service for handling local push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone
    tz_data.initializeTimeZones();
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    _isInitialized = true;
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    
    return true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // The app will open automatically when notification is tapped
    // The payload can be used to navigate to specific screens
    // ignore: avoid_print
    print('Notification tapped: ${response.payload}');
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pending_fees_channel',
      'Pending Fees',
      channelDescription: 'Notifications for pending fee payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Schedule a daily notification at a specific time
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    // Cancel existing scheduled notifications first
    await _notifications.cancel(1);
    
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Daily payment reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const details = NotificationDetails(android: androidDetails);
    
    await _notifications.zonedSchedule(
      1, // Fixed ID for daily reminder
      'Blue Academy',
      'Time to check pending payments!',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: 'pending_fees',
      uiLocalNotificationDateInterpretation: 
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Check pending fees and show notification if any
  Future<void> checkAndNotifyPendingFees() async {
    final db = DatabaseHelper.instance;
    
    try {
      final pendingFees = await db.getPendingFees();
      final overdueFees = await db.getOverdueFees();
      
      if (pendingFees.isEmpty) return;
      
      final pendingCount = pendingFees.length;
      final overdueCount = overdueFees.length;
      
      String title;
      String body;
      
      if (overdueCount > 0) {
        title = '⚠️ Overdue Payments';
        body = '$overdueCount payment${overdueCount > 1 ? 's are' : ' is'} overdue! Tap to send reminders.';
      } else {
        title = '💳 Pending Payments';
        body = 'You have $pendingCount pending payment${pendingCount > 1 ? 's' : ''}. Tap to view.';
      }
      
      await showNotification(
        id: 100,
        title: title,
        body: body,
        payload: 'pending_fees',
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error checking pending fees: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
