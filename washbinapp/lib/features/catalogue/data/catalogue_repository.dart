import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/features/catalogue/domain/category.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// Everything the customer can browse before booking.
///
/// Customer-facing reads ask for `isActive=true`, because the same routes also
/// serve an admin view and would otherwise list things that were deliberately
/// taken down. The one exception is [getService]: a detail screen reached from
/// a stale list still has to render, and say the service is unavailable.
class CatalogueRepository {
  CatalogueRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<Category>> getCategories() async {
    final json = await _api.getJsonList(
      '/categories',
      query: const {'isActive': 'true'},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList(growable: false);
  }

  /// All active services, or only those in [categoryId].
  ///
  /// [activeOnly] is relaxed by the bookings list, which has to name the
  /// service on a past booking even if it has since been taken down.
  Future<List<Service>> getServices({
    String? categoryId,
    bool activeOnly = true,
  }) async {
    final json = await _api.getJsonList(
      '/services',
      query: {if (activeOnly) 'isActive': 'true', 'categoryId': ?categoryId},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(Service.fromJson)
        .toList(growable: false);
  }

  /// The services in one category.
  ///
  /// Uses the nested route rather than `/services?categoryId=`, because this
  /// one 404s on a category that does not exist instead of answering with an
  /// empty list — which is how the screen tells "nothing here yet" apart from
  /// "this link is stale".
  Future<List<Service>> getServicesInCategory(String categoryId) async {
    final json = await _api.getJsonList(
      '/categories/$categoryId/services',
      query: const {'isActive': 'true'},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(Service.fromJson)
        .toList(growable: false);
  }

  Future<Service> getService(String id) async {
    return Service.fromJson(await _api.getJson('/services/$id'));
  }

  Future<Category> getCategory(String id) async {
    return Category.fromJson(await _api.getJson('/categories/$id'));
  }
}
