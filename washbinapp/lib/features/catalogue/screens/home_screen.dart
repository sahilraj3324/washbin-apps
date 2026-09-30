import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/widgets/active_booking_card.dart';
import 'package:washbinapp/features/catalogue/widgets/service_card.dart';
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
            scrollCacheExtent: const ScrollCacheExtent.pixels(1600),
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
        const SliverToBoxAdapter(child: _OffersSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        const SliverToBoxAdapter(
          child: _HomeSectionTitle(
            title: 'Find Your Perfect Home Services',
            subtitle: 'What do you need?',
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        _CategoryGrid(categories: catalogue.categories),
      ],
      if (catalogue.popularServices.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: _HomeSectionTitle(
            title: 'Seasonal Service',
            subtitle: 'Seasonal needs, sorted in one click',
          ),
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
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.03,
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD84A), AppTheme.washbinYellow],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_rounded, color: AppTheme.ink, size: 22),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Home' : 'Home, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.deepNavy,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '₹0',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ListenableBuilder(
                listenable: AppServicesScope.of(context).push,
                builder: (context, _) {
                  return UnreadBadge(
                    count: AppServicesScope.of(context).push.unreadCount,
                    foreground: AppTheme.deepNavy,
                    child: IconButton.filled(
                      onPressed: onNotifications,
                      icon: const Icon(Icons.person_rounded),
                      color: AppTheme.washbinYellow,
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.black.withValues(alpha: 0.45),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name.isEmpty
                ? 'Schedule pickup, wash, fold, and doorstep delivery'
                : 'Hi, $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: 0.78),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppTheme.ink, size: 26),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Search for "Wash & Iron"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF4A4F59),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Fresh Laundry.\nVerified Care.',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(52),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.local_laundry_service_rounded,
                      color: AppTheme.deepNavy,
                      size: 54,
                    ),
                    Positioned(
                      right: 18,
                      top: 24,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppTheme.deepNavy,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Smarter Care For Your Clothes.',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.verified_user_rounded,
                  label: 'EXPERTS',
                  value: '1K+',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.event_available_rounded,
                  label: 'BOOKINGS',
                  value: '100K+',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.star_rounded,
                  label: 'RATED',
                  value: '4.9+',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.deepNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.washbinYellow, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersSection extends StatelessWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Offers & Updates',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _CircleArrow(icon: Icons.chevron_left_rounded, onTap: () {}),
              const SizedBox(width: 10),
              _CircleArrow(icon: Icons.chevron_right_rounded, onTap: () {}),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 178,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _OfferPainter()),
                const Positioned(
                  left: 22,
                  bottom: 28,
                  child: Text(
                    'One Tap to\nClean That Stack',
                    style: TextStyle(
                      color: AppTheme.deepNavy,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 0.98,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const Positioned(
                  left: 24,
                  bottom: 14,
                  child: Text(
                    'Book pickup with WashBin',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(isActive: false),
              SizedBox(width: 8),
              _Dot(isActive: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleArrow extends StatelessWidget {
  const _CircleArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Color(0xFFD5D7DC),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.ink : const Color(0xFFD6D8DC),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1.12,
            ),
          ),
          if (title == 'Seasonal Service') ...[
            const SizedBox(height: 4),
            const Text(
              'Popular services',
              style: TextStyle(
                color: AppTheme.washbinYellow,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF5C6068),
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()..color = AppTheme.washbinYellow;
    final counter = Paint()..color = Colors.white.withValues(alpha: 0.86);
    final machine = Paint()..color = const Color(0xFFB9D4F2);
    final dark = Paint()..color = AppTheme.ink.withValues(alpha: 0.82);
    final pipe = Paint()
      ..color = AppTheme.deepNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, back);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 66), counter);
    canvas.drawRect(
      Rect.fromLTWH(18, 32, size.width - 36, 26),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.58, 50, 104, 108),
        const Radius.circular(8),
      ),
      machine,
    );
    canvas.drawCircle(
      Offset(size.width * 0.58 + 52, 104),
      28,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(Offset(size.width * 0.58 + 52, 104), 19, dark);

    final path = Path()
      ..moveTo(size.width * 0.58 + 52, 138)
      ..quadraticBezierTo(size.width * 0.46, 160, size.width * 0.32, 138)
      ..quadraticBezierTo(size.width * 0.2, 118, size.width * 0.12, 146);
    canvas.drawPath(path, pipe);

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.1, 70, size.width * 0.28, 74),
      Paint()..color = AppTheme.black.withValues(alpha: 0.24),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
