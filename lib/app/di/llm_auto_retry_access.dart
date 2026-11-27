/// App-level composition seam：聊天发送链路读取「请求失败自动重试」开关
/// （设置页持有），chat 不直接 import settings 的 application 层。
library;

export 'package:aetherlink_flutter/features/settings/application/llm_auto_retry_controller.dart'
    show chatLlmAutoRetryProvider;
