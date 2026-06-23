// Voice preset catalogs for all TTS engines.
// Ported from the Web version's engine files.

// ---------------------------------------------------------------------------
// Generic types
// ---------------------------------------------------------------------------

class VoicePreset {
  const VoicePreset({
    required this.id,
    required this.name,
    this.description = '',
    this.language = '',
  });
  final String id;
  final String name;
  final String description;
  final String language;
}

class SelectorGroup {
  const SelectorGroup({required this.name, required this.items});
  final String name;
  final List<SelectorItem> items;
}

class SelectorItem {
  const SelectorItem({
    required this.key,
    required this.label,
    this.subLabel = '',
  });
  final String key;
  final String label;
  final String subLabel;
}

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

const kOpenAIModels = <VoicePreset>[
  VoicePreset(
    id: 'gpt-4o-mini-tts',
    name: 'GPT-4o Mini TTS',
    description: '支持 instructions 控制语音风格',
  ),
  VoicePreset(id: 'tts-1', name: 'TTS-1', description: '标准质量，速度快'),
  VoicePreset(id: 'tts-1-hd', name: 'TTS-1-HD', description: '高清质量，更自然'),
];

const kOpenAIVoices = <VoicePreset>[
  VoicePreset(id: 'alloy', name: 'Alloy', description: '中性，平衡'),
  VoicePreset(id: 'ash', name: 'Ash', description: '男性，沉稳'),
  VoicePreset(id: 'ballad', name: 'Ballad', description: '温暖，叙事感'),
  VoicePreset(id: 'coral', name: 'Coral', description: '女性，清晰自然（官方推荐）'),
  VoicePreset(id: 'echo', name: 'Echo', description: '男性，深沉'),
  VoicePreset(id: 'fable', name: 'Fable', description: '英式，优雅'),
  VoicePreset(id: 'nova', name: 'Nova', description: '女性，年轻活泼'),
  VoicePreset(id: 'onyx', name: 'Onyx', description: '男性，深沉有力'),
  VoicePreset(id: 'sage', name: 'Sage', description: '中性，知性'),
  VoicePreset(id: 'shimmer', name: 'Shimmer', description: '女性，温柔'),
  VoicePreset(id: 'verse', name: 'Verse', description: '男性，多样表现力'),
  VoicePreset(id: 'marin', name: 'Marin', description: '女性，最新推荐'),
  VoicePreset(id: 'cedar', name: 'Cedar', description: '男性，最新推荐'),
];

const kOpenAIFormats = <VoicePreset>[
  VoicePreset(id: 'mp3', name: 'MP3', description: '通用格式，兼容性好'),
  VoicePreset(id: 'opus', name: 'Opus', description: '高压缩比，适合网络传输'),
  VoicePreset(id: 'aac', name: 'AAC', description: '高质量，适合移动设备'),
  VoicePreset(id: 'flac', name: 'FLAC', description: '无损压缩，最高质量'),
  VoicePreset(id: 'wav', name: 'WAV', description: '无压缩，最大兼容性'),
  VoicePreset(id: 'pcm', name: 'PCM', description: '原始音频数据'),
];

// ---------------------------------------------------------------------------
// Gemini
// ---------------------------------------------------------------------------

const kGeminiModels = <VoicePreset>[
  VoicePreset(
    id: 'gemini-3.1-flash-tts-preview',
    name: 'Gemini 3.1 Flash TTS',
    description: '最新模型，支持 audio tags 精细控制',
  ),
  VoicePreset(
    id: 'gemini-2.5-flash-preview-tts',
    name: 'Gemini 2.5 Flash TTS',
    description: '快速语音合成',
  ),
  VoicePreset(
    id: 'gemini-2.5-pro-preview-tts',
    name: 'Gemini 2.5 Pro TTS',
    description: '高质量语音合成',
  ),
];

const kGeminiVoices = <VoicePreset>[
  VoicePreset(id: 'Zephyr', name: 'Zephyr', description: 'Bright - 明亮'),
  VoicePreset(id: 'Puck', name: 'Puck', description: 'Upbeat - 乐观'),
  VoicePreset(id: 'Charon', name: 'Charon', description: 'Informative - 信息丰富'),
  VoicePreset(id: 'Kore', name: 'Kore', description: 'Firm - 坚定'),
  VoicePreset(id: 'Fenrir', name: 'Fenrir', description: 'Excitable - 兴奋'),
  VoicePreset(id: 'Leda', name: 'Leda', description: 'Youthful - 年轻'),
  VoicePreset(id: 'Orus', name: 'Orus', description: 'Firm - 坚定'),
  VoicePreset(id: 'Aoede', name: 'Aoede', description: 'Breezy - 轻松'),
  VoicePreset(
    id: 'Callirrhoe',
    name: 'Callirrhoe',
    description: 'Easy-going - 随和',
  ),
  VoicePreset(id: 'Autonoe', name: 'Autonoe', description: 'Bright - 明亮'),
  VoicePreset(id: 'Enceladus', name: 'Enceladus', description: 'Breathy - 气息感'),
  VoicePreset(id: 'Iapetus', name: 'Iapetus', description: 'Clear - 清晰'),
  VoicePreset(id: 'Umbriel', name: 'Umbriel', description: 'Easy-going - 随和'),
  VoicePreset(id: 'Algieba', name: 'Algieba', description: 'Smooth - 流畅'),
  VoicePreset(id: 'Despina', name: 'Despina', description: 'Smooth - 流畅'),
  VoicePreset(id: 'Erinome', name: 'Erinome', description: 'Clear - 清晰'),
  VoicePreset(id: 'Algenib', name: 'Algenib', description: 'Gravelly - 沙哑'),
  VoicePreset(
    id: 'Rasalgethi',
    name: 'Rasalgethi',
    description: 'Informative - 信息丰富',
  ),
  VoicePreset(id: 'Laomedeia', name: 'Laomedeia', description: 'Upbeat - 乐观'),
  VoicePreset(id: 'Achernar', name: 'Achernar', description: 'Soft - 柔和'),
  VoicePreset(id: 'Alnilam', name: 'Alnilam', description: 'Firm - 坚定'),
  VoicePreset(id: 'Schedar', name: 'Schedar', description: 'Even - 平稳'),
  VoicePreset(id: 'Gacrux', name: 'Gacrux', description: 'Mature - 成熟'),
  VoicePreset(
    id: 'Pulcherrima',
    name: 'Pulcherrima',
    description: 'Forward - 直接',
  ),
  VoicePreset(id: 'Achird', name: 'Achird', description: 'Friendly - 友好'),
  VoicePreset(
    id: 'Zubenelgenubi',
    name: 'Zubenelgenubi',
    description: 'Casual - 随意',
  ),
  VoicePreset(
    id: 'Vindemiatrix',
    name: 'Vindemiatrix',
    description: 'Gentle - 温和',
  ),
  VoicePreset(id: 'Sadachbia', name: 'Sadachbia', description: 'Lively - 活泼'),
  VoicePreset(
    id: 'Sadaltager',
    name: 'Sadaltager',
    description: 'Knowledgeable - 博学',
  ),
  VoicePreset(id: 'Sulafat', name: 'Sulafat', description: 'Warm - 温暖'),
];

// ---------------------------------------------------------------------------
// MiniMax
// ---------------------------------------------------------------------------

const kMiniMaxModels = <VoicePreset>[
  VoicePreset(
    id: 'speech-2.8-hd',
    name: 'Speech 2.8 HD',
    description: '最新高清，支持 interjection tags',
  ),
  VoicePreset(
    id: 'speech-2.8-turbo',
    name: 'Speech 2.8 Turbo',
    description: '最新快速，自然流畅',
  ),
  VoicePreset(
    id: 'speech-2.6-hd',
    name: 'Speech 2.6 HD',
    description: '高清，韵律出色/克隆相似度高',
  ),
  VoicePreset(
    id: 'speech-2.6-turbo',
    name: 'Speech 2.6 Turbo',
    description: '快速，支持 40+ 语言',
  ),
  VoicePreset(id: 'speech-02-hd', name: 'Speech 02 HD', description: '旧版高清'),
  VoicePreset(
    id: 'speech-02-turbo',
    name: 'Speech 02 Turbo',
    description: '旧版快速',
  ),
  VoicePreset(id: 'speech-01-hd', name: 'Speech 01 HD', description: '经典高清'),
  VoicePreset(
    id: 'speech-01-turbo',
    name: 'Speech 01 Turbo',
    description: '经典快速',
  ),
];

