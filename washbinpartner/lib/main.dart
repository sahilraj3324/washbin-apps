import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:washbinpartner/app/washbin_partner_app.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads android/app/google-services.json and
  // ios/Runner/GoogleService-Info.plist. Phone sign-in cannot work without
  // them, so this runs before the first frame.
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

  runApp(const WashbinPartnerApp());
}
