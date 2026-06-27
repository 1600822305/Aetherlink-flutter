import 'dart:async';

/// Cooperative cancellation signal for an in-flight [LlmGateway.streamChat].
///
/// Domain-pure (no dio): adapters bridge it to their transport's native
/// cancellation (e.g. dio's `CancelToken`) so cancelling actually aborts the
/// underlying HTTP request rather than just dropping the consumer. Calling
/// [cancel] completes [whenCancelled] and flips [isCancelled]; it is idempotent.
class LlmCancelToken {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