const kMiniMaxVoices = <VoicePreset>[
  VoicePreset(
    id: 'female-tianmei',
    name: '甜美女声',
    description: '甜美温柔的女性声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'female-shaonv',
    name: '少女',
    description: '年轻活泼的少女声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'female-yujie',
    name: '御姐',
    description: '成熟魅力的女性声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'female-chengshu',
    name: '成熟女声',
    description: '稳重大气的女性声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'male-qn-qingse',
    name: '青涩青年',
    description: '年轻清新的男性声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'male-qn-jingying',
    name: '精英青年',
    description: '专业自信的男性声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'male-qn-badaozongjie',
    name: '霸道总裁',
    description: '低沉有磁性的男性声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'male-qn-daxuesheng',
    name: '大学生',
    description: '朝气蓬勃的男性声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'presenter_male',
    name: '男性主持人',
    description: '专业播音风格男声',
    language: 'zh',
  ),
  VoicePreset(
    id: 'presenter_female',
    name: '女性主持人',
    description: '专业播音风格女声',
    language: 'zh',
  ),
  VoicePreset(
    id: 'Chinese (Mandarin)_Warm_Bestie',
    name: '温暖闺蜜（粤语兼容）',
    description: '支持粤语的温暖女声',
    language: 'yue',
  ),
  VoicePreset(
    id: 'Cantonese_Female_1',
    name: '粤语女声1',
    description: '标准粤语女声',
    language: 'yue',
  ),
  VoicePreset(
    id: 'English_Male_1',
    name: '英语男声',
    description: '标准英语男声',
    language: 'en',
  ),
  VoicePreset(
    id: 'English_Female_1',
    name: '英语女声',
    description: '标准英语女声',
    language: 'en',
  ),
  // 新增：官方系统音色
  VoicePreset(
    id: 'English_expressive_narrator',
    name: 'Expressive Narrator',
    description: '表现力叙述者',
    language: 'en',
  ),
  VoicePreset(
    id: 'English_Graceful_Lady',
    name: 'Graceful Lady',
    description: '优雅女士',
    language: 'en',
  ),
  VoicePreset(
    id: 'English_Insightful_Speaker',
    name: 'Insightful Speaker',
    description: '洞察力演讲者',
    language: 'en',
  ),
  VoicePreset(
    id: 'English_radiant_girl',
    name: 'Radiant Girl',
    description: '阳光女孩',
    language: 'en',
  ),
  VoicePreset(
    id: 'English_Persuasive_Man',
    name: 'Persuasive Man',
    description: '有说服力男声',
    language: 'en',
  ),
  VoicePreset(
    id: 'English_Sweet_Girl',
    name: 'Sweet Girl',
    description: '甜美女孩',
    language: 'en',
  ),
  VoicePreset(
    id: 'English_Lucky_Robot',
    name: 'Lucky Robot',
    description: '幸运机器人',
    language: 'en',
  ),
  VoicePreset(
    id: 'Chinese (Mandarin)_Reliable_Executive',
    name: '稳重高管',
    description: '可靠的男性高管声',
    language: 'zh',
  ),
  VoicePreset(
    id: 'Chinese (Mandarin)_News_Anchor',
    name: '新闻主播',
    description: '专业女主播声',
    language: 'zh',
  ),
  VoicePreset(
    id: 'Chinese (Mandarin)_Lyrical_Voice',
    name: '抒情女声',
    description: '抒情柔美女声',
    language: 'zh',
  ),
  VoicePreset(
    id: 'clever_boy',
    name: '聪明男童',
    description: '机智的男童声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'cute_boy',
    name: '可爱男童',
    description: '可爱的男童声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'lovely_girl',
    name: '萌萌女童',
    description: '可爱甜美的女童声音',
    language: 'zh',
  ),
  VoicePreset(
    id: 'Japanese_IntellectualSenior',
    name: '知性前辈',
    description: '知性的日语前辈声',
    language: 'ja',
  ),
  VoicePreset(
    id: 'Japanese_DecisivePrincess',
    name: '果断公主',
    description: '果断的日语公主声',
    language: 'ja',
  ),
  VoicePreset(
    id: 'Japanese_GentleButler',
    name: '温柔管家',
    description: '温柔的日语管家声',
    language: 'ja',
  ),
  VoicePreset(
    id: 'Japanese_Whisper_Belle',
    name: '低语美人',
    description: '低语的日语美人声',
    language: 'ja',
  ),
  VoicePreset(
    id: 'Japanese_OptimisticYouth',
    name: '乐观少年',
    description: '乐观的日语少年声',
    language: 'ja',
  ),
  VoicePreset(
    id: 'Korean_CalmGentleman',
    name: '沉稳绅士',
    description: '沉稳的韩语绅士声',
    language: 'ko',
  ),
  VoicePreset(
    id: 'Korean_CheerfulBoyfriend',
    name: '阳光男友',
    description: '开朗的韩语男友声',
    language: 'ko',
  ),
  VoicePreset(
    id: 'Korean_SweetGirl',
    name: '甜美女孩',
    description: '甜美的韩语女孩声',
    language: 'ko',
  ),
  VoicePreset(
    id: 'Korean_DecisiveQueen',
    name: '果断女王',
    description: '果断的韩语女王声',
    language: 'ko',
  ),
];

const kMiniMaxEmotions = <VoicePreset>[
  VoicePreset(id: 'neutral', name: '中性', description: '自然平和'),
  VoicePreset(id: 'happy', name: '开心', description: '愉快积极'),
  VoicePreset(id: 'sad', name: '悲伤', description: '忧郁低沉'),
  VoicePreset(id: 'angry', name: '愤怒', description: '激动强烈'),
  VoicePreset(id: 'fearful', name: '恐惧', description: '紧张害怕'),
  VoicePreset(id: 'disgusted', name: '厌恶', description: '不满反感'),
  VoicePreset(id: 'surprised', name: '惊讶', description: '惊奇意外'),
  VoicePreset(id: 'calm', name: '平静', description: '舒缓安宁'),
];

const kMiniMaxLanguageBoost = <VoicePreset>[
  VoicePreset(id: 'auto', name: '自动', description: '自动检测语言'),
  VoicePreset(id: 'Chinese', name: '中文普通话', description: '优化普通话发音'),
  VoicePreset(id: 'Chinese,Yue', name: '粤语', description: '优化粤语发音'),
  VoicePreset(id: 'English', name: '英语', description: '优化英语发音'),
  VoicePreset(id: 'Japanese', name: '日语', description: '优化日语发音'),
  VoicePreset(id: 'Korean', name: '韩语', description: '优化韩语发音'),
  VoicePreset(id: 'Spanish', name: '西班牙语', description: '优化西班牙语发音'),
  VoicePreset(id: 'French', name: '法语', description: '优化法语发音'),
  VoicePreset(id: 'German', name: '德语', description: '优化德语发音'),
  VoicePreset(id: 'Portuguese', name: '葡萄牙语', description: '优化葡萄牙语发音'),
  VoicePreset(id: 'Indonesian', name: '印尼语', description: '优化印尼语发音'),
  VoicePreset(id: 'Thai', name: '泰语', description: '优化泰语发音'),
  VoicePreset(id: 'Vietnamese', name: '越南语', description: '优化越南语发音'),
];

const kMiniMaxAudioFormats = <VoicePreset>[
  VoicePreset(id: 'mp3', name: 'MP3', description: '通用有损格式'),
  VoicePreset(id: 'wav', name: 'WAV', description: '无损格式'),
  VoicePreset(id: 'pcm', name: 'PCM', description: '原始音频数据'),
  VoicePreset(id: 'flac', name: 'FLAC', description: '无损压缩格式'),
  VoicePreset(id: 'opus', name: 'Opus', description: '高效编码格式'),
];

const kMiniMaxSampleRates = <VoicePreset>[
  VoicePreset(id: '8000', name: '8 kHz', description: '电话级别'),
  VoicePreset(id: '16000', name: '16 kHz', description: '语音识别级别'),
  VoicePreset(id: '22050', name: '22.05 kHz', description: '标准语音'),
  VoicePreset(id: '24000', name: '24 kHz', description: '高质量语音'),
  VoicePreset(id: '32000', name: '32 kHz', description: '推荐（默认）'),
  VoicePreset(id: '44100', name: '44.1 kHz', description: 'CD 级别'),
];

// ---------------------------------------------------------------------------
// SiliconFlow
// ---------------------------------------------------------------------------

const kSiliconFlowModels = <VoicePreset>[
  VoicePreset(
    id: 'FunAudioLLM/CosyVoice2-0.5B',
    name: 'CosyVoice2-0.5B',
    description: '多语言语音合成（中/英/日/韩/方言）',
  ),
  VoicePreset(
    id: 'fishaudio/fish-speech-1.5',
    name: 'Fish-Speech-1.5',
    description: '多语言 TTS，DualAR 架构（中/英/日）',
  ),
  VoicePreset(
    id: 'IndexTeam/IndexTTS-2',
    name: 'IndexTTS-2',
    description: 'B站情感语音合成，精确时长控制',
  ),
  VoicePreset(
    id: 'fnlp/MOSS-TTSD-v0.5',
    name: 'MOSS-TTSD-v0.5',
    description: '高表现力双人对话语音',
  ),
];

const _kSiliconFlowPresetVoices = <VoicePreset>[
  VoicePreset(id: 'alex', name: 'Alex', description: '沉稳男声'),
  VoicePreset(id: 'benjamin', name: 'Benjamin', description: '低沉男声'),
  VoicePreset(id: 'charles', name: 'Charles', description: '磁性男声'),
  VoicePreset(id: 'david', name: 'David', description: '欢快男声'),
  VoicePreset(id: 'anna', name: 'Anna', description: '沉稳女声'),
  VoicePreset(id: 'bella', name: 'Bella', description: '激情女声'),
  VoicePreset(id: 'claire', name: 'Claire', description: '温柔女声'),
  VoicePreset(id: 'diana', name: 'Diana', description: '欢快女声'),
];

