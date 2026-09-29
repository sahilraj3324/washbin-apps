import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:washbinapp/app/washbin_app.dart';

/// Runs in its own isolate when a push arrives with the app backgrounded or
/// closed.
///
/// Nothing to do here: every notification the app sends carries an FCM
/// `notification` block, which the system tray renders on its own, and the
/// stored copy is read from the API when the app next opens. Registering a
/// handler at all is what stops the plugin warning on every cold start.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads android/app/google-services.json and
  // ios/Runner/GoogleService-Info.plist. Phone sign-in cannot work without
  // them, so this runs before the first frame.
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

  runApp(const WashbinApp());
}
