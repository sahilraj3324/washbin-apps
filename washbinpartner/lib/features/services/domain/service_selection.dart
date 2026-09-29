import 'package:washbinpartner/features/services/domain/partner_service.dart';
import 'package:washbinpartner/features/services/domain/service.dart';

/// One row of the "My Services" screen: a service Washbin offers, and whether
/// this partner has opted in to it.
class ServiceSelection {
  const ServiceSelection({required this.service, this.row});

  final Service service;

  /// The partner's join row, or null when they have never chosen this service.
  final PartnerServiceRow? row;

  bool get isSelected => row?.isActive ?? false;

  /// True when the partner offered this before and turned it off. Selecting it
  /// again reactivates the existing row instead of creating a second one —
  /// which the unique index on (partnerId, serviceId) would refuse anyway.
  bool get isPaused => row != null && !row!.isActive;
}

/// The whole screen's state: every service Washbin offers, grouped under its
/// category, with this partner's choices applied.
class ServiceSelectionView {
  const ServiceSelectionView({required this.groups});

  /// Joins the catalogue to the partner's rows.
  ///
  /// Built from the catalogue rather than from the partner's rows, so a
  /// service is listed whether or not they have ever considered it. A row
  /// pointing at a service that is no longer in the catalogue is dropped: it
  /// cannot be displayed, and the partner cannot act on it.
  factory ServiceSelectionView.from({
    required List<ServiceCategory> categories,
    required List<Service> services,
    required List<PartnerServiceRow> rows,
  }) {
    final rowsByService = {for (final row in rows) row.serviceId: row};
    final servicesByCategory = <String, List<ServiceSelection>>{};

    for (final service in services) {
      servicesByCategory
          .putIfAbsent(service.categoryId, () => [])
          .add(
            ServiceSelection(
              service: service,
              row: rowsByService[service.id],
            ),
          );
    }

    final ordered = [...categories]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });

    final groups = <ServiceGroup>[];
    for (final category in ordered) {
      final selections = servicesByCategory.remove(category.id);
      if (selections == null || selections.isEmpty) {
        continue;
      }

      selections.sort((a, b) {
        final byOrder = a.service.sortOrder.compareTo(b.service.sortOrder);
        return byOrder != 0
            ? byOrder
            : a.service.name.compareTo(b.service.name);
      });
      groups.add(ServiceGroup(category: category, selections: selections));
    }

    // A service whose category is missing or inactive would otherwise vanish
    // from the screen while still counting towards the partner's total.
    final orphans = servicesByCategory.values.expand((rows) => rows).toList();
    if (orphans.isNotEmpty) {
      orphans.sort((a, b) => a.service.name.compareTo(b.service.name));
      groups.add(
        ServiceGroup(
          category: const ServiceCategory(id: '', name: 'Other services'),
          selections: orphans,
        ),
      );
    }

    return ServiceSelectionView(groups: groups);
  }

  final List<ServiceGroup> groups;

  Iterable<ServiceSelection> get all =>
      groups.expand((group) => group.selections);

  List<ServiceSelection> get selected =>
      all.where((selection) => selection.isSelected).toList(growable: false);

  int get selectedCount => selected.length;

  bool get isEmpty => groups.isEmpty;

  /// Whether this partner offers anything at all, which is one of the two
  /// conditions on submitting for review.
  bool get hasAnySelected => selectedCount > 0;
}

/// The services of one category, as a section of the list.
class ServiceGroup {
  const ServiceGroup({required this.category, required this.selections});

  final ServiceCategory category;
  final List<ServiceSelection> selections;

  int get selectedCount =>
      selections.where((selection) => selection.isSelected).length;
}