const kSiliconFlowVoices = <String, List<VoicePreset>>{
  'FunAudioLLM/CosyVoice2-0.5B': _kSiliconFlowPresetVoices,
  'fishaudio/fish-speech-1.5': _kSiliconFlowPresetVoices,
  'IndexTeam/IndexTTS-2': _kSiliconFlowPresetVoices,
  'fnlp/MOSS-TTSD-v0.5': _kSiliconFlowPresetVoices,
};

const kSiliconFlowOutputFormats = <VoicePreset>[
  VoicePreset(id: 'mp3', name: 'MP3', description: '通用有损格式'),
  VoicePreset(id: 'wav', name: 'WAV', description: '无损格式'),
  VoicePreset(id: 'pcm', name: 'PCM', description: '原始 PCM'),
  VoicePreset(id: 'opus', name: 'Opus', description: '高效有损格式'),
];

const kSiliconFlowSampleRates = <VoicePreset>[
  VoicePreset(id: '8000', name: '8kHz', description: '电话质量'),
  VoicePreset(id: '16000', name: '16kHz', description: '语音识别'),
  VoicePreset(id: '24000', name: '24kHz', description: '高清语音'),
  VoicePreset(id: '32000', name: '32kHz', description: '广播质量'),
  VoicePreset(id: '44100', name: '44.1kHz', description: 'CD 质量（默认）'),
  VoicePreset(id: '48000', name: '48kHz', description: 'Opus 专用'),
];

// ---------------------------------------------------------------------------
// Azure
// ---------------------------------------------------------------------------

const kAzureVoices = <VoicePreset>[
  // 中文（普通话）
  VoicePreset(
    id: 'zh-CN-XiaoxiaoNeural',
    name: '晓晓',
    description: '女声·情感丰富',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoxiaoMultilingualNeural',
    name: '晓晓 多语言',
    description: '女声·多语种',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoxiaoDialectsNeural',
    name: '晓晓 方言',
    description: '女声·方言',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunxiNeural',
    name: '云希',
    description: '男声·标准',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunjianNeural',
    name: '云健',
    description: '男声·新闻播报',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunyangNeural',
    name: '云扬',
    description: '男声·专业新闻',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaohanNeural',
    name: '晓涵',
    description: '女声·情感',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaomoNeural',
    name: '晓墨',
    description: '女声·温暖',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoxuanNeural',
    name: '晓萱',
    description: '女声·轻快',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoruiNeural',
    name: '晓蕊',
    description: '女声·老年',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoyiNeural',
    name: '晓伊',
    description: '女声·儿童',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunzeNeural',
    name: '云泽',
    description: '男声·广播',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunfengNeural',
    name: '云枫',
    description: '男声·沉稳',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunhaoNeural',
    name: '云皓',
    description: '男声·广告',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunjieNeural',
    name: '云杰',
    description: '男声·温暖',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaochenNeural',
    name: '晓辰',
    description: '女声·休闲',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaomengNeural',
    name: '晓梦',
    description: '女声·可爱',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoshuangNeural',
    name: '晓双',
    description: '女声·儿童',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoyanNeural',
    name: '晓颜',
    description: '女声·温柔',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-XiaoyouNeural',
    name: '晓悠',
    description: '女声·儿童故事',
    language: 'zh-CN',
  ),
  VoicePreset(
    id: 'zh-CN-YunxiaNeural',
    name: '云夏',
    description: '男声·少年',
    language: 'zh-CN',
  ),
  // 中文（粤语）
  VoicePreset(
    id: 'zh-HK-HiuMaanNeural',
    name: 'HiuMaan',
    description: '粤语女声',
    language: 'zh-HK',
  ),
  VoicePreset(
    id: 'zh-HK-WanLungNeural',
    name: 'WanLung',
    description: '粤语男声',
    language: 'zh-HK',
  ),
  VoicePreset(
    id: 'zh-HK-HiuGaaiNeural',
    name: 'HiuGaai',
    description: '粤语女声2',
    language: 'zh-HK',
  ),
  // 中文（台湾）
  VoicePreset(
    id: 'zh-TW-HsiaoChenNeural',
    name: 'HsiaoChen',
    description: '台湾女声',
    language: 'zh-TW',
  ),
  VoicePreset(
    id: 'zh-TW-YunJheNeural',
    name: 'YunJhe',
    description: '台湾男声',
    language: 'zh-TW',
  ),
  VoicePreset(
    id: 'zh-TW-HsiaoYuNeural',
    name: 'HsiaoYu',
    description: '台湾女声2',
    language: 'zh-TW',
  ),
  // 英文（美国）
  VoicePreset(
    id: 'en-US-JennyNeural',
    name: 'Jenny',
    description: '英文女声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-JennyMultilingualNeural',
    name: 'Jenny 多语言',
    description: '英文女声·多语种',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-GuyNeural',
    name: 'Guy',
    description: '英文男声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-AriaNeural',
    name: 'Aria',
    description: '英文情感女声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-DavisNeural',
    name: 'Davis',
    description: '英文情感男声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-AmberNeural',
    name: 'Amber',
    description: '英文温暖女声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-AnaNeural',
    name: 'Ana',
    description: '英文儿童女声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-AndrewNeural',
    name: 'Andrew',
    description: '英文温暖男声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-EmmaNeural',
    name: 'Emma',
    description: '英文专业女声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-BrianNeural',
    name: 'Brian',
    description: '英文叙事男声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-ChristopherNeural',
    name: 'Christopher',
    description: '英文可靠男声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-EricNeural',
    name: 'Eric',
    description: '英文自然男声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-MichelleNeural',
    name: 'Michelle',
    description: '英文友好女声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-RogerNeural',
    name: 'Roger',
    description: '英文成熟男声',
    language: 'en-US',
  ),
  VoicePreset(
    id: 'en-US-SteffanNeural',
    name: 'Steffan',
    description: '英文自信男声',
    language: 'en-US',
  ),
  // 英文（英国）
  VoicePreset(
    id: 'en-GB-SoniaNeural',
    name: 'Sonia',
    description: '英式女声',
    language: 'en-GB',
  ),
  VoicePreset(
    id: 'en-GB-RyanNeural',
    name: 'Ryan',
    description: '英式男声',
    language: 'en-GB',
  ),
  VoicePreset(
    id: 'en-GB-LibbyNeural',
    name: 'Libby',
    description: '英式女声2',
    language: 'en-GB',
  ),
  VoicePreset(
    id: 'en-GB-MaisieNeural',
    name: 'Maisie',
    description: '英式儿童',
    language: 'en-GB',
  ),
  // 日文
  VoicePreset(
    id: 'ja-JP-NanamiNeural',
    name: 'Nanami',
    description: '日文女声',
    language: 'ja-JP',
  ),
  VoicePreset(
    id: 'ja-JP-KeitaNeural',
    name: 'Keita',
    description: '日文男声',
    language: 'ja-JP',
  ),
  VoicePreset(
    id: 'ja-JP-AoiNeural',
    name: 'Aoi',
    description: '日文女声2',
    language: 'ja-JP',
  ),
  VoicePreset(
    id: 'ja-JP-DaichiNeural',
    name: 'Daichi',
    description: '日文男声2',
    language: 'ja-JP',
  ),
  VoicePreset(
    id: 'ja-JP-MayuNeural',
    name: 'Mayu',
    description: '日文女声3',
    language: 'ja-JP',
  ),
  VoicePreset(
    id: 'ja-JP-NaokiNeural',
    name: 'Naoki',
    description: '日文男声3',
    language: 'ja-JP',
  ),
  VoicePreset(
    id: 'ja-JP-ShioriNeural',
    name: 'Shiori',
    description: '日文女声4',
    language: 'ja-JP',
  ),
  // 韩文
  VoicePreset(
    id: 'ko-KR-SunHiNeural',
    name: 'SunHi',
    description: '韩文女声',
    language: 'ko-KR',
  ),
  VoicePreset(
    id: 'ko-KR-InJoonNeural',
    name: 'InJoon',
    description: '韩文男声',
    language: 'ko-KR',
  ),
  VoicePreset(
    id: 'ko-KR-BongJinNeural',
    name: 'BongJin',
    description: '韩文男声2',
    language: 'ko-KR',
  ),
  VoicePreset(
    id: 'ko-KR-GookMinNeural',
    name: 'GookMin',
    description: '韩文男声3',
    language: 'ko-KR',
  ),
  VoicePreset(
    id: 'ko-KR-JiMinNeural',
    name: 'JiMin',
    description: '韩文女声2',
    language: 'ko-KR',
  ),
  VoicePreset(
    id: 'ko-KR-YuJinNeural',
    name: 'YuJin',
    description: '韩文女声3',
    language: 'ko-KR',
  ),
  // 法语
  VoicePreset(
    id: 'fr-FR-DeniseNeural',
    name: 'Denise',
    description: '法语女声',
    language: 'fr-FR',
  ),
  VoicePreset(
    id: 'fr-FR-HenriNeural',
    name: 'Henri',
    description: '法语男声',
    language: 'fr-FR',
  ),
  // 德语
  VoicePreset(
    id: 'de-DE-KatjaNeural',
    name: 'Katja',
    description: '德语女声',
    language: 'de-DE',
  ),
  VoicePreset(
    id: 'de-DE-ConradNeural',
    name: 'Conrad',
    description: '德语男声',
    language: 'de-DE',
  ),
  // 西班牙语
  VoicePreset(
    id: 'es-ES-ElviraNeural',
    name: 'Elvira',
    description: '西语女声',
    language: 'es-ES',
  ),
  VoicePreset(
    id: 'es-ES-AlvaroNeural',
    name: 'Alvaro',
    description: '西语男声',
    language: 'es-ES',
  ),
  // 葡萄牙语
  VoicePreset(
    id: 'pt-BR-FranciscaNeural',
    name: 'Francisca',
    description: '葡语女声',
    language: 'pt-BR',
  ),
  VoicePreset(
    id: 'pt-BR-AntonioNeural',
    name: 'Antonio',
    description: '葡语男声',
    language: 'pt-BR',
  ),
  // 意大利语
  VoicePreset(
    id: 'it-IT-ElsaNeural',
    name: 'Elsa',
    description: '意语女声',
    language: 'it-IT',
  ),
  VoicePreset(
    id: 'it-IT-DiegoNeural',
    name: 'Diego',
    description: '意语男声',
    language: 'it-IT',
  ),
  // 俄语
  VoicePreset(
    id: 'ru-RU-SvetlanaNeural',
    name: 'Svetlana',
    description: '俄语女声',
    language: 'ru-RU',
  ),
  VoicePreset(
    id: 'ru-RU-DmitryNeural',
    name: 'Dmitry',
    description: '俄语男声',
    language: 'ru-RU',
  ),
  // 阿拉伯语
  VoicePreset(
    id: 'ar-SA-ZariyahNeural',
    name: 'Zariyah',
    description: '阿拉伯女声',
    language: 'ar-SA',
  ),
  VoicePreset(
    id: 'ar-SA-HamedNeural',
    name: 'Hamed',
    description: '阿拉伯男声',
    language: 'ar-SA',
  ),
  // 印地语
  VoicePreset(
    id: 'hi-IN-SwaraNeural',
    name: 'Swara',
    description: '印地女声',
    language: 'hi-IN',
  ),
  VoicePreset(
    id: 'hi-IN-MadhurNeural',
    name: 'Madhur',
    description: '印地男声',
    language: 'hi-IN',
  ),
  // 泰语
  VoicePreset(
    id: 'th-TH-PremwadeeNeural',
    name: 'Premwadee',
    description: '泰语女声',
    language: 'th-TH',
  ),
  VoicePreset(
    id: 'th-TH-NiwatNeural',
    name: 'Niwat',
    description: '泰语男声',
    language: 'th-TH',
  ),
  // 越南语
  VoicePreset(
    id: 'vi-VN-HoaiMyNeural',
    name: 'HoaiMy',
    description: '越南女声',
    language: 'vi-VN',
  ),
  VoicePreset(
    id: 'vi-VN-NamMinhNeural',
    name: 'NamMinh',
    description: '越南男声',
    language: 'vi-VN',
  ),
];

