/// Provider icon mapping – 1:1 port of `src/shared/utils/providerIcons.ts`.
///
/// Maps provider IDs and model-name patterns to bundled asset paths so
/// the model selector can show the correct logo for every vendor.
library;

const _base = 'assets/images/provider_icons';

const _dark = <String, String>{
  'gemini': '$_base/dark/google.png',
  'grok': '$_base/dark/grok.png',
  'deepseek': '$_base/dark/deepseek.png',
  'doubao': '$_base/dark/doubao.png',
  'moonshot': '$_base/dark/moonshot.png',
  'jina': '$_base/dark/jina.png',
  'hunyuan': '$_base/dark/hunyuan.png',
  'mistral': '$_base/dark/mistral.png',
  'minimax': '$_base/dark/minimax.png',
  'yi': '$_base/dark/yi.png',
  'baichuan': '$_base/dark/baichuan.png',
  'nvidia': '$_base/dark/nvidia.png',
  'perplexity': '$_base/dark/perplexity.png',
  'cherryin': '$_base/dark/cherryIn.png',
  'silicon': '$_base/dark/silicon.png',
  'siliconflow': '$_base/dark/silicon.png',
  'aihubmix': '$_base/dark/aihubmix.png',
  'ocoolai': '$_base/dark/ocoolai.png',
  'ppio': '$_base/dark/ppio.png',
  'alayanew': '$_base/dark/alayanew.png',
  'qiniu': '$_base/dark/qiniu.png',
  'dmxapi': '$_base/dark/dmxapi.png',
  'burncloud': '$_base/dark/burncloud.png',
  'tokenflux': '$_base/dark/tokenflux.png',
  '302ai': '$_base/dark/302ai.png',
  'cephalon': '$_base/dark/cephalon.png',
  'lanyun': '$_base/dark/lanyun.png',
  'ph8': '$_base/dark/ph8.png',
  'openrouter': '$_base/dark/openrouter.png',
  'ollama': '$_base/dark/ollama.png',
  'new-api': '$_base/dark/newapi.png',
  'lmstudio': '$_base/dark/lmstudio.png',
  'anthropic': '$_base/dark/anthropic.png',
  'openai': '$_base/dark/openai.png',
  'openai-aisdk': '$_base/dark/openai.png',
  'azure-openai': '$_base/dark/azure.png',
  'github': '$_base/dark/github.png',
  'copilot': '$_base/dark/githubcopilot.png',
  'zhipu': '$_base/dark/zhipu.png',
  'dashscope': '$_base/dark/dashscope.png',
  'stepfun': '$_base/dark/stepfun.png',
  'infini': '$_base/dark/infini.png',
  'groq': '$_base/dark/groq.png',
  'together': '$_base/dark/together.png',
  'fireworks': '$_base/dark/fireworks.png',
  'hyperbolic': '$_base/dark/hyperbolic.png',
  'modelscope': '$_base/dark/modelscope.png',
  'xirang': '$_base/dark/xirang.png',
  'tencent-cloud-ti': '$_base/dark/hunyuan.png',
  'baidu-cloud': '$_base/dark/baidu.png',
  'gpustack': '$_base/dark/gpustack.png',
  'voyageai': '$_base/dark/voyage.png',
  'aws-bedrock': '$_base/dark/bedrock.png',
  'poe': '$_base/dark/poe.png',
  'google': '$_base/dark/google.png',
  'volcengine': '$_base/dark/doubao.png',
  'model-combo': '$_base/dark/openai.png',
  'custom': '$_base/dark/openai.png',
};

