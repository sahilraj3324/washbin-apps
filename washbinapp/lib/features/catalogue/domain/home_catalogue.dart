import 'package:washbinapp/features/catalogue/domain/category.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// What the home screen needs, read in one go.
///
/// Both lists are fetched together so the screen has a single loading state
/// rather than two spinners racing each other.
class HomeCatalogue {
  const HomeCatalogue({
    required this.categories,
    required this.popularServices,
  });

  final List<Category> categories;

  /// The API has no popularity signal — no booking counts, no ratings — so
  /// this is the start of the admin's own display order. When a real signal
  /// exists, only this field's source changes.
  final List<Service> popularServices;

  /// How many services the home screen shows before the customer has to open
  /// a category.
  static const popularLimit = 6;

  bool get isEmpty => categories.isEmpty && popularServices.isEmpty;
}
