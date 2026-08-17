import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'rail_sahayak_notifications',
    'RailSahayak Notifications',
    description: 'Assistance requests and status updates',
    importance: Importance.max,
  );

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('Push notifications are disabled on Web.');
      return;
    }

    const androidInitialization = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosInitialization = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidInitialization,
      iOS: iosInitialization,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'Notification permission: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission was denied.');
      return;
    }

    await _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveTokenForUser(user);
      }
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _saveTokenForUser(currentUser);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (newToken) async {
        final user = _auth.currentUser;
        if (user != null) {
          await _saveTokenForUser(user, token: newToken);
        }
      },
    );

    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        debugPrint('FCM foreground message: ${message.data}');

        final notification = message.notification;
        if (notification == null) {
          return;
        }

        await _showLocalNotification(
          title: notification.title ?? 'RailSahayak',
          body: notification.body ?? 'You have a new update.',
          payload: message.data['requestId']?.toString(),
        );
      },
    );

    await _openedMessageSubscription?.cancel();
    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        debugPrint('Notification opened: ${message.data}');
      },
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from notification: ${initialMessage.data}');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'rail_sahayak_notifications',
      'RailSahayak Notifications',
      channelDescription: 'Assistance requests and status updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
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

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _saveTokenForUser(
    User user, {
    String? token,
  }) async {
    try {
      final fcmToken = token ?? await _messaging.getToken();

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('Could not get an FCM token.');
        return;
      }

      await _firestore.collection('users').doc(user.uid).set(
        {
          'fcmToken': fcmToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('FCM token saved for user: ${user.uid}');
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      return null;
    }

    return _messaging.getToken();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
  }
}
