import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';
import 'package:washbinapp/features/addresses/data/location_service.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

/// Boots signed in, on a phone-shaped surface, over a scripted backend and a
/// device that has no GPS.
Future<AppServices> _signedIn(
  WidgetTester tester,
  FakeBackend backend, {
  FakeLocationService? location,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  backend.requiresProfile = false;
  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    locationService: location ?? FakeLocationService(),
    baseUrl: 'https://api.test',
    // No poll timer firing under the test; polling has its own test.
    // Real FCM would reach Firebase, which no test has initialised.
    messagingService: FakeMessagingService(),
    trackingPollInterval: null,
  );

  await tester.pumpWidget(WashbinApp(services: services));
  await tester.pump(const Duration(milliseconds: 3200));
  await tester.pumpAndSettle();
  return services;
}

/// Home → service detail → Continue → the location picker.
Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Deep Cleaning'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  group('reaching the picker', () {
    testWidgets('Continue on a service opens Choose location', (tester) async {
      await _signedIn(tester, FakeBackend());
      await _openPicker(tester);

      expect(find.text('Choose location'), findsOneWidget);
      expect(find.text('Use my current location'), findsOneWidget);
      expect(find.text('Saved addresses'), findsOneWidget);
    });

    testWidgets('with no addresses saved it says so', (tester) async {
      await _signedIn(tester, FakeBackend());
      await _openPicker(tester);

      expect(find.textContaining('No saved addresses yet'), findsOneWidget);
      expect(find.text('Select a location'), findsOneWidget);
    });

    testWidgets('saved addresses are listed, default first', (tester) async {
      final backend = FakeBackend()
        ..addresses = [
          FakeBackend.address(id: 'a1', label: 'other'),
          FakeBackend.address(id: 'a2', label: 'work', isDefault: true),
        ];
      await _signedIn(tester, backend);
      await _openPicker(tester);

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .where((data) => data == 'Work' || data == 'Other')
          .toList();
      expect(labels.first, 'Work');
    });
  });

  group('serviceability', () {
    testWidgets('a covered address is accepted and enables Continue', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..addresses = [FakeBackend.address(id: 'a1', isDefault: true)];
      await _signedIn(tester, backend);
      await _openPicker(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.textContaining('we serve this area'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(backend.serviceabilityChecks.single['serviceId'], isNotNull);
    });

    testWidgets('an uncovered address is refused with a reason', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..addresses = [
          // Delhi, outside the Mumbai operational area.
          FakeBackend.address(
            id: 'a1',
            city: 'New Delhi',
            latitude: 28.6139,
            longitude: 77.209,
            isDefault: true,
          ),
        ];
      await _signedIn(tester, backend);
      await _openPicker(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.textContaining('does not cover this area'), findsOneWidget);
      // Continue stays unavailable, so nothing unserviceable can go forward.
      expect(find.text('Select a location'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('picking a covered address after a refused one recovers', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..addresses = [
          FakeBackend.address(
            id: 'far',
            label: 'work',
            city: 'New Delhi',
            latitude: 28.6139,
            longitude: 77.209,
          ),
          FakeBackend.address(id: 'near', isDefault: true),
        ];
      await _signedIn(tester, backend);
      await _openPicker(tester);

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not cover this area'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.textContaining('we serve this area'), findsOneWidget);
      expect(find.textContaining('does not cover this area'), findsNothing);
    });

    testWidgets('Continue moves on to the booking, creating nothing yet', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..addresses = [FakeBackend.address(id: 'a1', isDefault: true)];
      await _signedIn(tester, backend);
      await _openPicker(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The location is settled; when and what still are not.
      expect(find.text('When do you need it?'), findsOneWidget);
      expect(backend.bookingAttempts, isEmpty);
      expect(backend.bookings, isEmpty);
    });
  });

  group('current location', () {
    testWidgets('a granted fix is checked and accepted', (tester) async {
      final location = FakeLocationService();
      final backend = FakeBackend();
      await _signedIn(tester, backend, location: location);
      await _openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(location.requests, 1);
      expect(find.textContaining('we serve this area'), findsOneWidget);
      expect(backend.serviceabilityChecks.single['latitude'], 19.076);
    });

    testWidgets('a fix outside the service area is refused', (tester) async {
      final location = FakeLocationService(
        position: const Coordinates(latitude: 28.6139, longitude: 77.209),
      );
      await _signedIn(tester, FakeBackend(), location: location);
      await _openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('does not cover this area'), findsOneWidget);
      expect(find.text('Select a location'), findsOneWidget);
    });

    testWidgets('a declined permission explains the alternative', (
      tester,
    ) async {
      final location = FakeLocationService(
        failure: const LocationException(
          LocationFailure.denied,
          'Washbin needs your location to find help nearby. You can also pick '
          'a saved address instead.',
        ),
      );
      await _signedIn(tester, FakeBackend(), location: location);
      await _openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('pick a saved address'), findsOneWidget);
      // A refusal is not an error screen: the saved addresses are still there.
      expect(find.text('Saved addresses'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
    });

    testWidgets('a permanent denial offers the settings screen', (
      tester,
    ) async {
      final location = FakeLocationService(
        failure: const LocationException(
          LocationFailure.deniedForever,
          'Location is blocked for Washbin.',
        ),
      );
      await _signedIn(tester, FakeBackend(), location: location);
      await _openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(location.settingsOpened, 1);
    });

    testWidgets('location switched off is reported as such', (tester) async {
      final location = FakeLocationService(
        failure: const LocationException(
          LocationFailure.serviceDisabled,
          'Location is switched off on this device.',
        ),
      );
      await _signedIn(tester, FakeBackend(), location: location);
      await _openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('switched off'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
    });
  });
}
