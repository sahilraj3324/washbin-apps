import 'package:flutter/material.dart';
import 'package:washbinpartner/core/async/async_state.dart';
import 'package:washbinpartner/core/widgets/app_error_view.dart';
import 'package:washbinpartner/core/widgets/app_loading_indicator.dart';
import 'package:washbinpartner/core/widgets/scrollable_message.dart';

/// Renders the four things an asynchronous read can be — loading, empty,
/// failed, loaded — so no screen writes that switch by hand.
///
/// A refresh keeps the previous content on screen rather than replacing it
/// with a spinner; the pull-to-refresh gesture is already showing one.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loadingLabel,
    this.scrollable = true,
  });

  final AsyncState<T> state;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback? onRetry;

  /// Whether a loaded value counts as nothing to show, e.g. an empty list.
  final bool Function(T value)? isEmpty;

  /// Shown instead of [builder] when [isEmpty] says so.
  final Widget? empty;

  final String? loadingLabel;

  /// Wraps the loading, empty and failure states in a scroll view, so a
  /// `RefreshIndicator` above this still fires when there is nothing to scroll.
  /// Turn off when the parent is already a scrollable.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AsyncLoading<T>() => _message(
        AppLoadingIndicator.fullScreen(label: loadingLabel),
      ),
      AsyncFailure<T>(:final error) => _message(
        AppErrorView.fromException(error, onRetry: onRetry),
      ),
      AsyncData<T>(:final value) ||
      AsyncRefreshing<T>(:final value) => _content(context, value),
    };
  }

  Widget _content(BuildContext context, T value) {
    if (isEmpty?.call(value) ?? false) {
      return _message(empty ?? const SizedBox.shrink());
    }
    return builder(context, value);
  }

  Widget _message(Widget child) =>
      scrollable ? ScrollableMessage(child: child) : child;
}
