/// One row of GET /notifications (src/notifications/notifications.service.ts
/// on the backend). `objectType`/`objectId` identify what to open on tap -
/// "Expense"/"Event"/"Settlement" - deep-linked the same way as a push-tap or
/// an incoming `digitalsettlement://` / https App Link.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? deepLink;
  final String objectType;
  final String objectId;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.objectType,
    required this.objectId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        deepLink: json['deepLink'] as String?,
        objectType: json['objectType'] as String? ?? '',
        objectId: json['objectId'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
