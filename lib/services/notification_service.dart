import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint(
        'Push notifications are currently disabled on Web.',
      );
      return;
    }

    // ---------------------------------------------------------------
    // Request notification permission
    // ---------------------------------------------------------------

    final settings =
        await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'Notification permission: '
      '${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus ==
        AuthorizationStatus.denied) {
      debugPrint(
        'Notification permission was denied.',
      );
      return;
    }

    // ---------------------------------------------------------------
    // Listen for Firebase account changes
    // ---------------------------------------------------------------

    _auth.authStateChanges().listen(
      (user) async {
        if (user != null) {
          await _saveTokenForUser(user);
        }
      },
    );

    // ---------------------------------------------------------------
    // Handle the user already being logged in
    // ---------------------------------------------------------------

    final currentUser = _auth.currentUser;

    if (currentUser != null) {
      await _saveTokenForUser(currentUser);
    }

    // ---------------------------------------------------------------
    // Token refresh
    // ---------------------------------------------------------------

    _messaging.onTokenRefresh.listen(
      (newToken) async {
        debugPrint(
          'FCM TOKEN REFRESHED.',
        );

        final user = _auth.currentUser;

        if (user != null) {
          await _saveTokenForUser(
            user,
            token: newToken,
          );
        }
      },
    );

    // ---------------------------------------------------------------
    // Notification received while app is open
    // ---------------------------------------------------------------

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        debugPrint(
          'Notification received while app is open.',
        );

        debugPrint(
          'Title: ${message.notification?.title}',
        );

        debugPrint(
          'Body: ${message.notification?.body}',
        );

        debugPrint(
          'Data: ${message.data}',
        );
      },
    );

    // ---------------------------------------------------------------
    // Notification tapped while app is in background
    // ---------------------------------------------------------------

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        debugPrint(
          'Notification opened.',
        );

        debugPrint(
          'Data: ${message.data}',
        );
      },
    );

    // ---------------------------------------------------------------
    // App launched by tapping a notification
    // ---------------------------------------------------------------

    final initialMessage =
        await _messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        'App launched from notification.',
      );

      debugPrint(
        'Data: ${initialMessage.data}',
      );
    }
  }

  // -----------------------------------------------------------------
  // Save this phone's FCM token to the logged-in user's profile.
  // -----------------------------------------------------------------

  Future<void> _saveTokenForUser(
    User user, {
    String? token,
  }) async {
    try {
      final fcmToken =
          token ?? await _messaging.getToken();

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint(
          'Could not get an FCM token.',
        );
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'fcmToken': fcmToken,
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        'FCM token saved for user: ${user.uid}',
      );
    } catch (e) {
      debugPrint(
        'Failed to save FCM token: $e',
      );
    }
  }

  // -----------------------------------------------------------------
  // Public helper in case we need to manually refresh the token.
  // -----------------------------------------------------------------

  Future<String?> getToken() async {
    if (kIsWeb) {
      return null;
    }

    return _messaging.getToken();
  }
}