const kAzureOutputFormats = <VoicePreset>[
  // MP3
  VoicePreset(
    id: 'audio-48khz-192kbitrate-mono-mp3',
    name: 'MP3 48kHz 192k',
    description: '最高质量',
  ),
  VoicePreset(
    id: 'audio-48khz-96kbitrate-mono-mp3',
    name: 'MP3 48kHz 96k',
    description: '高质量',
  ),
  VoicePreset(
    id: 'audio-24khz-160kbitrate-mono-mp3',
    name: 'MP3 24kHz 160k',
    description: '高清',
  ),
  VoicePreset(
    id: 'audio-24khz-96kbitrate-mono-mp3',
    name: 'MP3 24kHz 96k',
    description: '标准+',
  ),
  VoicePreset(
    id: 'audio-24khz-48kbitrate-mono-mp3',
    name: 'MP3 24kHz 48k',
    description: '标准',
  ),
  VoicePreset(
    id: 'audio-16khz-128kbitrate-mono-mp3',
    name: 'MP3 16kHz 128k',
    description: '默认',
  ),
  VoicePreset(
    id: 'audio-16khz-64kbitrate-mono-mp3',
    name: 'MP3 16kHz 64k',
    description: '低码率',
  ),
  VoicePreset(
    id: 'audio-16khz-32kbitrate-mono-mp3',
    name: 'MP3 16kHz 32k',
    description: '最低码率',
  ),
  // Opus
  VoicePreset(
    id: 'ogg-48khz-16bit-mono-opus',
    name: 'Opus 48kHz',
    description: '高质量流媒体',
  ),
  VoicePreset(
    id: 'ogg-24khz-16bit-mono-opus',
    name: 'Opus 24kHz',
    description: '标准流媒体',
  ),
  VoicePreset(
    id: 'ogg-16khz-16bit-mono-opus',
    name: 'Opus 16kHz',
    description: '低码率流媒体',
  ),
  // WAV (RIFF)
  VoicePreset(
    id: 'riff-48khz-16bit-mono-pcm',
    name: 'WAV 48kHz',
    description: '无损最高',
  ),
  VoicePreset(
    id: 'riff-24khz-16bit-mono-pcm',
    name: 'WAV 24kHz',
    description: '无损标准',
  ),
  VoicePreset(
    id: 'riff-16khz-16bit-mono-pcm',
    name: 'WAV 16kHz',
    description: '无损低',
  ),
  // Raw PCM
  VoicePreset(
    id: 'raw-48khz-16bit-mono-pcm',
    name: 'PCM 48kHz',
    description: '原始 CD+',
  ),
  VoicePreset(
    id: 'raw-24khz-16bit-mono-pcm',
    name: 'PCM 24kHz',
    description: '原始标准',
  ),
  VoicePreset(
    id: 'raw-16khz-16bit-mono-pcm',
    name: 'PCM 16kHz',
    description: '原始低',
  ),
  // WebM
  VoicePreset(
    id: 'webm-24khz-16bit-mono-opus',
    name: 'WebM 24kHz',
    description: 'WebM 容器',
  ),
  VoicePreset(
    id: 'webm-16khz-16bit-mono-opus',
    name: 'WebM 16kHz',
    description: 'WebM 低',
  ),
];

const kAzureStyles = <VoicePreset>[
  VoicePreset(id: '', name: '无', description: '默认中性'),
  VoicePreset(id: 'cheerful', name: 'Cheerful', description: '开心'),
  VoicePreset(id: 'sad', name: 'Sad', description: '悲伤'),
  VoicePreset(id: 'angry', name: 'Angry', description: '愤怒'),
  VoicePreset(id: 'excited', name: 'Excited', description: '兴奋'),
  VoicePreset(id: 'friendly', name: 'Friendly', description: '友好'),
  VoicePreset(id: 'terrified', name: 'Terrified', description: '恐惧'),
  VoicePreset(id: 'shouting', name: 'Shouting', description: '大喊'),
  VoicePreset(id: 'whispering', name: 'Whispering', description: '耳语'),
  VoicePreset(id: 'hopeful', name: 'Hopeful', description: '满怀期望'),
  VoicePreset(
    id: 'narration-professional',
    name: 'Narration Pro',
    description: '专业旁白',
  ),
  VoicePreset(
    id: 'newscast-casual',
    name: 'Newscast Casual',
    description: '随意新闻',
  ),
  VoicePreset(
    id: 'newscast-formal',
    name: 'Newscast Formal',
    description: '正式新闻',
  ),
  VoicePreset(
    id: 'customerservice',
    name: 'Customer Service',
    description: '客服',
  ),
  VoicePreset(id: 'chat', name: 'Chat', description: '聊天'),
  VoicePreset(id: 'assistant', name: 'Assistant', description: '助手'),
  VoicePreset(id: 'calm', name: 'Calm', description: '平静'),
  VoicePreset(id: 'gentle', name: 'Gentle', description: '温柔'),
  VoicePreset(id: 'serious', name: 'Serious', description: '严肃'),
  VoicePreset(id: 'depressed', name: 'Depressed', description: '沮丧'),
  VoicePreset(id: 'embarrassed', name: 'Embarrassed', description: '尴尬'),
  VoicePreset(id: 'envious', name: 'Envious', description: '嫉妒'),
  VoicePreset(id: 'fearful', name: 'Fearful', description: '害怕'),
  VoicePreset(id: 'affectionate', name: 'Affectionate', description: '深情'),
  VoicePreset(id: 'disgruntled', name: 'Disgruntled', description: '不满'),
  VoicePreset(id: 'lyrical', name: 'Lyrical', description: '抒情'),
  VoicePreset(id: 'poetry-reading', name: 'Poetry Reading', description: '诗朗诵'),
  VoicePreset(
    id: 'advertisement-upbeat',
    name: 'Ad Upbeat',
    description: '广告活力',
  ),
  VoicePreset(id: 'sports-commentary', name: 'Sports', description: '体育解说'),
  VoicePreset(
    id: 'sports-commentary-excited',
    name: 'Sports Excited',
    description: '激动解说',
  ),
  VoicePreset(
    id: 'documentary-narration',
    name: 'Documentary',
    description: '纪录片旁白',
  ),
];

const kAzureRoles = <VoicePreset>[
  VoicePreset(id: '', name: '无', description: '默认'),
  VoicePreset(id: 'Girl', name: 'Girl', description: '模拟女孩'),
  VoicePreset(id: 'Boy', name: 'Boy', description: '模拟男孩'),
  VoicePreset(
    id: 'YoungAdultFemale',
    name: 'Young Adult ♀',
    description: '年轻女性',
  ),
  VoicePreset(id: 'YoungAdultMale', name: 'Young Adult ♂', description: '年轻男性'),
  VoicePreset(
    id: 'OlderAdultFemale',
    name: 'Older Adult ♀',
    description: '中年女性',
  ),
  VoicePreset(id: 'OlderAdultMale', name: 'Older Adult ♂', description: '中年男性'),
  VoicePreset(id: 'SeniorFemale', name: 'Senior ♀', description: '老年女性'),
  VoicePreset(id: 'SeniorMale', name: 'Senior ♂', description: '老年男性'),
];

