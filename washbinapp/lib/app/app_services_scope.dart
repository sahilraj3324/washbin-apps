import 'package:flutter/widgets.dart';
import 'package:washbinapp/app/app_services.dart';

/// Exposes the object graph to the widget tree, so a screen can reach a
/// repository without it being threaded through every constructor above it.
///
/// Repositories are stateless collaborators, not state — anything that
/// *changes* belongs in `SessionScope`, which rebuilds its dependents.
class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<AppServicesScope>()
        ?.widget;
    assert(scope != null, 'No AppServicesScope above this widget');
    return (scope! as AppServicesScope).services;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      services != oldWidget.services;
}
