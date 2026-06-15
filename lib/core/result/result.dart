import 'package:aetherlink_flutter/core/error/failure.dart';

/// Lightweight functional result: either a success ([Ok]) or a [Failure]
/// ([Err]).
///
/// Used to model expected failures without throwing across the `data` /
/// `domain` boundary (see `docs/ARCHITECTURE.md`). Pure Dart, no framework
/// dependency, so `domain` may depend on it.
sealed class Result<T> {
  const Result();
}

/// Successful result holding a [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

/// Failed result holding a [failure].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
