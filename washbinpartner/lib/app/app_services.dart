import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/core/api/health_api.dart';
import 'package:washbinpartner/core/session/access_token_store.dart';
import 'package:washbinpartner/core/session/session_controller.dart';
import 'package:washbinpartner/features/auth/data/auth_api.dart';
import 'package:washbinpartner/features/auth/data/phone_auth_service.dart';
import 'package:washbinpartner/features/availability/data/availability_repository.dart';
import 'package:washbinpartner/features/availability/data/partner_location_service.dart';
import 'package:washbinpartner/features/jobs/data/job_execution_repository.dart';
import 'package:washbinpartner/features/jobs/data/job_offers_repository.dart';
import 'package:washbinpartner/features/notifications/data/messaging_service.dart';
import 'package:washbinpartner/features/notifications/data/notification_repository.dart';
import 'package:washbinpartner/features/notifications/data/push_notifications.dart';
import 'package:washbinpartner/features/partner/data/partner_repository.dart';
import 'package:washbinpartner/features/services/data/partner_services_repository.dart';
import 'package:washbinpartner/features/services/data/services_repository.dart';

/// Builds the object graph once, at startup, and hands it to the widget tree.
///
/// Wiring lives here rather than in widgets so that a test can substitute an
/// HTTP client or a Firebase stand-in without touching any screen.
class AppServices {
  AppServices({
    http.Client? httpClient,
    PhoneAuthService? phoneAuthService,
    PartnerLocationService? locationService,
    MessagingService? messagingService,
    String? baseUrl,
  }) {
    tokens = AccessTokenStore();
    phoneAuth = phoneAuthService ?? PhoneAuthService();

    apiClient = ApiClient(
      httpClient: httpClient,
      accessToken: tokens.read,
      baseUrl: baseUrl,
    );

    authApi = AuthApi(apiClient: apiClient);
    partners = PartnerRepository(apiClient: apiClient);
    services = ServicesRepository(apiClient: apiClient);
    partnerServices = PartnerServicesRepository(apiClient: apiClient);
    availability = AvailabilityRepository(apiClient: apiClient);
    jobOffers = JobOffersRepository(apiClient: apiClient);
    jobExecution = JobExecutionRepository(apiClient: apiClient);
    notifications = NotificationRepository(apiClient: apiClient);
    messaging = messagingService ?? MessagingService();
    push = PushNotifications(repository: notifications, messaging: messaging);
    location = locationService ?? PartnerLocationService();
    health = HealthApi(apiClient: apiClient);

    session = SessionController(
      authApi: authApi,
      phoneAuthService: phoneAuth,
      partnerRepository: partners,
      tokenStore: tokens,
    );

    // Closed last: the client is built before the session that reacts to its
    // 401s, so this is the one link that cannot be set in a constructor.
    apiClient.onUnauthorized = session.handleUnauthorized;

    session
      ..addListener(_syncPush)
      ..beforeSignOut = push.stop;
  }

  void _syncPush() {
    if (session.isSignedIn) {
      unawaited(push.start());
    }
  }

  late final AccessTokenStore tokens;
  late final PhoneAuthService phoneAuth;
  late final ApiClient apiClient;
  late final AuthApi authApi;
  late final PartnerRepository partners;
  late final ServicesRepository services;
  late final PartnerServicesRepository partnerServices;
  late final AvailabilityRepository availability;
  late final JobOffersRepository jobOffers;
  late final JobExecutionRepository jobExecution;
  late final NotificationRepository notifications;
  late final MessagingService messaging;
  late final PushNotifications push;
  late final PartnerLocationService location;
  late final HealthApi health;
  late final SessionController session;

  void dispose() {
    session
      ..removeListener(_syncPush)
      ..dispose();
    push.dispose();
    apiClient.close();
  }
}
