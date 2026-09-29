import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/app_empty_view.dart';
import 'package:washbinapp/core/widgets/async_view.dart';
import 'package:washbinapp/features/catalogue/data/catalogue_repository.dart';
import 'package:washbinapp/features/catalogue/domain/category.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';
import 'package:washbinapp/features/catalogue/widgets/service_card.dart';

/// A list of services — every active one, or just those in [category].
///
/// The same screen serves the Services tab and the category drill-down,
/// because they differ only in which read they run and what the bar says.
class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key, this.category});

  /// Null lists the whole catalogue.
  final Category? category;

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  AsyncController<List<Service>>? _services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_services != null) {
      return;
    }
    final repository = AppServicesScope.of(context).catalogue;
    _services = AsyncController(() => _read(repository))..load();
  }

  Future<List<Service>> _read(CatalogueRepository repository) {
    final category = widget.category;

    return category == null
        ? repository.getServices()
        : repository.getServicesInCategory(category.id);
  }

  @override
  void dispose() {
    _services?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final controller = _services!;

    final body = RefreshIndicator(
      color: AppTheme.red,
      onRefresh: controller.refresh,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return AsyncView<List<Service>>(
            state: controller.state,
            onRetry: controller.load,
            loadingLabel: 'Loading services',
            isEmpty: (services) => services.isEmpty,
            empty: _empty(controller.state.valueOrNull == null),
            builder: (context, services) => _ServiceList(services: services),
          );
        },
      ),
    );

    // In the Services tab there is no bar to add; the shell owns the chrome.
    if (category == null) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _empty(bool neverLoaded) {
    final category = widget.category;

    return AppEmptyView(
      title: category == null
          ? 'No services yet'
          : 'Nothing in ${category.name} yet',
      message: neverLoaded
          ? null
          : 'Pull down to check again once more are added.',
      icon: Icons.home_repair_service_rounded,
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.services});

  final List<Service> services;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = services[index];
        return ServiceCard(
          service: service,
          onTap: () =>
              Navigator.of(context).push(AppRouter.serviceDetail(service)),
        );
      },
    );
  }
}
