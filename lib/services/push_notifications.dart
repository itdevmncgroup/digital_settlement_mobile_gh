import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'deep_link_handler.dart';
import 'notifications_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'approval_activity',
  'Approval activity',
  description: 'Expense and settlement approvals awaiting your review',
  importance: Importance.high,
);

/// Background/terminated-state FCM messages are delivered to a top-level
/// (non-instance) function per the firebase_messaging plugin contract - it
/// runs in its own isolate, so it can't touch app state (Provider, the
/// navigatorKey); it exists only so the platform doesn't drop the message
/// before the app is running to handle it via onMessageOpenedApp/getInitialMessage.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Wires up push notifications: requests permission, registers this device's
/// token, and handles a tap in every app state (foreground/background/
/// terminated). Safe to call even when Firebase isn't configured yet
/// (no google-services.json/GoogleService-Info.plist) - every step is
/// try/catch-guarded so the app keeps working without push.
Future<void> setupPushNotifications({
  required GlobalKey<NavigatorState> navigatorKey,
  required NotificationsService notifications,
}) async {
  try {
    if (Firebase.apps.isEmpty) return; // Firebase.initializeApp() in main.dart didn't run/succeed.

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final path = response.payload;
        if (path != null) handleDeepLink(navigatorKey, path);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    await notifications.registerDeviceToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => notifications.registerDeviceToken());

    // Foreground: FCM alone shows no banner (that's platform behavior for
    // background/terminated only), so surface one via flutter_local_notifications
    // and bump the in-app badge.
    FirebaseMessaging.onMessage.listen((message) {
      notifications.refresh();
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(android: AndroidNotificationDetails(_androidChannel.id, _androidChannel.name)),
        payload: message.data['deepLink'] as String?,
      );
    });

    // Tapped from background (app was alive, just backgrounded).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final path = message.data['deepLink'] as String?;
      if (path != null && path.isNotEmpty) handleDeepLink(navigatorKey, path);
    });

    // App was launched cold by tapping a push (terminated state).
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    final initialPath = initialMessage?.data['deepLink'] as String?;
    if (initialPath != null && initialPath.isNotEmpty) handleDeepLink(navigatorKey, initialPath);
  } catch (e, st) {
    developer.log('Push notification setup failed - continuing without push', name: 'notifications', error: e, stackTrace: st);
  }
}
