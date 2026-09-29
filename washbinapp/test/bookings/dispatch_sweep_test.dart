import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/core/api/dev_tools_api.dart';
import 'package:washbinapp/app/washbin_app.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 14; frame++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<AppServices> _signedIn(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  backend.requiresProfile = false;
  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    locationService: FakeLocationService(),
    messagingService: FakeMessagingService(),
    baseUrl: 'https://api.test',
    trackingPollInterval: null,
  );

  await tester.pumpWidget(WashbinApp(services: services));
  await tester.pump(const Duration(milliseconds: 3200));
  await _settle(tester);
  return services;
}

Map<String, dynamic> _scheduled() => FakeBackend.booking(
  id: '68c1f4aa930b148ed80df6ab',
  status: 'pending',
  bookingType: 'scheduled',
  scheduledAt: DateTime.now()
      .add(const Duration(minutes: 20))
      .toUtc()
      .toIso8601String(),
);

void main() {
  group('the sweep call', () {
    DevToolsApi devToolsFor(FakeBackend backend) => DevToolsApi(
      apiClient: ApiClient(
        httpClient: backend.client,
        accessToken: () => 'washbin-token',
        baseUrl: 'https://api.test',
      ),
    );

    test('reports what the sweep did', () async {
      final backend = FakeBackend()..bookings = [_scheduled()];

      final result = await devToolsFor(backend).runDispatchSweep();

      expect(result.dispatched, 1);
      expect(result.summary, contains('1 scheduled dispatched'));
      expect(backend.bookings.single['status'], 'searching_partner');
    });

    test('an older server without the dispatcher is not misreported', () async {
      // A deployment that predates scheduled dispatch answers without the
      // field; claiming "0 dispatched" would look like it ran and found none.
      final backend = FakeBackend()..bookings = [_scheduled()];
      final api = ApiClient(
        httpClient: backend.client,
        baseUrl: 'https://api.test',
      );

      final legacy = SweepResult.fromJson(const {
        'expired': 2,
        'readvanced': 1,
      });

      expect(legacy.dispatched, isNull);
      expect(legacy.summary, contains('dispatch not deployed'));
      api.close();
    });
  });

  group('the developer card', () {
    testWidgets('is hidden in a production build', (tester) async {
      // ENV defaults to production, so this is what a release build shows.
      await _signedIn(tester, FakeBackend());
      await tester.tap(find.text('Profile'));
      await _settle(tester);

      expect(find.text('Run dispatch sweep'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });
}
