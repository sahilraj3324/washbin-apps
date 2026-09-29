import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/features/addresses/data/address_repository.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';

import '../support/fake_backend.dart';

AddressRepository _repository(FakeBackend backend, {String? token}) {
  return AddressRepository(
    apiClient: ApiClient(
      httpClient: backend.client,
      accessToken: () => token ?? 'washbin-token',
      baseUrl: 'https://api.test',
    ),
  );
}

const _draft = AddressDraft(
  label: AddressLabel.work,
  fullAddress: '221B Baker Street',
  city: 'Mumbai',
  state: 'Maharashtra',
  pincode: '400001',
  latitude: 19.076,
  longitude: 72.8777,
  houseNumber: 'Flat 4B',
  landmark: 'Opposite the metro',
);

void main() {
  group('reading', () {
    test('the address book is fetched with the bearer token', () async {
      final backend = FakeBackend()
        ..addresses = [FakeBackend.address(id: 'addr-1', isDefault: true)];

      final addresses = await _repository(backend).getMyAddresses();

      expect(addresses.single.id, 'addr-1');
      expect(
        backend.authorizationHeaders['/addresses/me'],
        'Bearer washbin-token',
      );
    });

    test('every field survives the round trip', () async {
      final backend = FakeBackend()
        ..addresses = [
          FakeBackend.address(
            id: 'addr-1',
            label: 'work',
            houseNumber: 'Flat 4B',
            landmark: 'Opposite the metro',
            isDefault: true,
          ),
        ];

      final address = (await _repository(backend).getMyAddresses()).single;

      expect(address.label, AddressLabel.work);
      expect(address.houseNumber, 'Flat 4B');
      expect(address.landmark, 'Opposite the metro');
      expect(address.latitude, 19.076);
      expect(address.longitude, 72.8777);
      expect(address.isDefault, isTrue);
      expect(address.streetLine, 'Flat 4B, 12 Marine Drive');
      expect(address.areaLine, 'Mumbai, Maharashtra 400020');
    });

    test('an unknown label falls back to home rather than throwing', () async {
      final backend = FakeBackend()
        ..addresses = [FakeBackend.address(id: 'a', label: 'holiday-house')];

      final address = (await _repository(backend).getMyAddresses()).single;

      expect(address.label, AddressLabel.home);
    });
  });

  group('writing', () {
    test('a draft is sent in the shape the API accepts', () async {
      final backend = FakeBackend();

      final saved = await _repository(backend).addAddress(_draft);

      expect(saved.label, AddressLabel.work);
      expect(saved.fullAddress, '221B Baker Street');
      // The label goes over the wire as the API's own string, not the enum.
      expect(backend.addresses.single['label'], 'work');
      // customerId is never sent: it comes from the token.
      expect(backend.addresses.single.containsKey('customerId'), isFalse);
    });

    test('the first address saved becomes the default on its own', () async {
      final backend = FakeBackend();

      final first = await _repository(backend).addAddress(_draft);

      expect(first.isDefault, isTrue);
    });

    test('promoting a default demotes the previous one', () async {
      final backend = FakeBackend();
      final repository = _repository(backend);

      final home = await repository.addAddress(_draft);
      final work = await repository.addAddress(_draft);
      expect(home.isDefault, isTrue);
      expect(work.isDefault, isFalse);

      await repository.setDefault(work.id);
      final addresses = await repository.getMyAddresses();

      expect(addresses.where((a) => a.isDefault).map((a) => a.id), [work.id]);
    });

    test('the default is listed first', () async {
      final backend = FakeBackend();
      final repository = _repository(backend);

      await repository.addAddress(_draft);
      final second = await repository.addAddress(_draft);
      await repository.setDefault(second.id);

      final addresses = await repository.getMyAddresses();

      expect(addresses.first.id, second.id);
    });

    test('deleting the default promotes another', () async {
      final backend = FakeBackend();
      final repository = _repository(backend);

      final first = await repository.addAddress(_draft);
      await repository.addAddress(_draft);

      await repository.deleteAddress(first.id);
      final left = await repository.getMyAddresses();

      expect(left, hasLength(1));
      expect(left.single.isDefault, isTrue);
    });

    test('an edit keeps the id and changes only what was sent', () async {
      final backend = FakeBackend();
      final repository = _repository(backend);
      final saved = await repository.addAddress(_draft);

      final updated = await repository.updateAddress(
        saved.id,
        const AddressDraft(
          label: AddressLabel.other,
          fullAddress: '10 Downing Street',
          city: 'Mumbai',
          state: 'Maharashtra',
          pincode: '400002',
          latitude: 19.1,
          longitude: 72.9,
        ),
      );

      expect(updated.id, saved.id);
      expect(updated.label, AddressLabel.other);
      expect(updated.fullAddress, '10 Downing Street');
    });
  });

  group('serviceability', () {
    test('a covered point is serviceable', () async {
      final backend = FakeBackend();

      final serviceable = await _repository(backend).isServiceable(
        point: const Coordinates(latitude: 19.08, longitude: 72.88),
        serviceId: 'svc-1',
      );

      expect(serviceable, isTrue);
      expect(backend.serviceabilityChecks.single, {
        'latitude': 19.08,
        'longitude': 72.88,
        'serviceId': 'svc-1',
      });
    });

    test('a point outside every area is not', () async {
      final backend = FakeBackend();

      final serviceable = await _repository(backend).isServiceable(
        // Delhi, well beyond the Mumbai area.
        point: const Coordinates(latitude: 28.6139, longitude: 77.209),
        serviceId: 'svc-1',
      );

      expect(serviceable, isFalse);
    });

    test('nowhere is serviceable when no areas are configured', () async {
      // Which is exactly what a freshly deployed API answers.
      final backend = FakeBackend()..serviceAreas = [];

      final serviceable = await _repository(backend).isServiceable(
        point: const Coordinates(latitude: 19.076, longitude: 72.8777),
        serviceId: 'svc-1',
      );

      expect(serviceable, isFalse);
    });

    test('an inactive service is never serviceable', () async {
      final backend = FakeBackend()
        ..services = [
          FakeBackend.service(
            id: 'svc-off',
            categoryId: 'cat-1',
            name: 'Retired',
            basePrice: 1,
            isActive: false,
          ),
        ];

      final serviceable = await _repository(backend).isServiceable(
        point: const Coordinates(latitude: 19.076, longitude: 72.8777),
        serviceId: 'svc-off',
      );

      expect(serviceable, isFalse);
    });

    test('an unknown service is an error, not a quiet false', () async {
      final backend = FakeBackend();

      await expectLater(
        _repository(backend).isServiceable(
          point: const Coordinates(latitude: 19.076, longitude: 72.8777),
          serviceId: 'svc-nope',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.badRequest,
          ),
        ),
      );
    });
  });
}
