import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/app_empty_view.dart';
import 'package:washbinapp/core/widgets/async_view.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_bucket.dart';
import 'package:washbinapp/features/bookings/domain/bookings_view.dart';
import 'package:washbinapp/features/bookings/widgets/booking_card.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// The Bookings tab: everything the customer has ever asked for, split into
/// what is happening now, what is coming, and what is over.
///
/// The server is the whole history — nothing is kept locally — so the lists
/// here are whatever `GET /bookings` last returned, grouped for reading.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => BookingsScreenState();
}

class BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  AsyncController<BookingsView>? _view;
  late final TabController _tabs = TabController(
    length: BookingBucket.values.length,
    vsync: this,
  );

  String? _busyId;

  /// False until the tab has been opened for the first time.
  ///
  /// The shell builds every tab up front and keeps them alive, so an unopened
  /// Bookings tab would otherwise sit there showing a spinner — animating
  /// every frame, forever, behind whatever the customer is actually looking
  /// at. Nothing is drawn and nothing is fetched until it is asked for.
  bool _requested = false;

  /// Opened on the first non-empty tab, once.
  bool _hasChosenOpeningTab = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_view != null) {
      return;
    }
    final services = AppServicesScope.of(context);
    _view = AsyncController(() async {
      final results = await Future.wait([
        services.bookings.getMyBookings(),
        // Inactive ones included: a past booking still has to name its
        // service even after the service has been taken down.
        services.catalogue.getServices(activeOnly: false),
      ]);

      return BookingsView.join(
        results[0] as List<Booking>,
        results[1] as List<Service>,
      );
    })..addListener(_chooseOpeningTab);
  }

  /// Lands the customer on a tab with something in it, rather than on an
  /// empty "Active" when everything they have is finished.
  void _chooseOpeningTab() {
    final view = _view?.state.valueOrNull;

    if (_hasChosenOpeningTab || view == null || view.isEmpty) {
      return;
    }
    _hasChosenOpeningTab = true;
    _tabs.index = view.openingBucket.index;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _view
      ?..removeListener(_chooseOpeningTab)
      ..dispose();
    super.dispose();
  }

  /// Loads the list, and reloads it every later time the tab is opened.
  ///
  /// The tabs live in an IndexedStack, so this screen is built once and kept.
  /// Without this, a booking created a moment ago would not appear until the
  /// app restarted.
  Future<void> refresh() async {
    final view = _view;
    if (view == null) {
      return;
    }
    if (!_requested) {
      setState(() => _requested = true);
    }
    await (view.state.valueOrNull == null ? view.load() : view.refresh());
  }

  Future<void> _open(Booking booking, String serviceName) async {
    await Navigator.of(context).push(
      AppRouter.bookingTracking(
        bookingId: booking.id,
        serviceName: serviceName,
        initial: booking,
      ),
    );
    // The status may have moved, or the booking been cancelled, while open.
    await _view?.refresh();
  }

  Future<void> _cancel(Booking booking, String serviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          '$serviceName will be called off. You can book it again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    final bookings = AppServicesScope.of(context).bookings;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyId = booking.id);

    try {
      await bookings.cancel(booking.id);
    } on ApiException catch (error) {
      // The server decides. A 409 means the booking moved past the point
      // where cancelling is allowed while the dialog was open.
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      await _view?.refresh();
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_requested) {
      return const SizedBox.shrink();
    }
    final controller = _view!;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final view = controller.state.valueOrNull;

        return Column(
          children: [
            if (view != null && !view.isEmpty) _Tabs(tabs: _tabs, view: view),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.red,
                onRefresh: controller.refresh,
                child: AsyncView<BookingsView>(
                  state: controller.state,
                  onRetry: controller.load,
                  loadingLabel: 'Loading your bookings',
                  isEmpty: (view) => view.isEmpty,
                  empty: const AppEmptyView(
                    title: 'No bookings yet',
                    message:
                        'Pick a service from Home and your bookings will show '
                        'up here.',
                    icon: Icons.receipt_long_rounded,
                  ),
                  builder: (context, view) => TabBarView(
                    controller: _tabs,
                    children: [
                      for (final bucket in BookingBucket.values)
                        _BucketList(
                          bucket: bucket,
                          view: view,
                          busyId: _busyId,
                          onOpen: _open,
                          onCancel: _cancel,
                          onRefresh: controller.refresh,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs, required this.view});

  final TabController tabs;
  final BookingsView view;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: TabBar(
        controller: tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppTheme.red,
        unselectedLabelColor: AppTheme.muted,
        indicatorColor: AppTheme.red,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        tabs: [
          for (final bucket in BookingBucket.values)
            Tab(
              // The count is worth showing: it is how a customer sees at a
              // glance that the tab they want is not the one they are on.
              text: view.countIn(bucket) == 0
                  ? bucket.label
                  : '${bucket.label} (${view.countIn(bucket)})',
            ),
        ],
      ),
    );
  }
}

class _BucketList extends StatelessWidget {
  const _BucketList({
    required this.bucket,
    required this.view,
    required this.busyId,
    required this.onOpen,
    required this.onCancel,
    required this.onRefresh,
  });

  final BookingBucket bucket;
  final BookingsView view;
  final String? busyId;
  final void Function(Booking booking, String serviceName) onOpen;
  final void Function(Booking booking, String serviceName) onCancel;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final bookings = view.inBucket(bucket);
    final empty = bucket.emptyState;

    // Each tab refreshes the one list behind all four, so the gesture works
    // wherever the customer happens to be.
    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: onRefresh,
      child: bookings.isEmpty
          ? _ScrollableEmpty(title: empty.title, message: empty.message)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final name = view.nameFor(booking);

                return BookingCard(
                  booking: booking,
                  serviceName: name,
                  isBusy: busyId == booking.id,
                  onTap: () => onOpen(booking, name),
                  onCancel: booking.status.isCancellable
                      ? () => onCancel(booking, name)
                      : null,
                );
              },
            ),
    );
  }
}

/// An empty tab still has to scroll, or pull-to-refresh cannot fire on it.
class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: AppEmptyView(
              title: title,
              message: message,
              icon: Icons.receipt_long_rounded,
            ),
          ),
        );
      },
    );
  }
}
