import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/remote_image.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// Everything about one service, and the button that will eventually start a
/// booking.
///
/// Opened with the service the list already had, so it draws immediately, and
/// re-reads it in the background — a price or a description can have changed
/// since the list was fetched, and a service can have been taken down.
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.service});

  final Service service;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  AsyncController<Service>? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_service != null) {
      return;
    }
    final repository = AppServicesScope.of(context).catalogue;
    _service = AsyncController(
      () => repository.getService(widget.service.id),
      initialValue: widget.service,
    )..refresh();
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  void _continue(Service service) {
    // Where, before what: the location decides whether this can be booked at
    // all, so it is asked for before anything else about the booking.
    Navigator.of(context).push(AppRouter.chooseLocation(service));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _service!;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          // A failed re-read is not worth an error screen: the service passed
          // in is real, and the customer can still read it.
          final service = controller.state.valueOrNull ?? widget.service;

          return RefreshIndicator(
            color: AppTheme.red,
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 240,
                  backgroundColor: AppTheme.red,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: RemoteImage(
                      url: service.imageUrl ?? service.iconUrl,
                      fallbackIcon: Icons.cleaning_services_rounded,
                      borderRadius: 0,
                      iconSize: 64,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _Details(service: service)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final service = controller.state.valueOrNull ?? widget.service;
          return _ContinueBar(
            service: service,
            onContinue: service.isActive ? () => _continue(service) : null,
          );
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final duration = service.durationLabel;
    final note = service.pricingNote;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!service.isActive) ...[
            const _UnavailableBanner(),
            const SizedBox(height: 18),
          ],
          Text(
            service.name,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          // A Wrap, not a Row: "Estimated time: 2 hrs 30 mins" next to a
          // 24pt price does not fit a narrow phone on one line.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                service.priceLabel,
                style: const TextStyle(
                  color: AppTheme.red,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              if (duration != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Estimated time: $duration',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'About this service',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.description,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.red.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.pause_circle_outline_rounded, color: AppTheme.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This service is not available right now.',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.service, required this.onContinue});

  final Service service;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    service.priceLabel,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    service.durationLabel ?? 'Duration confirmed on booking',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: onContinue,
                child: Text(onContinue == null ? 'Unavailable' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