const kAzureProsodyRates = <VoicePreset>[
  VoicePreset(id: 'x-slow', name: '极慢', description: 'x-slow'),
  VoicePreset(id: 'slow', name: '慢', description: 'slow'),
  VoicePreset(id: 'medium', name: '正常', description: 'medium'),
  VoicePreset(id: 'fast', name: '快', description: 'fast'),
  VoicePreset(id: 'x-fast', name: '极快', description: 'x-fast'),
];

const kAzureProsodyPitches = <VoicePreset>[
  VoicePreset(id: 'x-low', name: '极低', description: 'x-low'),
  VoicePreset(id: 'low', name: '低', description: 'low'),
  VoicePreset(id: 'medium', name: '正常', description: 'medium'),
  VoicePreset(id: 'high', name: '高', description: 'high'),
  VoicePreset(id: 'x-high', name: '极高', description: 'x-high'),
];

const kAzureProsodyVolumes = <VoicePreset>[
  VoicePreset(id: 'silent', name: '静音', description: 'silent'),
  VoicePreset(id: 'x-soft', name: '极轻', description: 'x-soft'),
  VoicePreset(id: 'soft', name: '轻', description: 'soft'),
  VoicePreset(id: 'medium', name: '正常', description: 'medium'),
  VoicePreset(id: 'loud', name: '响', description: 'loud'),
  VoicePreset(id: 'x-loud', name: '极响', description: 'x-loud'),
];

// ---------------------------------------------------------------------------
// ElevenLabs
// ---------------------------------------------------------------------------

const kElevenLabsVoices = <VoicePreset>[
  VoicePreset(
    id: 'JBFqnCBsd6RMkjVDRZzb',
    name: 'George',
    description: '温暖的英式男声',
  ),
  VoicePreset(id: 'EXAVITQu4vr4xnSDxMaL', name: 'Bella', description: '柔和的女声'),
  VoicePreset(id: 'TX3LPaxmHKxFdv7VOQHJ', name: 'Liam', description: '专业的男性旁白'),
  VoicePreset(id: 'pFZP5JQG7iQjIQuC4Bku', name: 'Lily', description: '亲切的女声'),
  VoicePreset(
    id: 'onwK4e9ZLuTAKqWW03F9',
    name: 'Daniel',
    description: '深沉的英式男声',
  ),
  VoicePreset(id: 'N2lVS1w4EtoT3dr4eOWO', name: 'Callum', description: '年轻的男声'),
  VoicePreset(
    id: 'XB0fDUnXU5powFXDhCwa',
    name: 'Charlotte',
    description: '优雅的女声',
  ),
  VoicePreset(id: 'Xb7hH8MSUJpSbSDYk0k2', name: 'Alice', description: '成熟的女声'),
  VoicePreset(
    id: 'iP95p4xoKVk53GoZ742B',
    name: 'Chris',
    description: '亲切的男性声音',
  ),
  VoicePreset(
    id: 'cgSgspJ2msm6clMCkdW9',
    name: 'Jessica',
    description: '活泼的女声',
  ),
];

const kElevenLabsModels = <VoicePreset>[
  VoicePreset(id: 'eleven_v3', name: 'v3', description: '最新旗舰模型，最高音质'),
  VoicePreset(
    id: 'eleven_multilingual_v2',
    name: 'Multilingual v2',
    description: '多语言高质量模型',
  ),
  VoicePreset(
    id: 'eleven_turbo_v2_5',
    name: 'Turbo v2.5',
    description: '低延迟优化模型',
  ),
  VoicePreset(
    id: 'eleven_flash_v2_5',
    name: 'Flash v2.5',
    description: '超低延迟 75ms',
  ),
  VoicePreset(
    id: 'eleven_monolingual_v1',
    name: 'English v1',
    description: '英语专用模型',
  ),
];

const kElevenLabsOutputFormats = <VoicePreset>[
  // MP3
  VoicePreset(
    id: 'mp3_44100_192',
    name: 'MP3 44.1kHz 192k',
    description: '最高质量',
  ),
  VoicePreset(
    id: 'mp3_44100_128',
    name: 'MP3 44.1kHz 128k',
    description: '高质量（默认）',
  ),
  VoicePreset(id: 'mp3_44100_96', name: 'MP3 44.1kHz 96k', description: '标准+'),
  VoicePreset(id: 'mp3_44100_64', name: 'MP3 44.1kHz 64k', description: '标准'),
  VoicePreset(id: 'mp3_44100_32', name: 'MP3 44.1kHz 32k', description: '低码率'),
  VoicePreset(id: 'mp3_22050_32', name: 'MP3 22.05kHz 32k', description: '低带宽'),
  VoicePreset(id: 'mp3_24000_48', name: 'MP3 24kHz 48k', description: '中等'),
  // PCM
  VoicePreset(id: 'pcm_44100', name: 'PCM 44.1kHz', description: 'CD 质量'),
  VoicePreset(id: 'pcm_24000', name: 'PCM 24kHz', description: '高清语音'),
  VoicePreset(id: 'pcm_22050', name: 'PCM 22.05kHz', description: '标准'),
  VoicePreset(id: 'pcm_16000', name: 'PCM 16kHz', description: '语音识别'),
  // Opus
  VoicePreset(
    id: 'opus_48000_128',
    name: 'Opus 48kHz 128k',
    description: '高质量流媒体',
  ),
  VoicePreset(
    id: 'opus_48000_64',
    name: 'Opus 48kHz 64k',
    description: '标准流媒体',
  ),
  VoicePreset(
    id: 'opus_48000_32',
    name: 'Opus 48kHz 32k',
    description: '低码率流媒体',
  ),
  // WAV
  VoicePreset(id: 'wav_44100', name: 'WAV 44.1kHz', description: '无损 CD 质量'),
  // Telephony
  VoicePreset(id: 'ulaw_8000', name: 'μ-law 8kHz', description: '电话（北美）'),
  VoicePreset(id: 'alaw_8000', name: 'A-law 8kHz', description: '电话（欧洲）'),
];

// ---------------------------------------------------------------------------
// Volcano — voice name → voice_type mapping
// ---------------------------------------------------------------------------

