import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/async/async_state.dart';
import 'package:washbinapp/core/widgets/app_empty_view.dart';
import 'package:washbinapp/core/widgets/app_error_view.dart';
import 'package:washbinapp/core/widgets/app_loading_indicator.dart';
import 'package:washbinapp/features/catalogue/data/catalogue_repository.dart';
import 'package:washbinapp/features/catalogue/domain/category.dart';
import 'package:washbinapp/features/catalogue/domain/home_catalogue.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';
import 'package:washbinapp/features/catalogue/widgets/category_card.dart';
import 'package:washbinapp/features/catalogue/widgets/section_heading.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/widgets/active_booking_card.dart';
import 'package:washbinapp/features/catalogue/widgets/service_card.dart';
import 'package:washbinapp/features/common/widgets/washbin_logo.dart';
import 'package:washbinapp/features/notifications/widgets/unread_badge.dart';

/// The Home tab: who you are, what you can book, and a shortcut to the
/// services the catalogue leads with.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AsyncController<HomeCatalogue>? _catalogue;

  /// Loaded separately from the catalogue, and allowed to fail on its own: a
  /// bookings outage must not stop a customer browsing services.
  ///
  /// This is what reconnects someone to a booking in progress after they
  /// close and reopen the app.
  AsyncController<_ActiveBooking?>? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Built here rather than in initState because the repository comes from
    // an inherited widget. Guarded so a rebuild does not refetch.
    if (_catalogue != null) {
      return;
    }
    final services = AppServicesScope.of(context);
    _catalogue = AsyncController(() => _read(services.catalogue))..load();
    _active = AsyncController(() => _readActive(services))..load();
  }

  static Future<HomeCatalogue> _read(CatalogueRepository repository) async {
    final results = await Future.wait([
      repository.getCategories(),
      repository.getServices(),
    ]);

    return HomeCatalogue(
      categories: results[0] as List<Category>,
      popularServices: (results[1] as List<Service>)
          .take(HomeCatalogue.popularLimit)
          .toList(growable: false),
    );
  }

  /// The newest booking that has not finished — completed and cancelled ones
  /// are deliberately never shown as active.
  static Future<_ActiveBooking?> _readActive(AppServices services) async {
    final bookings = await services.bookings.getMyBookings();
    final active = bookings.where((booking) => !booking.status.isSettled);

    if (active.isEmpty) {
      return null;
    }

    // Only now is the service name worth a request. Most customers have no
    // booking in progress, and they should not pay for this lookup.
    final booking = active.first;
    String? name;
    try {
      name = (await services.catalogue.getService(booking.serviceId)).name;
    } on ApiException {
      // The service may have been taken down. The booking still matters.
    }

    return _ActiveBooking(
      booking: booking,
      serviceName: name ?? 'Your booking',
    );
  }

  @override
  void dispose() {
    _catalogue?.dispose();
    _active?.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_catalogue!.refresh(), _active!.refresh()]);
  }

  Future<void> _openNotifications() async {
    final push = AppServicesScope.of(context).push;
    await Navigator.of(context).push(AppRouter.notifications());
    await push.refreshUnreadCount();
  }

  Future<void> _openTracking(_ActiveBooking active) async {
    await Navigator.of(context).push(
      AppRouter.bookingTracking(
        bookingId: active.booking.id,
        serviceName: active.serviceName,
        initial: active.booking,
      ),
    );
    // It may have been cancelled or completed while open.
    await _active?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _catalogue!;
    final customer = SessionScope.of(context).customer;

    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: _refreshAll,
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, _active]),
        builder: (context, _) {
          return CustomScrollView(
            // Always scrollable, so pull-to-refresh still works when the
            // content is an empty state that does not fill the screen.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(
                  name: customer?.givenName ?? '',
                  onNotifications: _openNotifications,
                ),
              ),
              ..._activeBooking(),
              ..._body(controller),
            ],
          );
        },
      ),
    );
  }

  /// Absent while loading and after any failure: a banner that flickers in
  /// and out, or reports a problem the customer cannot act on, is worse than
  /// no banner.
  List<Widget> _activeBooking() {
    final active = _active?.state.valueOrNull;

    if (active == null) {
      return const [];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: ActiveBookingCard(
            booking: active.booking,
            serviceName: active.serviceName,
            onView: () => _openTracking(active),
          ),
        ),
      ),
    ];
  }

  /// The catalogue is laid out as real slivers rather than a shrink-wrapped
  /// list inside one: a grid that measures its own height inside a viewport
  /// cannot report intrinsics, and the whole screen fails to lay out.
  List<Widget> _body(AsyncController<HomeCatalogue> controller) {
    return switch (controller.state) {
      AsyncLoading<HomeCatalogue>() => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppLoadingIndicator.fullScreen(label: 'Loading services'),
        ),
      ],
      AsyncFailure<HomeCatalogue>(:final error) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorView.fromException(error, onRetry: controller.load),
        ),
      ],
      AsyncData<HomeCatalogue>(:final value) ||
      AsyncRefreshing<HomeCatalogue>(:final value) => _catalogueSlivers(value),
    };
  }

  List<Widget> _catalogueSlivers(HomeCatalogue catalogue) {
    if (catalogue.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyView(
            title: 'No services yet',
            message:
                'Washbin is not live in your area just yet. Pull down to '
                'check again.',
            icon: Icons.home_repair_service_rounded,
          ),
        ),
      ];
    }

    return [
      if (catalogue.categories.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        const SliverToBoxAdapter(
          child: SectionHeading(title: 'What do you need?'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        _CategoryGrid(categories: catalogue.categories),
      ],
      if (catalogue.popularServices.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
        const SliverToBoxAdapter(
          child: SectionHeading(title: 'Popular services'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        _PopularServices(services: catalogue.popularServices),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ];
  }
}

/// A booking in progress, with the service name already looked up.
class _ActiveBooking {
  const _ActiveBooking({required this.booking, required this.serviceName});

  final Booking booking;
  final String serviceName;
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid.builder(
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryCard(
            category: category,
            onTap: () =>
                Navigator.of(context)
                    .push(AppRouter.categoryServices(category)),
          );
        },
      ),
    );
  }
}

class _PopularServices extends StatelessWidget {
  const _PopularServices({required this.services});

  final List<Service> services;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
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
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name, required this.onNotifications});

  final String name;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.red,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const WashbinLogo(size: 50, showShadow: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Washbin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.isEmpty ? 'Welcome' : 'Hi, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: AppServicesScope.of(context).push,
            builder: (context, _) {
              return UnreadBadge(
                count: AppServicesScope.of(context).push.unreadCount,
                child: IconButton.filledTonal(
                  onPressed: onNotifications,
                  icon: const Icon(Icons.notifications_none_rounded),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
