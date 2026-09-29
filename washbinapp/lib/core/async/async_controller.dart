import 'package:flutter/foundation.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/async/async_state.dart';

/// Loads one thing and reports where it got to.
///
/// Screens own an instance per read rather than calling a repository from
/// `build`, which is what makes pull-to-refresh, retry and "keep the old list
/// visible while refreshing" the same few lines everywhere.
class AsyncController<T> extends ChangeNotifier {
  AsyncController(this._read, {T? initialValue})
    : _state = initialValue == null
          ? AsyncLoading<T>()
          : AsyncData<T>(initialValue);

  final Future<T> Function() _read;

  AsyncState<T> _state;
  AsyncState<T> get state => _state;

  /// Set when a refresh failed but the previous content was kept, so a screen
  /// can mention it without throwing away a list that was fine a moment ago.
  ApiException? _refreshFailure;
  ApiException? get refreshFailure => _refreshFailure;

  /// Guards against a slow first load landing after a refresh that started
  /// later, which would put stale content back on screen.
  int _generation = 0;
  bool _disposed = false;

  /// First load: a spinner stands in for the content.
  Future<void> load() => _run(keepValue: false);

  /// Reload asked for by the customer. Keeps what is already on screen, and
  /// leaves it there if the reload fails.
  Future<void> refresh() => _run(keepValue: true);

  Future<void> _run({required bool keepValue}) async {
    final previous = _state.valueOrNull;
    final keep = keepValue && previous != null;
    final generation = ++_generation;

    _refreshFailure = null;
    _emit(keep ? AsyncRefreshing<T>(previous) : AsyncLoading<T>());

    try {
      final result = await _read();
      if (generation == _generation) {
        _emit(AsyncData<T>(result));
      }
    } on ApiException catch (error) {
      if (generation != _generation) {
        return;
      }
      if (keep) {
        _refreshFailure = error;
        _emit(AsyncData<T>(previous));
      } else {
        _emit(AsyncFailure<T>(error));
      }
    }
  }

  void acknowledgeRefreshFailure() => _refreshFailure = null;

  /// Replaces the loaded value without a round trip.
  ///
  /// For changes the screen has already made and the server has merely been
  /// told about — marking a notification read, say — where waiting for a
  /// refresh would make the tap feel broken.
  void setValue(T value) => _emit(AsyncData<T>(value));

  void _emit(AsyncState<T> state) {
    if (_disposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