const kVolcanoVoices = <String, String>{
  // ========== 通用场景 ==========
  '灿灿2.0': 'BV700_V2_streaming',
  '灿灿': 'BV700_streaming',
  '炀炀': 'BV705_streaming',
  '擎苍2.0': 'BV701_V2_streaming',
  '擎苍': 'BV701_streaming',
  '通用女声2.0': 'BV001_V2_streaming',
  '通用女声': 'BV001_streaming',
  '通用男声': 'BV002_streaming',
  '超自然音色-梓梓2.0': 'BV406_V2_streaming',
  '超自然音色-梓梓': 'BV406_streaming',
  '超自然音色-燃燃2.0': 'BV407_V2_streaming',
  '超自然音色-燃燃': 'BV407_streaming',
  // ========== 有声阅读 ==========
  '阳光青年': 'BV123_streaming',
  '反卷青年': 'BV120_streaming',
  '通用赘婿': 'BV119_streaming',
  '古风少御': 'BV115_streaming',
  '霸气青叔': 'BV107_streaming',
  '质朴青年': 'BV100_streaming',
  '温柔淑女': 'BV104_streaming',
  '开朗青年': 'BV004_streaming',
  '甜宠少御': 'BV113_streaming',
  '儒雅青年': 'BV102_streaming',
  // ========== 智能助手 ==========
  '甜美小源': 'BV405_streaming',
  '亲切女声': 'BV007_streaming',
  '知性女声': 'BV009_streaming',
  '诚诚': 'BV419_streaming',
  '童童': 'BV415_streaming',
  '亲切男声': 'BV008_streaming',
  // ========== 视频配音 ==========
  '译制片男声': 'BV408_streaming',
  '懒小羊': 'BV426_streaming',
  '清新文艺女声': 'BV428_streaming',
  '鸡汤女声': 'BV403_streaming',
  '智慧老者': 'BV158_streaming',
  '慈爱姥姥': 'BV157_streaming',
  '说唱小哥': 'BR001_streaming',
  '活力解说男': 'BV410_streaming',
  '影视解说小帅': 'BV411_streaming',
  '解说小帅-多情感': 'BV437_streaming',
  '影视解说小美': 'BV412_streaming',
  '纨绔青年': 'BV159_streaming',
  '直播一姐': 'BV418_streaming',
  '沉稳解说男': 'BV142_streaming',
  '潇洒青年': 'BV143_streaming',
  '阳光男声': 'BV056_streaming',
  '活泼女声': 'BV005_streaming',
  '小萝莉': 'BV064_streaming',
  // ========== 特色音色 ==========
  '奶气萌娃': 'BV051_streaming',
  '动漫海绵': 'BV063_streaming',
  '动漫海星': 'BV417_streaming',
  '动漫小新': 'BV050_streaming',
  '天才童声': 'BV061_streaming',
  // ========== 广告配音 ==========
  '促销男声': 'BV401_streaming',
  '促销女声': 'BV402_streaming',
  '磁性男声': 'BV006_streaming',
  // ========== 新闻播报 ==========
  '新闻女声': 'BV011_streaming',
  '新闻男声': 'BV012_streaming',
  // ========== 教育场景 ==========
  '知性姐姐-双语': 'BV034_streaming',
  '温柔小哥': 'BV033_streaming',
  // ========== 方言 ==========
  '东北老铁': 'BV021_streaming',
  '东北丫头': 'BV020_streaming',
  '西安佟掌柜': 'BV210_streaming',
  '沪上阿姐': 'BV217_streaming',
  '广西表哥': 'BV213_streaming',
  '甜美台妹': 'BV025_streaming',
  '台普男声': 'BV227_streaming',
  '港剧男神': 'BV026_streaming',
  '广东女仔': 'BV424_streaming',
  '相声演员': 'BV212_streaming',
  '重庆小伙': 'BV019_streaming',
  '四川甜妹儿': 'BV221_streaming',
  '重庆幺妹儿': 'BV423_streaming',
  '乡村企业家': 'BV214_streaming',
  '湖南妹坨': 'BV226_streaming',
  '长沙靓女': 'BV216_streaming',
  '方言灿灿': 'BV704_streaming',
  // ========== 美式英语 ==========
  '慵懒女声-Ava': 'BV511_streaming',
  '议论女声-Alicia': 'BV505_streaming',
  '情感女声-Lawrence': 'BV138_streaming',
  '美式女声-Amelia': 'BV027_streaming',
  '讲述女声-Amanda': 'BV502_streaming',
  '活力女声-Ariana': 'BV503_streaming',
  '活力男声-Jackson': 'BV504_streaming',
  '天才少女': 'BV421_streaming',
  'Stefan': 'BV702_streaming',
  '天真萌娃-Lily': 'BV506_streaming',
  // ========== 英式英语 ==========
  '亲切女声-Anna': 'BV040_streaming',
  // ========== 澳洲英语 ==========
  '澳洲男声-Henry': 'BV516_streaming',
  // ========== 日语 ==========
  '元气少女': 'BV520_streaming',
  '萌系少女': 'BV521_streaming',
  '气质女声': 'BV522_streaming',
  '日语男声': 'BV524_streaming',
  // ========== 葡萄牙语 ==========
  '活力男声-Carlos': 'BV531_streaming',
  '活力女声-葡语': 'BV530_streaming',
  // ========== 西班牙语 ==========
  '气质御姐-西语': 'BV065_streaming',
  // ========== 豆包大模型音色 (bigtts) ==========
  '[豆包]Vivi': 'zh_female_vv_mars_bigtts',
  '[豆包]灿灿': 'zh_female_cancan_mars_bigtts',
  '[豆包]爽快思思': 'zh_female_shuangkuaisisi_moon_bigtts',
  '[豆包]温暖阿虎': 'zh_male_wennuanahu_moon_bigtts',
  '[豆包]少年梓辛': 'zh_male_shaonianzixin_moon_bigtts',
  '[豆包]邻家女孩': 'zh_female_linjianvhai_moon_bigtts',
  '[豆包]渊博小叔': 'zh_male_yuanboxiaoshu_moon_bigtts',
  '[豆包]阳光青年': 'zh_male_yangguangqingnian_moon_bigtts',
  '[豆包]甜美小源': 'zh_female_tianmeixiaoyuan_moon_bigtts',
  '[豆包]清澈梓梓': 'zh_female_qingchezizi_moon_bigtts',
  '[豆包]邻家男孩': 'zh_male_linjiananhai_moon_bigtts',
  '[豆包]甜美悦悦': 'zh_female_tianmeiyueyue_moon_bigtts',
  '[豆包]心灵鸡汤': 'zh_female_xinlingjitang_moon_bigtts',
  '[豆包]解说小明': 'zh_male_jieshuoxiaoming_moon_bigtts',
  '[豆包]开朗姐姐': 'zh_female_kailangjiejie_moon_bigtts',
  '[豆包]亲切女声': 'zh_female_qinqienvsheng_moon_bigtts',
  '[豆包]温柔小雅': 'zh_female_wenrouxiaoya_moon_bigtts',
  '[豆包]快乐小东': 'zh_male_xudong_conversation_wvae_bigtts',
  '[豆包]文静毛毛': 'zh_female_maomao_conversation_wvae_bigtts',
  '[豆包]悠悠君子': 'zh_male_M100_conversation_wvae_bigtts',
  '[豆包]魅力苏菲': 'zh_female_sophie_conversation_wvae_bigtts',
  '[豆包]阳光阿辰': 'zh_male_qingyiyuxuan_mars_bigtts',
  '[豆包]甜美桃子': 'zh_female_tianmeitaozi_mars_bigtts',
  '[豆包]清新女声': 'zh_female_qingxinnvsheng_mars_bigtts',
  '[豆包]知性女声': 'zh_female_zhixingnvsheng_mars_bigtts',
  '[豆包]清爽男大': 'zh_male_qingshuangnanda_mars_bigtts',
  '[豆包]温柔小哥': 'zh_male_wenrouxiaoge_mars_bigtts',
  // 角色扮演
  '[豆包]傲娇霸总': 'zh_male_aojiaobazong_moon_bigtts',
  '[豆包]病娇姐姐': 'ICL_zh_female_bingjiaojiejie_tob',
  '[豆包]妩媚御姐': 'ICL_zh_female_wumeiyujie_tob',
  '[豆包]傲娇女友': 'ICL_zh_female_aojiaonvyou_tob',
  '[豆包]冷酷哥哥': 'ICL_zh_male_lengkugege_v1_tob',
  '[豆包]成熟姐姐': 'ICL_zh_female_chengshujiejie_tob',
  '[豆包]贴心女友': 'ICL_zh_female_tiexinnvyou_tob',
  '[豆包]性感御姐': 'ICL_zh_female_xingganyujie_tob',
  '[豆包]病娇弟弟': 'ICL_zh_male_bingjiaodidi_tob',
  '[豆包]傲慢少爷': 'ICL_zh_male_aomanshaoye_tob',
  '[豆包]腹黑公子': 'ICL_zh_male_fuheigongzi_tob',
  '[豆包]暖心学姐': 'ICL_zh_female_nuanxinxuejie_tob',
  '[豆包]可爱女生': 'ICL_zh_female_keainvsheng_tob',
  '[豆包]知性温婉': 'ICL_zh_female_zhixingwenwan_tob',
  '[豆包]暖心体贴': 'ICL_zh_male_nuanxintitie_tob',
  '[豆包]开朗轻快': 'ICL_zh_male_kailangqingkuai_tob',
  '[豆包]活泼爽朗': 'ICL_zh_male_huoposhuanglang_tob',
  '[豆包]率真小伙': 'ICL_zh_male_shuaizhenxiaohuo_tob',
  '[豆包]温柔文雅': 'ICL_zh_female_wenrouwenya_tob',
  '[豆包]温柔女神': 'ICL_zh_female_wenrounvshen_239eff5e8ffa_tob',
  '[豆包]炀炀': 'ICL_zh_male_BV705_streaming_cs_tob',
  // 视频配音
  '[豆包]擎苍': 'zh_male_qingcang_mars_bigtts',
  '[豆包]霸气青叔': 'zh_male_baqiqingshu_mars_bigtts',
  '[豆包]温柔淑女': 'zh_female_wenroushunv_mars_bigtts',
  '[豆包]儒雅青年': 'zh_male_ruyaqingnian_mars_bigtts',
  '[豆包]悬疑解说': 'zh_male_changtianyi_mars_bigtts',
  '[豆包]古风少御': 'zh_female_gufengshaoyu_mars_bigtts',
  '[豆包]活力小哥': 'zh_male_yangguangqingnian_mars_bigtts',
  '[豆包]鸡汤妹妹': 'zh_female_jitangmeimei_mars_bigtts',
  '[豆包]贴心女声': 'zh_female_tiexinnvsheng_mars_bigtts',
  '[豆包]萌丫头': 'zh_female_mengyatou_mars_bigtts',
  '[豆包]磁性解说男声': 'zh_male_jieshuonansheng_mars_bigtts',
  '[豆包]广告解说': 'zh_male_chunhui_mars_bigtts',
  '[豆包]少儿故事': 'zh_female_shaoergushi_mars_bigtts',
  '[豆包]天才童声': 'zh_male_tiancaitongsheng_mars_bigtts',
  '[豆包]俏皮女声': 'zh_female_qiaopinvsheng_mars_bigtts',
  '[豆包]懒音绵宝': 'zh_male_lanxiaoyang_mars_bigtts',
  '[豆包]亮嗓萌仔': 'zh_male_dongmanhaimian_mars_bigtts',
  '[豆包]暖阳女声': 'zh_female_kefunvsheng_mars_bigtts',
  // 特色/IP音色
  '[豆包]猴哥': 'zh_male_sunwukong_mars_bigtts',
  '[豆包]熊二': 'zh_male_xionger_mars_bigtts',
  '[豆包]佩奇猪': 'zh_female_peiqi_mars_bigtts',
  '[豆包]樱桃丸子': 'zh_female_yingtaowanzi_mars_bigtts',
  '[豆包]武则天': 'zh_female_wuzetian_mars_bigtts',
  '[豆包]顾姐': 'zh_female_gujie_mars_bigtts',
  '[豆包]四郎': 'zh_male_silang_mars_bigtts',
  '[豆包]鲁班七号': 'zh_male_lubanqihao_mars_bigtts',
  // 多情感音色
  '[豆包]冷酷哥哥-多情感': 'zh_male_lengkugege_emo_v2_mars_bigtts',
  '[豆包]高冷御姐-多情感': 'zh_female_gaolengyujie_emo_v2_mars_bigtts',
  '[豆包]傲娇霸总-多情感': 'zh_male_aojiaobazong_emo_v2_mars_bigtts',
  '[豆包]邻居阿姨-多情感': 'zh_female_linjuayi_emo_v2_mars_bigtts',
  '[豆包]儒雅男友-多情感': 'zh_male_ruyayichen_emo_v2_mars_bigtts',
  '[豆包]俊朗男友-多情感': 'zh_male_junlangnanyou_emo_v2_mars_bigtts',
  '[豆包]柔美女友-多情感': 'zh_female_roumeinvyou_emo_v2_mars_bigtts',
  '[豆包]阳光青年-多情感': 'zh_male_yangguangqingnian_emo_v2_mars_bigtts',
  '[豆包]爽快思思-多情感': 'zh_female_shuangkuaisisi_emo_v2_mars_bigtts',
  '[豆包]深夜播客': 'zh_male_shenyeboke_emo_v2_mars_bigtts',
  // 英文音色
  '[豆包]Lauren': 'en_female_lauren_moon_bigtts',
  '[豆包]Amanda': 'en_female_amanda_mars_bigtts',
  '[豆包]Adam': 'en_male_adam_mars_bigtts',
  '[豆包]Jackson': 'en_male_jackson_mars_bigtts',
  '[豆包]Emily': 'en_female_emily_mars_bigtts',
  '[豆包]Smith': 'en_male_smith_mars_bigtts',
  '[豆包]Anna': 'en_female_anna_mars_bigtts',
  '[豆包]Sarah': 'en_female_sarah_mars_bigtts',
  '[豆包]Dryw': 'en_male_dryw_mars_bigtts',
  '[豆包]Nara': 'en_female_nara_moon_bigtts',
  '[豆包]Bruce': 'en_male_bruce_moon_bigtts',
  '[豆包]Michael': 'en_male_michael_moon_bigtts',
  '[豆包]Daisy': 'en_female_dacey_conversation_wvae_bigtts',
  '[豆包]Luna': 'en_female_sarah_new_conversation_wvae_bigtts',
  '[豆包]Owen': 'en_male_charlie_conversation_wvae_bigtts',
  '[豆包]Lucas': 'zh_male_M100_conversation_wvae_bigtts',
  '[豆包]Candice-多情感': 'en_female_candice_emo_v2_mars_bigtts',
  '[豆包]Serena-多情感': 'en_female_skye_emo_v2_mars_bigtts',
  '[豆包]Glen-多情感': 'en_male_glen_emo_v2_mars_bigtts',
  '[豆包]Sylus-多情感': 'en_male_sylus_emo_v2_mars_bigtts',
  // 客服场景
  '[豆包]理性圆子': 'ICL_zh_female_lixingyuanzi_cs_tob',
  '[豆包]清甜桃桃': 'ICL_zh_female_qingtiantaotao_cs_tob',
  '[豆包]清晰小雪': 'ICL_zh_female_qingxixiaoxue_cs_tob',
  '[豆包]开朗婷婷': 'ICL_zh_female_kailangtingting_cs_tob',
  '[豆包]温婉珊珊': 'ICL_zh_female_wenwanshanshan_cs_tob',
  '[豆包]甜美小雨': 'ICL_zh_female_tianmeixiaoyu_cs_tob',
  '[豆包]灵动欣欣': 'ICL_zh_female_lingdongxinxin_cs_tob',
  '[豆包]乖巧可儿': 'ICL_zh_female_guaiqiaokeer_cs_tob',
  '[豆包]阳光洋洋': 'ICL_zh_male_yangguangyangyang_cs_tob',
  // ========== 豆包语音合成 2.0 (uranus) ==========
  '[豆包2.0]小何': 'zh_female_xiaohe_uranus_bigtts',
  '[豆包2.0]Vivi': 'zh_female_vv_uranus_bigtts',
  '[豆包2.0]云舟': 'zh_male_m191_uranus_bigtts',
  '[豆包2.0]小天': 'zh_male_taocheng_uranus_bigtts',
  '[豆包2.0]刘飞': 'zh_male_liufei_uranus_bigtts',
  '[豆包2.0]魅力苏菲': 'zh_male_sophie_uranus_bigtts',
  '[豆包2.0]清新女声': 'zh_female_qingxinnvsheng_uranus_bigtts',
  '[豆包2.0]甜美小源': 'zh_female_tianmeixiaoyuan_uranus_bigtts',
  '[豆包2.0]甜美桃子': 'zh_female_tianmeitaozi_uranus_bigtts',
  '[豆包2.0]爽快思思': 'zh_female_shuangkuaisisi_uranus_bigtts',
  '[豆包2.0]邻家女孩': 'zh_female_linjianvhai_uranus_bigtts',
  '[豆包2.0]少年梓辛': 'zh_male_shaonianzixin_uranus_bigtts',
  '[豆包2.0]魅力女友': 'zh_female_meilinvyou_uranus_bigtts',
  '[豆包2.0]流畅女声': 'zh_female_liuchangnv_uranus_bigtts',
  '[豆包2.0]儒雅逸辰': 'zh_male_ruyayichen_uranus_bigtts',
  '[豆包2.0]知性灿灿': 'zh_female_cancan_uranus_bigtts',
  '[豆包2.0]撒娇学妹': 'zh_female_sajiaoxuemei_uranus_bigtts',
  '[豆包2.0]猴哥': 'zh_male_sunwukong_uranus_bigtts',
  '[豆包2.0]佩奇猪': 'zh_female_peiqi_uranus_bigtts',
};

