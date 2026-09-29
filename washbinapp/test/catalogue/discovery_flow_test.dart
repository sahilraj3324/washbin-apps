import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

/// Boots straight into the signed-in app over a scripted catalogue.
///
/// The default test surface is 800x600 — a shape no phone has — which makes a
/// two-column grid tall enough to push the service list off screen. These
/// screens are laid out for a phone, so the tests measure one.
Future<AppServices> _signedIn(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  backend.requiresProfile = false;
  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    locationService: FakeLocationService(),
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

void main() {
  group('home', () {
    testWidgets('shows categories and popular services', (tester) async {
      await _signedIn(tester, FakeBackend());

      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('Home Cleaning'), findsOneWidget);
      expect(find.text('Cooking'), findsOneWidget);

      expect(find.text('Popular services'), findsOneWidget);
      expect(find.text('Deep Cleaning'), findsOneWidget);
      expect(find.text('₹299'), findsOneWidget);
      expect(find.text('30 mins'), findsOneWidget);
    });

    testWidgets('an empty catalogue reads as empty, not broken', (
      tester,
    ) async {
      await _signedIn(
        tester,
        FakeBackend()
          ..categories = []
          ..services = [],
      );

      expect(find.text('No services yet'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a failed load offers a retry that works', (tester) async {
      final backend = FakeBackend()..catalogueFails = true;
      await _signedIn(tester, backend);

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('What do you need?'), findsNothing);

      backend.catalogueFails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Home Cleaning'), findsOneWidget);
    });

    testWidgets('pull-to-refresh picks up a newly added category', (
      tester,
    ) async {
      final backend = FakeBackend();
      await _signedIn(tester, backend);
      expect(find.text('Plumbing'), findsNothing);

      backend.categories = [
        ...backend.categories,
        FakeBackend.category(id: 'cat-3', name: 'Plumbing', sortOrder: 2),
      ];

      await tester.fling(
        find.text('What do you need?'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Plumbing'), findsOneWidget);
    });

    testWidgets('the greeting uses the first name only', (tester) async {
      await _signedIn(tester, FakeBackend());

      expect(find.text('Hi, Rahul'), findsOneWidget);
    });
  });

  group('category to detail', () {
    testWidgets('a category opens its own services', (tester) async {
      await _signedIn(tester, FakeBackend());

      await tester.tap(find.text('Home Cleaning'));
      await tester.pumpAndSettle();

      // The category bar, plus its one service — and not the other category's.
      expect(find.text('Home Cleaning'), findsOneWidget);
      expect(find.text('Deep Cleaning'), findsOneWidget);
      expect(find.text('Home Cook'), findsNothing);
    });

    testWidgets('an empty category says so without looking broken', (
      tester,
    ) async {
      await _signedIn(tester, FakeBackend()..services = []);

      await tester.tap(find.text('Cooking'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing in Cooking yet'), findsOneWidget);
    });

    testWidgets('a service opens its detail screen', (tester) async {
      await _signedIn(tester, FakeBackend());

      await tester.tap(find.text('Deep Cleaning'));
      await tester.pumpAndSettle();

      expect(find.text('About this service'), findsOneWidget);
      expect(find.text('A thorough job, done well.'), findsOneWidget);
      expect(find.text('Estimated time: 30 mins'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('back returns to the list it came from', (tester) async {
      await _signedIn(tester, FakeBackend());

      await tester.tap(find.text('Home Cleaning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deep Cleaning'));
      await tester.pumpAndSettle();
      expect(find.text('About this service'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('About this service'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('What do you need?'), findsOneWidget);
    });
  });

  group('service detail', () {
    testWidgets('Continue asks where, and books nothing', (tester) async {
      final backend = FakeBackend();
      await _signedIn(tester, backend);
      await tester.tap(find.text('Deep Cleaning'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Where the service happens decides whether it can be booked at all,
      // so it is asked before anything else. Still nothing is booked.
      expect(find.text('Choose location'), findsOneWidget);
      // Home reads bookings for its active-booking card; what matters is that
      // nothing was *created*.
      expect(backend.bookingAttempts, isEmpty);
    });

    testWidgets('a service taken down since the list loaded is not bookable', (
      tester,
    ) async {
      final backend = FakeBackend();
      await _signedIn(tester, backend);

      // Taken down between the list being drawn and the detail being opened.
      backend.services = [
        FakeBackend.service(
          id: 'svc-1',
          categoryId: 'cat-1',
          name: 'Deep Cleaning',
          basePrice: 299,
          durationMinutes: 30,
          isActive: false,
        ),
        ...backend.services.where((row) => row['_id'] != 'svc-1'),
      ];

      await tester.tap(find.text('Deep Cleaning'));
      await tester.pumpAndSettle();

      expect(
        find.text('This service is not available right now.'),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('a failed re-read leaves the service on screen', (
      tester,
    ) async {
      final backend = FakeBackend();
      await _signedIn(tester, backend);

      backend.catalogueFails = true;
      await tester.tap(find.text('Deep Cleaning'));
      await tester.pumpAndSettle();

      // The row the list already had is real; losing the refresh is not a
      // reason to show an error page instead of it.
      expect(find.text('About this service'), findsOneWidget);
      expect(find.text('₹299'), findsWidgets);
    });
  });

  group('services tab', () {
    testWidgets('lists every active service across categories', (tester) async {
      await _signedIn(tester, FakeBackend());

      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();

      expect(find.text('Deep Cleaning'), findsOneWidget);
      expect(find.text('Home Cook'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('1 hr'), findsOneWidget);
    });

    testWidgets('an inactive service never appears in a list', (tester) async {
      await _signedIn(
        tester,
        FakeBackend()
          ..services = [
            FakeBackend.service(
              id: 'svc-off',
              categoryId: 'cat-1',
              name: 'Retired Service',
              basePrice: 199,
              isActive: false,
            ),
          ],
      );

      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();

      expect(find.text('Retired Service'), findsNothing);
      expect(find.text('No services yet'), findsOneWidget);
    });
  });
}
