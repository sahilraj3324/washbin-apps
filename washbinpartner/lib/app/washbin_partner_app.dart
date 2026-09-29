import 'package:flutter/material.dart';
import 'package:washbinpartner/app/app_gate.dart';
import 'package:washbinpartner/app/app_services.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';

/// The root widget: build the object graph, put it in the tree, start the
/// session, and let [AppGate] decide what the partner sees.
class WashbinPartnerApp extends StatefulWidget {
  const WashbinPartnerApp({super.key, this.services});

  /// Supplied by tests to swap in a scripted HTTP client and a Firebase
  /// stand-in. Production builds construct their own.
  final AppServices? services;

  @override
  State<WashbinPartnerApp> createState() => _WashbinPartnerAppState();
}

class _WashbinPartnerAppState extends State<WashbinPartnerApp> {
  late final AppServices _services = widget.services ?? AppServices();

  /// True when this widget built the graph and is therefore responsible for
  /// tearing it down; a caller that passed one in owns its own lifecycle.
  late final bool _ownsServices = widget.services == null;

  @override
  void initState() {
    super.initState();
    _services.session.start();
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
          title: 'Washbin Partner',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const AppGate(),
        ),
      ),
    );
  }
}
