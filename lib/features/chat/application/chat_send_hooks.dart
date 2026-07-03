import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_send_hooks.g.dart';

/// 拦截器：返回 true 表示本次发送已被消费（不再走常规模型回复流程）。
typedef ChatSendInterceptor = Future<bool> Function(String text);

/// 用户发送拦截缝：其它 feature（经 `app/di` 组合）可临时接管输入框的
/// 纯文本发送——目前用于 AI 辩论进行中的「用户插话」。
@Riverpod(keepAlive: true)
class ChatSendInterceptorHolder extends _$ChatSendInterceptorHolder {
  @override
  ChatSendInterceptor? build() => null;

  void set(ChatSendInterceptor? interceptor) => state = interceptor;
}
