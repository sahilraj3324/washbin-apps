import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinpartner/app/app_services.dart';
import 'package:washbinpartner/app/washbin_partner_app.dart';

import '../support/fake_backend.dart';
import '../support/fake_phone_auth_service.dart';

AppServices _services(FakeBackend backend) {
  return AppServices(
    httpClient: backend.client,
    phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    baseUrl: 'https://api.test',
  );
}

/// Boots straight into the signed-in app as a partner at [verificationStatus].
Future<void> _open(WidgetTester tester, FakeBackend backend) async {
  await tester.pumpWidget(WashbinPartnerApp(services: _services(backend)));
  await tester.pump(const Duration(milliseconds: 2600));
  await tester.pumpAndSettle();
}

FakeBackend _registered({String verificationStatus = 'pending'}) =>
    FakeBackend()
      ..requiresProfile = false
      ..verificationStatus = verificationStatus;

/// Brings [finder] on screen, whether it is merely scrolled out of view or
/// not built yet — the 800x600 test viewport is shorter than most of these
/// screens, and a ListView does not build what it cannot show.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // The outermost scrollable is the screen's own list; a form field can
    // bring its own (a dropdown's menu), so it is named rather than inferred.
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Fills the profile form the way a partner would and saves it.
Future<void> _fillProfile(WidgetTester tester) async {
  Future<void> enter(String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await _reveal(tester, field);
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  await enter('Email address', 'rahul@example.com');
  await enter('Years of experience', '6');
  await enter('Address line 1', '14 Shivaji Road');
  await enter('City', 'Mumbai');
  await enter('State', 'Maharashtra');
  await enter('Pincode', '400020');

  await _tapAndSettle(tester, find.widgetWithText(FilledButton, 'Save profile'));
}

void main() {
  group('the onboarding checklist', () {
    testWidgets('a new partner is told exactly what is outstanding', (
      tester,
    ) async {
      await _open(tester, _registered());

      expect(find.text('Finish setting up'), findsOneWidget);
      expect(
        find.textContaining('Still needed: Email address'),
        findsOneWidget,
      );
      expect(find.text('Choose the work you take on'), findsOneWidget);
    });

    testWidgets('submitting is refused until both steps are done', (
      tester,
    ) async {
      final backend = _registered();
      await _open(tester, backend);

      final submit = find.widgetWithText(FilledButton, 'Submit for review');
      await _reveal(tester, submit);

      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(
        find.text('Finish both steps above to send your profile to Washbin.'),
        findsOneWidget,
      );

      await tester.tap(submit);
      await tester.pumpAndSettle();
      // Not merely inert on screen: nothing reached the server.
      expect(backend.submitCalls, 0);
    });

    testWidgets('a complete profile alone is not enough', (tester) async {
      final backend = _registered()..completeProfile();
      await _open(tester, backend);

      expect(find.text('All set'), findsOneWidget);

      final submit = find.widgetWithText(FilledButton, 'Submit for review');
      await _reveal(tester, submit);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    });

    testWidgets('the service count comes from the backend, not the app', (
      tester,
    ) async {
      final backend = _registered()
        ..completeProfile()
        ..offerService('svc-1')
        ..offerService('svc-2')
        // Paused rows do not count: assignment skips them.
        ..offerService('svc-3', isActive: false);
      await _open(tester, backend);

      expect(find.text('You offer 2 services'), findsOneWidget);
    });
  });

  group('editing the profile', () {
    testWidgets('filling the form completes the checklist', (tester) async {
      final backend = _registered();
      await _open(tester, backend);

      await _tapAndSettle(tester, find.text('Profile details'));
      expect(find.text('Edit profile'), findsOneWidget);

      await _fillProfile(tester);

      // Back on the checklist, with the step now satisfied.
      expect(find.text('Finish setting up'), findsOneWidget);
      expect(find.text('All set'), findsOneWidget);
      expect(backend.profileUpdates.single['email'], 'rahul@example.com');
      expect(backend.profileUpdates.single['experienceYears'], 6);
      expect(
        (backend.profileUpdates.single['address']
            as Map<String, dynamic>)['pincode'],
        '400020',
      );
    });

    testWidgets('never sends a field the partner may not set', (tester) async {
      final backend = _registered();
      await _open(tester, backend);

      await _tapAndSettle(tester, find.text('Profile details'));
      await _fillProfile(tester);

      // A body carrying verificationStatus is how a partner would approve
      // themselves; the server rejects it, and the app must never try.
      final sent = backend.profileUpdates.single.keys.toSet();
      expect(sent.contains('verificationStatus'), isFalse);
      expect(sent.contains('status'), isFalse);
      expect(sent.contains('phone'), isFalse);
      expect(sent.contains('authUserId'), isFalse);
    });

    testWidgets('a bad pincode is caught before the request', (tester) async {
      final backend = _registered();
      await _open(tester, backend);

      await _tapAndSettle(tester, find.text('Profile details'));

      final pincode = find.widgetWithText(TextFormField, 'Pincode');
      await _reveal(tester, pincode);
      await tester.enterText(pincode, '4002');
      await _tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Save profile'),
      );

      expect(find.text('Enter a valid 6-digit pincode'), findsOneWidget);
      expect(backend.profileUpdates, isEmpty);
    });

    testWidgets('the verified number is shown but cannot be typed into', (
      tester,
    ) async {
      await _open(tester, _registered());
      await _tapAndSettle(tester, find.text('Profile details'));

      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(
        find.text('Verified by OTP. Contact support to change it.'),
        findsOneWidget,
      );
      // Not a form field at all, so there is nothing to submit.
      expect(
        find.widgetWithText(TextFormField, 'Mobile number'),
        findsNothing,
      );
    });
  });

  group('choosing services', () {
    testWidgets('lists the catalogue grouped by category', (tester) async {
      await _open(tester, _registered());
      await _tapAndSettle(tester, find.text('My services'));

      expect(find.text('Home Cleaning'), findsOneWidget);
      expect(find.text('Cooking'), findsOneWidget);
      expect(find.text('Deep Cleaning'), findsOneWidget);
      expect(find.text('Home Cook'), findsOneWidget);
    });

    testWidgets('selecting one creates the join row', (tester) async {
      final backend = _registered();
      await _open(tester, backend);
      await _tapAndSettle(tester, find.text('My services'));

      await _tapAndSettle(tester, find.text('Deep Cleaning'));

      expect(backend.partnerServices.values.single['serviceId'], 'svc-1');
      expect(backend.partnerServices.values.single['isActive'], true);
      expect(find.text('You offer 1 service.'), findsOneWidget);
    });

    testWidgets('clearing one pauses the row rather than deleting it', (
      tester,
    ) async {
      final backend = _registered()..offerService('svc-1');
      await _open(tester, backend);
      await _tapAndSettle(tester, find.text('My services'));

      await _tapAndSettle(tester, find.text('Deep Cleaning'));

      // The row survives with the flag off — the API has no partner-facing
      // delete, and keeping it is what lets re-selecting restore it.
      expect(backend.partnerServices.values.single['isActive'], false);
    });

    testWidgets('re-selecting reactivates instead of adding a second row', (
      tester,
    ) async {
      final backend = _registered()..offerService('svc-1', isActive: false);
      await _open(tester, backend);
      await _tapAndSettle(tester, find.text('My services'));

      await _tapAndSettle(tester, find.text('Deep Cleaning'));

      // A second POST would hit the unique index on (partnerId, serviceId)
      // and come back 409.
      expect(backend.partnerServices, hasLength(1));
      expect(backend.partnerServices.values.single['isActive'], true);
      expect(find.text('You offer 1 service.'), findsOneWidget);
    });

    testWidgets('a failed write is reported and changes nothing', (
      tester,
    ) async {
      final backend = _registered();
      await _open(tester, backend);
      await _tapAndSettle(tester, find.text('My services'));

      backend.partnerServicesFail = true;
      await _tapAndSettle(tester, find.text('Deep Cleaning'));

      expect(find.text('Internal server error'), findsOneWidget);
      expect(backend.partnerServices, isEmpty);
    });
  });

  group('submitting for review', () {
    testWidgets('a finished partner can send their profile to Washbin', (
      tester,
    ) async {
      final backend = _registered()
        ..completeProfile()
        ..offerService('svc-1');
      await _open(tester, backend);

      await _tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Submit for review'),
      );

      expect(backend.submitCalls, 1);
      expect(backend.verificationStatus, 'submitted');

      // The screen becomes its waiting form without a reload.
      expect(find.text('Pending approval'), findsOneWidget);
      expect(
        find.text(
          'Your profile has been submitted. We are reviewing your details, '
          'which usually takes 1-2 working days.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Submit for review'),
        findsNothing,
      );
    });

    testWidgets('the server refusing is shown, not swallowed', (tester) async {
      // The app thinks it is ready and the server disagrees — which is what a
      // drift between the two copies of the rule looks like.
      final backend = _registered()
        ..completeProfile()
        ..offerService('svc-1');
      await _open(tester, backend);

      backend.experienceYears = null;
      await _tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Submit for review'),
      );

      expect(
        find.textContaining('missing: experienceYears'),
        findsOneWidget,
      );
    });

    testWidgets('a rejected partner fixes and resubmits', (tester) async {
      final backend = _registered(verificationStatus: 'rejected')
        ..completeProfile()
        ..offerService('svc-1')
        ..rejectionReason = 'Document details are incomplete.';
      await _open(tester, backend);

      expect(find.text('Profile rejected'), findsOneWidget);
      expect(find.text('Document details are incomplete.'), findsOneWidget);

      await _tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Submit again'),
      );

      expect(backend.verificationStatus, 'submitted');
      // The old reason described a profile that no longer exists.
      expect(backend.rejectionReason, isNull);
      expect(find.text('Document details are incomplete.'), findsNothing);
      expect(find.text('Pending approval'), findsOneWidget);
    });
  });

  group('access to work', () {
    testWidgets('an unapproved partner has no route to jobs at all', (
      tester,
    ) async {
      for (final status in ['pending', 'submitted', 'rejected']) {
        final backend = _registered(verificationStatus: status)
          ..completeProfile()
          ..offerService('svc-1');
        await _open(tester, backend);

        expect(find.text('Jobs'), findsNothing, reason: 'at $status');
        expect(find.text('Bookings'), findsNothing, reason: 'at $status');
      }
    });

    testWidgets('a suspended partner gets no onboarding to work through', (
      tester,
    ) async {
      final backend = _registered(verificationStatus: 'verified')
        ..partnerStatus = 'suspended'
        ..completeProfile()
        ..offerService('svc-1');
      await _open(tester, backend);

      expect(find.text('Account suspended'), findsOneWidget);
      // Nothing they could edit would change the decision, so the checklist
      // is not offered.
      expect(find.text('Before you can go online'), findsNothing);
      expect(find.text('Profile details'), findsNothing);
      expect(find.text('Jobs'), findsNothing);
    });

    testWidgets('approval opens the shell, and the profile tab with it', (
      tester,
    ) async {
      final backend = _registered(verificationStatus: 'verified')
        ..completeProfile()
        ..offerService('svc-1');
      await _open(tester, backend);

      expect(find.text('Jobs'), findsOneWidget);

      await _tapAndSettle(tester, find.text('Profile'));
      expect(find.text('Verified partner'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('rahul@example.com'), findsOneWidget);
      expect(find.text('6 years'), findsOneWidget);
    });

    testWidgets('an approved partner can still change their services', (
      tester,
    ) async {
      final backend = _registered(verificationStatus: 'verified')
        ..completeProfile()
        ..offerService('svc-1');
      await _open(tester, backend);

      await _tapAndSettle(tester, find.text('Profile'));
      await _tapAndSettle(tester, find.text('My services'));

      await _tapAndSettle(tester, find.text('Home Cook'));
      expect(backend.partnerServices, hasLength(2));
      expect(find.text('You offer 2 services.'), findsOneWidget);
    });
  });
}
