import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/features/catalogue/data/catalogue_repository.dart';

import '../support/fake_backend.dart';

CatalogueRepository _repository(FakeBackend backend) {
  return CatalogueRepository(
    apiClient: ApiClient(
      httpClient: backend.client,
      baseUrl: 'https://api.test',
    ),
  );
}

void main() {
  test('customer-facing reads ask for active rows only', () async {
    final backend = FakeBackend();
    final repository = _repository(backend);

    await repository.getCategories();
    await repository.getServices();
    await repository.getServicesInCategory('cat-1');

    expect(backend.queries['/categories'], {'isActive': 'true'});
    expect(backend.queries['/services'], {'isActive': 'true'});
    expect(backend.queries['/categories/cat-1/services'], {'isActive': 'true'});
  });

  test('a category filter is passed through as a query parameter', () async {
    final backend = FakeBackend();

    await _repository(backend).getServices(categoryId: 'cat-2');

    expect(backend.queries['/services'], {
      'isActive': 'true',
      'categoryId': 'cat-2',
    });
  });

  test('the category route returns only that category\'s services', () async {
    final backend = FakeBackend();

    final services = await _repository(backend).getServicesInCategory('cat-1');

    expect(services.map((service) => service.name), ['Deep Cleaning']);
  });

  test('an unknown category is a 404, not an empty list', () async {
    // The distinction the app needs: "nothing here yet" versus "stale link".
    final backend = FakeBackend();

    await expectLater(
      _repository(backend).getServicesInCategory('cat-gone'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.notFound,
        ),
      ),
    );
  });

  test('a service detail read works for an inactive service', () async {
    // A list is filtered to active rows, but a detail screen reached from a
    // stale list still has to render and say the service is unavailable.
    final backend = FakeBackend()
      ..services = [
        FakeBackend.service(
          id: 'svc-off',
          categoryId: 'cat-1',
          name: 'Retired Service',
          basePrice: 199,
          isActive: false,
        ),
      ];

    final listed = await _repository(backend).getServices();
    final detail = await _repository(backend).getService('svc-off');

    expect(listed, isEmpty);
    expect(detail.name, 'Retired Service');
    expect(detail.isActive, isFalse);
  });

  test('a failing catalogue surfaces a retryable error', () async {
    final backend = FakeBackend()..catalogueFails = true;

    await expectLater(
      _repository(backend).getCategories(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.kind, 'kind', ApiErrorKind.server)
            .having((error) => error.isRetryable, 'isRetryable', isTrue),
      ),
    );
  });

  test('an object where an array was expected does not crash', () async {
    final backend = FakeBackend()..categories = [];
    final repository = _repository(backend);

    // Sanity: the empty case is an empty list, not an error.
    expect(await repository.getCategories(), isEmpty);
  });
}
