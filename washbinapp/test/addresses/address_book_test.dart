import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

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

/// Profile tab → Saved addresses.
Future<void> _openAddressBook(WidgetTester tester) async {
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Saved addresses'));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, String action) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty address book invites adding one', (tester) async {
    await _signedIn(tester, FakeBackend());
    await _openAddressBook(tester);

    expect(find.text('No addresses yet'), findsOneWidget);
    expect(find.text('Add an address'), findsOneWidget);
  });

  testWidgets('saved addresses are listed with the default marked', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..addresses = [
        FakeBackend.address(id: 'a1', isDefault: true),
        FakeBackend.address(id: 'a2', label: 'work'),
      ];
    await _signedIn(tester, backend);
    await _openAddressBook(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('an address can be added end to end', (tester) async {
    final backend = FakeBackend();
    await _signedIn(tester, backend);
    await _openAddressBook(tester);

    await tester.tap(find.text('Add an address'));
    await tester.pumpAndSettle();
    expect(find.text('Add address'), findsWidgets);

    // Coordinates are the one thing that cannot be typed.
    await tester.tap(find.text('Use current'));
    await tester.pumpAndSettle();
    expect(find.text('Map location set'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '12 Marine Drive',
    );
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(backend.addresses, hasLength(1));
    // The geocoder prefilled city, state and PIN from the fix.
    expect(backend.addresses.single['city'], 'Mumbai');
    expect(backend.addresses.single['pincode'], '400020');
    expect(backend.addresses.single['latitude'], 19.076);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('saving without a location says what is missing', (tester) async {
    await _signedIn(tester, FakeBackend());
    await _openAddressBook(tester);
    await tester.tap(find.text('Add an address'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '12 Marine Drive',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'City'),
      'Mumbai',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'State'),
      'Maharashtra',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'PIN code'),
      '400020',
    );
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Set the location'), findsOneWidget);
  });

  testWidgets('a bad PIN code is caught before the request', (tester) async {
    final backend = FakeBackend();
    await _signedIn(tester, backend);
    await _openAddressBook(tester);
    await tester.tap(find.text('Add an address'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use current'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '12 Marine Drive',
    );
    // Indian PIN codes never start with zero — the same rule the API applies.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'PIN code'),
      '012345',
    );
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a six-digit PIN code'), findsOneWidget);
    expect(backend.addresses, isEmpty);
  });

  testWidgets('an address can be edited', (tester) async {
    final backend = FakeBackend()
      ..addresses = [FakeBackend.address(id: 'a1', isDefault: true)];
    await _signedIn(tester, backend);
    await _openAddressBook(tester);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Edit address'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Landmark (optional)'),
      'Next to the pier',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(backend.addresses.single['landmark'], 'Next to the pier');
    expect(find.text('Near Next to the pier'), findsOneWidget);
  });

  testWidgets('the default can be moved to another address', (tester) async {
    final backend = FakeBackend()
      ..addresses = [
        FakeBackend.address(id: 'a1', isDefault: true),
        FakeBackend.address(id: 'a2', label: 'work'),
      ];
    await _signedIn(tester, backend);
    await _openAddressBook(tester);

    // The current default offers no "set as default" — the API cannot clear
    // one, so the option would only produce a refusal.
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Set as default'), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();

    final defaults = backend.addresses
        .where((row) => row['isDefault'] == true)
        .map((row) => row['_id']);
    expect(defaults, ['a2']);
  });

  testWidgets('deleting asks first, and keeping it changes nothing', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..addresses = [FakeBackend.address(id: 'a1', isDefault: true)];
    await _signedIn(tester, backend);
    await _openAddressBook(tester);

    await _openMenu(tester, 'Delete');
    expect(find.text('Delete this address?'), findsOneWidget);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(backend.addresses, hasLength(1));
  });

  testWidgets('confirming a delete removes it', (tester) async {
    final backend = FakeBackend()
      ..addresses = [
        FakeBackend.address(id: 'a1', isDefault: true),
        FakeBackend.address(id: 'a2', label: 'work'),
      ];
    await _signedIn(tester, backend);
    await _openAddressBook(tester);

    await _openMenu(tester, 'Delete');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(backend.addresses.map((row) => row['_id']), ['a2']);
    // Deleting the default promotes the survivor, so a booking still has
    // somewhere to go.
    expect(backend.addresses.single['isDefault'], isTrue);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('a failed load offers a retry that works', (tester) async {
    final backend = FakeBackend()
      ..addresses = [FakeBackend.address(id: 'a1', isDefault: true)]
      ..addressesFail = true;
    await _signedIn(tester, backend);
    await _openAddressBook(tester);

    expect(find.text('Try again'), findsOneWidget);

    backend.addressesFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
