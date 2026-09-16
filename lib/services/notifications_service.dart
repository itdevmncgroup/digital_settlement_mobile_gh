import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/app_notification.dart';
import 'api_client.dart';

/// In-app + push notification state (GET /notifications on the backend) -
/// mirrors AuthService's ChangeNotifier + try/catch-and-log shape. Device
/// token register/unregister are best-effort: Firebase may not be configured
/// yet (no google-services.json/GoogleService-Info.plist), and a failure here
/// must never block login/logout.
class NotificationsService extends ChangeNotifier {
  final ApiClient api;
  NotificationsService(this.api);

  List<AppNotification> items = [];
  int unreadCount = 0;
  bool loading = false;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final list = await api.get('/notifications') as List;
      items = list.map((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
      final countRes = await api.get('/notifications/unread-count') as Map<String, dynamic>;
      unreadCount = countRes['count'] as int? ?? 0;
    } catch (e, st) {
      developer.log('Failed to load notifications', name: 'notifications', error: e, stackTrace: st);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    try {
      await api.patch('/notifications/$id/read');
      final i = items.indexWhere((n) => n.id == id);
      if (i != -1 && !items[i].read) {
        items[i] = AppNotification(
          id: items[i].id,
          type: items[i].type,
          title: items[i].title,
          body: items[i].body,
          deepLink: items[i].deepLink,
          objectType: items[i].objectType,
          objectId: items[i].objectId,
          read: true,
          createdAt: items[i].createdAt,
        );
        unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e, st) {
      developer.log('Failed to mark notification read', name: 'notifications', error: e, stackTrace: st);
    }
  }

  /// Registers this device's current FCM token against the logged-in user.
  /// Call once after login (see login_screen.dart) - a no-op if Firebase
  /// isn't configured yet.
  Future<void> registerDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
      await api.post('/notifications/device-tokens', {'token': token, 'platform': platform});
    } catch (e, st) {
      developer.log('Failed to register device token', name: 'notifications', error: e, stackTrace: st);
    }
  }

  /// Unlinks this device's FCM token from the account - call before clearing
  /// the session (see profile_screen.dart's logout button) so a shared device
  /// stops receiving the previous user's push after logout.
  Future<void> unregisterDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await api.delete('/notifications/device-tokens/$token');
    } catch (e, st) {
      developer.log('Failed to unregister device token', name: 'notifications', error: e, stackTrace: st);
    }
  }
}
