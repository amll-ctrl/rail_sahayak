import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'rail_sahayak_notifications',
    'RailSahayak Notifications',
    description: 'Assistance requests and status updates',
    importance: Importance.max,
  );

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _staffRequestSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _passengerRequestSubscription;

  bool _staffRequestListenerInitialized = false;
  bool _passengerRequestListenerInitialized = false;
  String? _notificationListenerUserId;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('Push notifications are disabled on Web.');
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission was denied.');
      return;
    }

    await _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      await _stopFirestoreNotificationListeners();
      if (user != null) {
        await _saveTokenForUser(user);
        await _watchUserProfile(user);
      }
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _saveTokenForUser(currentUser);
      await _watchUserProfile(currentUser);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      final user = _auth.currentUser;
      if (user != null) {
        await _saveTokenForUser(user, token: newToken);
      }
    });

    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('FCM foreground message: ${message.data}');
      final notification = message.notification;
      if (notification == null) return;

      await showLocalNotification(
        title: notification.title ?? 'RailSahayak',
        body: notification.body ?? 'You have a new update.',
        payload: message.data['requestId']?.toString(),
      );
    });

    await _openedMessageSubscription?.cancel();
    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened: ${message.data}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from notification: ${initialMessage.data}');
    }
  }

  Future<void> _watchUserProfile(User user) async {
    await _profileSubscription?.cancel();

    _notificationListenerUserId = user.uid;

    _profileSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (_notificationListenerUserId != user.uid) return;

      final data = snapshot.data();
      final role = (data?['role'] ?? 'passenger').toString().toLowerCase();

      await _stopFirestoreNotificationListeners();

      if (role == 'staff') {
        _startStaffRequestListener();
      } else {
        _startPassengerRequestListener(user.uid);
      }
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('User profile notification listener error: $error');
    });
  }

  void _startStaffRequestListener() {
    _staffRequestListenerInitialized = false;

    _staffRequestSubscription = _firestore.collection('requests').snapshots().listen((snapshot) async {
      if (!_staffRequestListenerInitialized) {
        _staffRequestListenerInitialized = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final passengerName = (data['passengerName'] ?? 'Passenger').toString();
        final trainNo = (data['trainNo'] ?? 'Train').toString();
        final coach = (data['coach'] ?? '').toString();

        await showLocalNotification(
          title: 'New assistance request',
          body: '$passengerName needs assistance on $trainNo${coach.isEmpty ? '' : ' • Coach $coach'}.',
          payload: change.doc.id,
        );
      }
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('Staff Firestore notification listener error: $error');
    });
  }

  void _startPassengerRequestListener(String userId) {
    _passengerRequestListenerInitialized = false;

    _passengerRequestSubscription = _firestore
        .collection('requests')
        .where('passengerId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      if (!_passengerRequestListenerInitialized) {
        _passengerRequestListenerInitialized = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final status = (data['status'] ?? 'Updated').toString();
        final trainNo = (data['trainNo'] ?? 'your train').toString();

        await showLocalNotification(
          title: 'Assistance request updated',
          body: 'Your request for $trainNo is now $status.',
          payload: change.doc.id,
        );
      }
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('Passenger Firestore notification listener error: $error');
    });
  }

  Future<void> _stopFirestoreNotificationListeners() async {
    await _staffRequestSubscription?.cancel();
    await _passengerRequestSubscription?.cancel();
    _staffRequestSubscription = null;
    _passengerRequestSubscription = null;
    _staffRequestListenerInitialized = false;
    _passengerRequestListenerInitialized = false;
  }

  Future<void> showLocalNotification({
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

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> _saveTokenForUser(User user, {String? token}) async {
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
    if (kIsWeb) return null;
    return _messaging.getToken();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    await _profileSubscription?.cancel();
    await _stopFirestoreNotificationListeners();
  }
}