/// Volcano voice groups (matching Web VOICE_GROUPS).
const kVolcanoVoiceGroups = <String, List<String>>{
  '通用场景': [
    '灿灿2.0',
    '灿灿',
    '炀炀',
    '擎苍2.0',
    '擎苍',
    '通用女声2.0',
    '通用女声',
    '通用男声',
    '超自然音色-梓梓2.0',
    '超自然音色-梓梓',
    '超自然音色-燃燃2.0',
    '超自然音色-燃燃',
  ],
  '有声阅读': [
    '阳光青年',
    '反卷青年',
    '通用赘婿',
    '古风少御',
    '霸气青叔',
    '质朴青年',
    '温柔淑女',
    '开朗青年',
    '甜宠少御',
    '儒雅青年',
  ],
  '智能助手': ['甜美小源', '亲切女声', '知性女声', '诚诚', '童童', '亲切男声'],
  '视频配音': [
    '译制片男声',
    '懒小羊',
    '清新文艺女声',
    '鸡汤女声',
    '智慧老者',
    '慈爱姥姥',
    '说唱小哥',
    '活力解说男',
    '影视解说小帅',
    '解说小帅-多情感',
    '影视解说小美',
    '纨绔青年',
    '直播一姐',
    '沉稳解说男',
    '潇洒青年',
    '阳光男声',
    '活泼女声',
    '小萝莉',
  ],
  '特色音色': ['奶气萌娃', '动漫海绵', '动漫海星', '动漫小新', '天才童声'],
  '广告配音': ['促销男声', '促销女声', '磁性男声'],
  '新闻播报': ['新闻女声', '新闻男声'],
  '教育场景': ['知性姐姐-双语', '温柔小哥'],
  '方言-东北': ['东北老铁', '东北丫头'],
  '方言-西南': ['重庆小伙', '四川甜妹儿', '重庆幺妹儿', '广西表哥'],
  '方言-粤语': ['港剧男神', '广东女仔'],
  '方言-其他': [
    '西安佟掌柜',
    '沪上阿姐',
    '甜美台妹',
    '台普男声',
    '相声演员',
    '乡村企业家',
    '湖南妹坨',
    '长沙靓女',
    '方言灿灿',
  ],
  '美式英语': [
    '慵懒女声-Ava',
    '议论女声-Alicia',
    '情感女声-Lawrence',
    '美式女声-Amelia',
    '讲述女声-Amanda',
    '活力女声-Ariana',
    '活力男声-Jackson',
    '天才少女',
    'Stefan',
    '天真萌娃-Lily',
  ],
  '英式英语': ['亲切女声-Anna'],
  '澳洲英语': ['澳洲男声-Henry'],
  '日语': ['元气少女', '萌系少女', '气质女声', '日语男声'],
  '葡萄牙语': ['活力男声-Carlos', '活力女声-葡语'],
  '西班牙语': ['气质御姐-西语'],
  '豆包-通用': [
    '[豆包]Vivi',
    '[豆包]灿灿',
    '[豆包]爽快思思',
    '[豆包]温暖阿虎',
    '[豆包]少年梓辛',
    '[豆包]邻家女孩',
    '[豆包]渊博小叔',
    '[豆包]阳光青年',
    '[豆包]甜美小源',
    '[豆包]清澈梓梓',
    '[豆包]邻家男孩',
    '[豆包]甜美悦悦',
    '[豆包]心灵鸡汤',
    '[豆包]解说小明',
    '[豆包]开朗姐姐',
    '[豆包]亲切女声',
    '[豆包]温柔小雅',
    '[豆包]快乐小东',
    '[豆包]文静毛毛',
    '[豆包]悠悠君子',
    '[豆包]魅力苏菲',
    '[豆包]阳光阿辰',
    '[豆包]甜美桃子',
    '[豆包]清新女声',
    '[豆包]知性女声',
    '[豆包]清爽男大',
    '[豆包]温柔小哥',
  ],
  '豆包-角色扮演': [
    '[豆包]傲娇霸总',
    '[豆包]病娇姐姐',
    '[豆包]妩媚御姐',
    '[豆包]傲娇女友',
    '[豆包]冷酷哥哥',
    '[豆包]成熟姐姐',
    '[豆包]贴心女友',
    '[豆包]性感御姐',
    '[豆包]病娇弟弟',
    '[豆包]傲慢少爷',
    '[豆包]腹黑公子',
    '[豆包]暖心学姐',
    '[豆包]可爱女生',
    '[豆包]知性温婉',
    '[豆包]暖心体贴',
    '[豆包]开朗轻快',
    '[豆包]活泼爽朗',
    '[豆包]率真小伙',
    '[豆包]温柔文雅',
    '[豆包]温柔女神',
    '[豆包]炀炀',
  ],
  '豆包-视频配音': [
    '[豆包]擎苍',
    '[豆包]霸气青叔',
    '[豆包]温柔淑女',
    '[豆包]儒雅青年',
    '[豆包]悬疑解说',
    '[豆包]古风少御',
    '[豆包]活力小哥',
    '[豆包]鸡汤妹妹',
    '[豆包]贴心女声',
    '[豆包]萌丫头',
    '[豆包]磁性解说男声',
    '[豆包]广告解说',
    '[豆包]少儿故事',
    '[豆包]天才童声',
    '[豆包]俏皮女声',
    '[豆包]懒音绵宝',
    '[豆包]亮嗓萌仔',
    '[豆包]暖阳女声',
  ],
  '豆包-IP音色': [
    '[豆包]猴哥',
    '[豆包]熊二',
    '[豆包]佩奇猪',
    '[豆包]樱桃丸子',
    '[豆包]武则天',
    '[豆包]顾姐',
    '[豆包]四郎',
    '[豆包]鲁班七号',
  ],
  '豆包-多情感': [
    '[豆包]冷酷哥哥-多情感',
    '[豆包]高冷御姐-多情感',
    '[豆包]傲娇霸总-多情感',
    '[豆包]邻居阿姨-多情感',
    '[豆包]儒雅男友-多情感',
    '[豆包]俊朗男友-多情感',
    '[豆包]柔美女友-多情感',
    '[豆包]阳光青年-多情感',
    '[豆包]爽快思思-多情感',
    '[豆包]深夜播客',
  ],
  '豆包-英文': [
    '[豆包]Lauren',
    '[豆包]Amanda',
    '[豆包]Adam',
    '[豆包]Jackson',
    '[豆包]Emily',
    '[豆包]Smith',
    '[豆包]Anna',
    '[豆包]Sarah',
    '[豆包]Dryw',
    '[豆包]Nara',
    '[豆包]Bruce',
    '[豆包]Michael',
    '[豆包]Daisy',
    '[豆包]Luna',
    '[豆包]Owen',
    '[豆包]Lucas',
    '[豆包]Candice-多情感',
    '[豆包]Serena-多情感',
    '[豆包]Glen-多情感',
    '[豆包]Sylus-多情感',
  ],
  '豆包-客服': [
    '[豆包]理性圆子',
    '[豆包]清甜桃桃',
    '[豆包]清晰小雪',
    '[豆包]开朗婷婷',
    '[豆包]温婉珊珊',
    '[豆包]甜美小雨',
    '[豆包]灵动欣欣',
    '[豆包]乖巧可儿',
    '[豆包]阳光洋洋',
  ],
  '豆包2.0 (仅V3)': [
    '[豆包2.0]小何',
    '[豆包2.0]Vivi',
    '[豆包2.0]云舟',
    '[豆包2.0]小天',
    '[豆包2.0]刘飞',
    '[豆包2.0]魅力苏菲',
    '[豆包2.0]清新女声',
    '[豆包2.0]甜美小源',
    '[豆包2.0]甜美桃子',
    '[豆包2.0]爽快思思',
    '[豆包2.0]邻家女孩',
    '[豆包2.0]少年梓辛',
    '[豆包2.0]魅力女友',
    '[豆包2.0]流畅女声',
    '[豆包2.0]儒雅逸辰',
    '[豆包2.0]知性灿灿',
    '[豆包2.0]撒娇学妹',
    '[豆包2.0]猴哥',
    '[豆包2.0]佩奇猪',
  ],
};

