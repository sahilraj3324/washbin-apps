import 'package:washbinapp/core/api/api_exception.dart';

/// Where an asynchronous read has got to.
///
/// A screen switches over this once instead of juggling three nullable fields,
/// which is how "loading spinner over stale data" and "error with the previous
/// list still on screen" bugs get written.
sealed class AsyncState<T> {
  const AsyncState();

  /// The value, if one has ever been loaded. Non-null during a refresh, so a
  /// pull-to-refresh can keep showing the old list while the new one arrives.
  T? get valueOrNull => switch (this) {
    AsyncData<T>(:final value) => value,
    AsyncRefreshing<T>(:final value) => value,
    _ => null,
  };

  bool get isLoading => this is AsyncLoading<T> || this is AsyncRefreshing<T>;
}

/// Nothing has been loaded yet — the screen has no content to show.
final class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();
}

/// Loaded.
final class AsyncData<T> extends AsyncState<T> {
  const AsyncData(this.value);

  final T value;
}

/// Loaded once, and being loaded again. The previous value stays on screen.
final class AsyncRefreshing<T> extends AsyncState<T> {
  const AsyncRefreshing(this.value);

  final T value;
}

/// The read failed and there is nothing to show.
final class AsyncFailure<T> extends AsyncState<T> {
  const AsyncFailure(this.error);

  final ApiException error;
}
