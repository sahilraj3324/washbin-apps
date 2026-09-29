import 'package:flutter/widgets.dart';
import 'package:washbinpartner/core/session/session_controller.dart';

/// Puts the session in the widget tree and rebuilds dependents when it moves.
///
/// This is the whole of the app's state management: a [ChangeNotifier] and an
/// [InheritedNotifier]. Both ship with Flutter, so nothing is pulled in for it,
/// and it is the same shape a package like `provider` would wrap — swapping
/// one in later would not change a single call site's meaning.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The session, rebuilding the caller when it changes.
  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget');
    return scope!.notifier!;
  }

  /// The session, *without* subscribing — for callbacks that act on it rather
  /// than render it, such as a button calling `signOut()`.
  static SessionController read(BuildContext context) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<SessionScope>()
        ?.widget;
    assert(scope != null, 'No SessionScope above this widget');
    return (scope! as SessionScope).notifier!;
  }
}
