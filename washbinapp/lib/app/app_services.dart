import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/core/api/dev_tools_api.dart';
import 'package:washbinapp/core/api/health_api.dart';
import 'package:washbinapp/core/session/access_token_store.dart';
import 'package:washbinapp/core/session/session_controller.dart';
import 'package:washbinapp/features/auth/data/auth_api.dart';
import 'package:washbinapp/features/auth/data/phone_auth_service.dart';
import 'package:washbinapp/features/addresses/data/address_repository.dart';
import 'package:washbinapp/features/addresses/data/location_service.dart';
import 'package:washbinapp/features/bookings/data/booking_repository.dart';
import 'package:washbinapp/features/catalogue/data/catalogue_repository.dart';
import 'package:washbinapp/features/notifications/data/messaging_service.dart';
import 'package:washbinapp/features/notifications/data/notification_repository.dart';
import 'package:washbinapp/features/notifications/data/push_notifications.dart';
import 'package:washbinapp/features/profile/data/customer_repository.dart';

/// Builds the object graph once, at startup, and hands it to the widget tree.
///
/// Wiring lives here rather than in widgets so that a test can substitute an
/// HTTP client or a Firebase stand-in without touching any screen.
class AppServices {
  AppServices({
    http.Client? httpClient,
    PhoneAuthService? phoneAuthService,
    LocationService? locationService,
    MessagingService? messagingService,
    String? baseUrl,
    this.trackingPollInterval = const Duration(seconds: 10),
  }) {
    location = locationService ?? LocationService();
    messaging = messagingService ?? MessagingService();
    tokens = AccessTokenStore();
    phoneAuth = phoneAuthService ?? PhoneAuthService();

    apiClient = ApiClient(
      httpClient: httpClient,
      accessToken: tokens.read,
      baseUrl: baseUrl,
    );

    authApi = AuthApi(apiClient: apiClient);
    customers = CustomerRepository(apiClient: apiClient);
    catalogue = CatalogueRepository(apiClient: apiClient);
    addresses = AddressRepository(apiClient: apiClient);
    bookings = BookingRepository(apiClient: apiClient);
    notifications = NotificationRepository(apiClient: apiClient);
    push = PushNotifications(repository: notifications, messaging: messaging);
    health = HealthApi(apiClient: apiClient);
    devTools = DevToolsApi(apiClient: apiClient);

    session = SessionController(
      authApi: authApi,
      phoneAuthService: phoneAuth,
      customerRepository: customers,
      tokenStore: tokens,
    );

    // Closed last: the client is built before the session that reacts to its
    // 401s, so this is the one link that cannot be set in a constructor.
    apiClient.onUnauthorized = session.handleUnauthorized;

    // Push starts only once the app knows whose device this is, and is
    // retired before the session is cleared — otherwise the next customer to
    // sign in on this phone would receive the previous one's updates.
    session
      ..addListener(_syncPush)
      ..beforeSignOut = push.stop;
  }

  /// The navigator of the signed-in area, so a tapped notification can open a
  /// booking from outside the widget tree.
  final signedInNavigatorKey = GlobalKey<NavigatorState>();

  void _syncPush() {
    if (session.isSignedIn) {
      unawaited(push.start());
    }
  }

  late final AccessTokenStore tokens;
  late final PhoneAuthService phoneAuth;
  late final ApiClient apiClient;
  late final AuthApi authApi;
  late final CustomerRepository customers;
  late final CatalogueRepository catalogue;
  late final AddressRepository addresses;
  late final BookingRepository bookings;
  late final NotificationRepository notifications;
  late final MessagingService messaging;
  late final PushNotifications push;
  late final LocationService location;

  /// How often the tracking screen re-reads a live booking.
  ///
  /// Null disables polling entirely — which is how tests run without a timer
  /// firing underneath them, and what a future realtime feed would set once
  /// status changes are pushed instead of pulled.
  final Duration? trackingPollInterval;
  late final HealthApi health;
  late final DevToolsApi devTools;
  late final SessionController session;

  void dispose() {
    session
      ..removeListener(_syncPush)
      ..dispose();
    push.dispose();
    apiClient.close();
  }
}