/// Volcano emotion ID → Chinese label.
const kVolcanoEmotions = <String, String>{
  'happy': '开心',
  'sad': '悲伤',
  'angry': '愤怒',
  'scare': '害怕',
  'hate': '厌恶',
  'surprise': '惊讶',
  'tear': '哭腔',
  'novel_dialog': '平和',
  'excited': '激动',
  'coldness': '冷漠',
  'neutral': '中性',
  'depressed': '沮丧',
  'fear': '恐惧',
  'pleased': '愉悦',
  'sorry': '抱歉',
  'annoyed': '嗔怪',
  'shy': '害羞',
  'tender': '温柔',
  'customer_service': '客服',
  'professional': '专业',
  'serious': '严肃',
  'assistant': '助手',
  'advertising': '广告',
  'news': '新闻播报',
  'entertainment': '娱乐八卦',
  'narrator': '旁白-舒缓',
  'narrator_immersive': '旁白-沉浸',
  'storytelling': '讲故事',
  'radio': '情感电台',
  'chat': '自然对话',
  'comfort': '安慰鼓励',
  'lovey-dovey': '撒娇',
  'energetic': '可爱元气',
  'conniving': '绿茶',
  'tsundere': '傲娇',
  'charming': '娇媚',
  'yoga': '瑜伽',
  'tension': '咆哮/焦急',
  'magnetic': '磁性',
  'vocal-fry': '气泡音',
  'asmr': '低语ASMR',
  'dialect': '方言',
  'warm': '温暖',
  'affectionate': '深情',
  'authoritative': '权威',
};

/// Volcano emotion groups for the full-screen selector.
const kVolcanoEmotionGroups = <String, List<String>>{
  '基础情感': [
    'happy',
    'sad',
    'angry',
    'scare',
    'fear',
    'hate',
    'surprise',
    'tear',
    'novel_dialog',
    'excited',
    'coldness',
    'neutral',
    'depressed',
  ],
  '交流情感': ['pleased', 'sorry', 'annoyed', 'shy', 'tender'],
  '专业风格': [
    'customer_service',
    'professional',
    'serious',
    'assistant',
    'advertising',
    'news',
    'entertainment',
  ],
  '叙述风格': ['narrator', 'narrator_immersive', 'storytelling', 'radio', 'chat'],
  '特色风格': [
    'comfort',
    'lovey-dovey',
    'energetic',
    'conniving',
    'tsundere',
    'charming',
    'yoga',
    'tension',
    'magnetic',
    'vocal-fry',
    'asmr',
    'dialect',
  ],
  '英文专用': ['warm', 'affectionate', 'authoritative'],
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool isVolcanoBigModelVoice(String voiceType) {
  return voiceType.contains('_bigtts') ||
      voiceType.startsWith('ICL_') ||
      voiceType.startsWith('S_');
}

bool isVolcanoSeedTts2Voice(String voiceType) {
  return voiceType.contains('_uranus_');
}

/// Build [SelectorGroup] list from Volcano voice groups.
List<SelectorGroup> buildVolcanoVoiceGroups() {
  return kVolcanoVoiceGroups.entries.map((entry) {
    return SelectorGroup(
      name: entry.key,
      items: entry.value.map((voiceName) {
        final voiceType = kVolcanoVoices[voiceName] ?? '';
        final compat = isVolcanoSeedTts2Voice(voiceType)
            ? 'V3'
            : isVolcanoBigModelVoice(voiceType)
            ? 'V1+V3'
            : 'V1';
        return SelectorItem(
          key: voiceName,
          label: voiceName,
          subLabel: '$voiceType · $compat',
        );
      }).toList(),
    );
  }).toList();
}

/// Build [SelectorGroup] list from Volcano emotion groups.
List<SelectorGroup> buildVolcanoEmotionGroups() {
  return kVolcanoEmotionGroups.entries.map((entry) {
    return SelectorGroup(
      name: entry.key,
      items: entry.value
          .where((key) => kVolcanoEmotions.containsKey(key))
          .map(
            (key) => SelectorItem(
              key: key,
              label: kVolcanoEmotions[key]!,
              subLabel: key,
            ),
          )
          .toList(),
    );
  }).toList();
}

/// Build a flat [SelectorGroup] from a list of [VoicePreset].
List<SelectorGroup> buildPresetGroups(
  String groupName,
  List<VoicePreset> presets,
) {
  return [
    SelectorGroup(
      name: groupName,
      items: presets
          .map(
            (p) =>
                SelectorItem(key: p.id, label: p.name, subLabel: p.description),
          )
          .toList(),
    ),
  ];
}
