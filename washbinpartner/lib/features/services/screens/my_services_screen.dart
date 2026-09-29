import 'package:flutter/material.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/async/async_controller.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/core/widgets/app_empty_view.dart';
import 'package:washbinpartner/core/widgets/async_view.dart';
import 'package:washbinpartner/features/services/data/partner_services_repository.dart';
import 'package:washbinpartner/features/services/data/services_repository.dart';
import 'package:washbinpartner/features/services/domain/partner_service.dart';
import 'package:washbinpartner/features/services/domain/service.dart';
import 'package:washbinpartner/features/services/domain/service_selection.dart';
import 'package:washbinpartner/features/services/widgets/service_selection_tile.dart';

/// What this partner offers: the whole catalogue, with their choices applied.
///
/// Selecting and clearing are writes that happen one tap at a time — there is
/// no Save button, because the partner services API has no batch route and
/// pretending otherwise would mean a half-applied list on a failed save.
class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key, this.onChanged});

  /// Called after any successful change, so a caller showing a count can
  /// re-read it. The onboarding checklist uses this.
  final VoidCallback? onChanged;

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  late final ServicesRepository _services =
      AppServicesScope.of(context).services;
  late final PartnerServicesRepository _mine =
      AppServicesScope.of(context).partnerServices;

  late final AsyncController<ServiceSelectionView> _controller =
      AsyncController(_read);

  /// Service ids with a write in flight, so the same row cannot be tapped
  /// twice into two conflicting requests.
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ServiceSelectionView> _read() async {
    // One round trip each, in parallel: the catalogue does not depend on the
    // partner's rows.
    final results = await Future.wait([
      _services.getCategories(),
      _services.getServices(),
      _mine.getMine(),
    ]);

    return ServiceSelectionView.from(
      categories: results[0] as List<ServiceCategory>,
      services: results[1] as List<Service>,
      rows: results[2] as List<PartnerServiceRow>,
    );
  }

  /// Applies one tap.
  ///
  /// Three cases, and the difference matters: a service never chosen needs a
  /// new row, a paused one needs its existing row reactivated — the unique
  /// index would refuse a second — and a live one is paused rather than
  /// deleted, which is the only removal the API offers a partner.
  Future<void> _toggle(ServiceSelection selection) async {
    final serviceId = selection.service.id;
    if (_busy.contains(serviceId)) {
      return;
    }

    setState(() => _busy.add(serviceId));
    final messenger = ScaffoldMessenger.of(context);

    try {
      final row = selection.row;
      if (row == null) {
        await _mine.add(serviceId);
      } else {
        await _mine.setActive(rowId: row.id, isActive: !row.isActive);
      }

      await _controller.refresh();
      widget.onChanged?.call();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy.remove(serviceId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('My services'),
        backgroundColor: AppTheme.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return RefreshIndicator(
              color: AppTheme.red,
              onRefresh: _controller.refresh,
              child: AsyncView<ServiceSelectionView>(
                state: _controller.state,
                onRetry: _controller.load,
                loadingLabel: 'Loading services...',
                isEmpty: (view) => view.isEmpty,
                empty: const AppEmptyView(
                  title: 'No services yet',
                  message:
                      'Washbin has not published any services for partners to '
                      'choose from. Check back shortly.',
                  icon: Icons.home_repair_service_outlined,
                ),
                builder: (context, view) => _List(
                  view: view,
                  busy: _busy,
                  onToggle: _toggle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.view,
    required this.busy,
    required this.onToggle,
  });

  final ServiceSelectionView view;
  final Set<String> busy;
  final Future<void> Function(ServiceSelection selection) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _SelectedSummary(count: view.selectedCount),
        const SizedBox(height: 20),
        for (final group in view.groups) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.category.name,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (group.selectedCount > 0)
                  Text(
                    '${group.selectedCount} selected',
                    style: const TextStyle(
                      color: AppTheme.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          for (final selection in group.selections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ServiceSelectionTile(
                selection: selection,
                isBusy: busy.contains(selection.service.id),
                onTap: () => onToggle(selection),
              ),
            ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final none = count == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: none ? AppTheme.red.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(
            none ? Icons.info_outline_rounded : Icons.check_circle_rounded,
            color: none ? AppTheme.red : const Color(0xFF1B8A4B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              none
                  ? 'Choose at least one service. Customers only see partners '
                        'for the work they offer.'
                  : 'You offer $count ${count == 1 ? 'service' : 'services'}.',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