const _light = <String, String>{
  'gemini': '$_base/light/google.png',
  'grok': '$_base/light/grok.png',
  'deepseek': '$_base/light/deepseek.png',
  'doubao': '$_base/light/doubao.png',
  'moonshot': '$_base/light/moonshot.png',
  'jina': '$_base/light/jina.png',
  'hunyuan': '$_base/light/hunyuan.png',
  'mistral': '$_base/light/mistral.png',
  'minimax': '$_base/light/minimax.png',
  'yi': '$_base/light/yi.png',
  'baichuan': '$_base/light/baichuan.png',
  'nvidia': '$_base/light/nvidia.png',
  'perplexity': '$_base/light/perplexity.png',
  'cherryin': '$_base/light/cherryIn.png',
  'silicon': '$_base/light/silicon.png',
  'siliconflow': '$_base/light/silicon.png',
  'aihubmix': '$_base/light/aihubmix.png',
  'ocoolai': '$_base/light/ocoolai.png',
  'ppio': '$_base/light/ppio.png',
  'alayanew': '$_base/light/alayanew.png',
  'qiniu': '$_base/light/qiniu.png',
  'dmxapi': '$_base/light/dmxapi.png',
  'burncloud': '$_base/light/burncloud.png',
  'tokenflux': '$_base/light/tokenflux.png',
  '302ai': '$_base/light/302ai.png',
  'cephalon': '$_base/light/cephalon.png',
  'lanyun': '$_base/light/lanyun.png',
  'ph8': '$_base/light/ph8.png',
  'openrouter': '$_base/light/openrouter.png',
  'ollama': '$_base/light/ollama.png',
  'new-api': '$_base/light/newapi.png',
  'lmstudio': '$_base/light/lmstudio.png',
  'anthropic': '$_base/light/anthropic.png',
  'openai': '$_base/light/openai.png',
  'openai-aisdk': '$_base/light/openai.png',
  'azure-openai': '$_base/light/azure.png',
  'github': '$_base/light/github.png',
  'copilot': '$_base/light/githubcopilot.png',
  'zhipu': '$_base/light/zhipu.png',
  'dashscope': '$_base/light/dashscope.png',
  'stepfun': '$_base/light/stepfun.png',
  'infini': '$_base/light/infini.png',
  'groq': '$_base/light/groq.png',
  'together': '$_base/light/together.png',
  'fireworks': '$_base/light/fireworks.png',
  'hyperbolic': '$_base/light/hyperbolic.png',
  'modelscope': '$_base/light/modelscope.png',
  'xirang': '$_base/light/xirang.png',
  'tencent-cloud-ti': '$_base/light/hunyuan.png',
  'baidu-cloud': '$_base/light/baidu.png',
  'gpustack': '$_base/light/gpustack.png',
  'voyageai': '$_base/light/voyage.png',
  'aws-bedrock': '$_base/light/bedrock.png',
  'poe': '$_base/light/poe.png',
  'google': '$_base/light/google.png',
  'volcengine': '$_base/light/doubao.png',
  'model-combo': '$_base/light/openai.png',
  'custom': '$_base/light/openai.png',
};

const _modelNamePatterns = <String, String>{
  'gpt': 'openai',
  'o1': 'openai',
  'o3': 'openai',
  'chatgpt': 'openai',
  'claude': 'anthropic',
  'gemini': 'google',
  'grok': 'grok',
  'deepseek': 'deepseek',
  'doubao': 'doubao',
  'qwen': 'dashscope',
  'moonshot': 'moonshot',
  'jina': 'jina',
  'hunyuan': 'hunyuan',
  'llama': 'openai',
  'mistral': 'mistral',
  'minimax': 'minimax',
  'yi': 'yi',
  'baichuan': 'baichuan',
  'chatglm': 'zhipu',
  'glm': 'zhipu',
  'perplexity': 'perplexity',
  'sonar': 'perplexity',
};

String getProviderIcon(String providerId, {bool isDark = false}) {
  final icons = isDark ? _dark : _light;
  final normalizedId = providerId.toLowerCase().replaceAll('_', '-');
  return icons[normalizedId] ?? icons['custom']!;
}

String getModelOrProviderIcon(
  String modelId,
  String providerId, {
  bool isDark = false,
}) {
  final lowerModelId = modelId.toLowerCase();
  for (final entry in _modelNamePatterns.entries) {
    if (lowerModelId.contains(entry.key)) {
      return getProviderIcon(entry.value, isDark: isDark);
    }
  }
  return getProviderIcon(providerId, isDark: isDark);
}
