import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:dio/dio.dart';

/// Bridges a domain [LlmCancelToken] to a dio [CancelToken] so cancelling the
/// former aborts the underlying HTTP request. Returns `null` when no token was
/// supplied (the non-cancellable path). If the token is already cancelled the
/// returned dio token starts cancelled, so the request is rejected immediately.
CancelToken? bindLlmCancelToken(LlmCancelToken? cancelToken) {
  if (cancelToken == null) return null;
  final dioToken = CancelToken();
  if (cancelToken.isCancelled) {
    dioToken.cancel();
  } else {
    cancelToken.whenCancelled.then((_) {
      if (!dioToken.isCancelled) dioToken.cancel();
    });
  }
  return dioToken;
}
