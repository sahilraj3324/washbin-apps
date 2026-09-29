import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_gate.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';

/// The root widget: build the object graph, put it in the tree, start the
/// session, and let [AppGate] decide what the customer sees.
class WashbinApp extends StatefulWidget {
  const WashbinApp({super.key, this.services});

  /// Supplied by tests to swap in a scripted HTTP client and a Firebase
  /// stand-in. Production builds construct their own.
  final AppServices? services;

  @override
  State<WashbinApp> createState() => _WashbinAppState();
}

class _WashbinAppState extends State<WashbinApp> {
  late final AppServices _services = widget.services ?? AppServices();

  /// True when this widget built the graph and is therefore responsible for
  /// tearing it down; a caller that passed one in owns its own lifecycle.
  late final bool _ownsServices = widget.services == null;

  /// Scoped to the whole app so an in-app banner can be shown from a push
  /// handler, which has no BuildContext of its own.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _services.push
      ..onOpenBooking = _openBooking
      ..onForeground = _showBanner;
    _services.session.start();
  }

  /// A tapped notification opens the booking — and the booking screen re-reads
  /// it from the server. The push payload says which booking, never what state
  /// it is in, so one that sat in the tray for an hour cannot mislead.
  void _openBooking(PushPayload payload) {
    final bookingId = payload.bookingId;
    final navigator = _services.signedInNavigatorKey.currentState;

    // Null while signed out, which is exactly when a booking must not open.
    if (bookingId == null || navigator == null) {
      return;
    }

    navigator.push(AppRouter.bookingTracking(bookingId: bookingId));
  }

  /// The system tray stays silent while the app is open, so the app says it.
  void _showBanner(PushPayload payload) {
    final title = payload.title;
    final body = payload.body;

    if (title == null && body == null) {
      return;
    }

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (body != null) Text(body),
          ],
        ),
        action: payload.opensBooking
            ? SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => _openBooking(payload),
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsServices) {
      _services.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: _services,
      child: SessionScope(
        controller: _services.session,
        child: MaterialApp(
          title: 'Washbin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          scaffoldMessengerKey: _messengerKey,
          home: const AppGate(),
        ),
      ),
    );
  }
}
