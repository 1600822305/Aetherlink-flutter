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
  VoicePreset(id: 'speech-02-hd', name: 'Speech 02 HD', description: '高清语音模型'),
  VoicePreset(id: 'speech-02', name: 'Speech 02', description: '标准语音模型'),
  VoicePreset(id: 'speech-01-hd', name: 'Speech 01 HD', description: '旧版高清模型'),
  VoicePreset(id: 'speech-01', name: 'Speech 01', description: '旧版标准模型'),
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
  VoicePreset(id: '', name: '自动', description: '自动检测语言'),
  VoicePreset(id: 'Chinese', name: '中文普通话', description: '优化普通话发音'),
  VoicePreset(id: 'Chinese,Yue', name: '粤语', description: '优化粤语发音'),
  VoicePreset(id: 'English', name: '英语', description: '优化英语发音'),
  VoicePreset(id: 'Japanese', name: '日语', description: '优化日语发音'),
  VoicePreset(id: 'Korean', name: '韩语', description: '优化韩语发音'),
];

// ---------------------------------------------------------------------------
// SiliconFlow
// ---------------------------------------------------------------------------

const kSiliconFlowModels = <VoicePreset>[
  VoicePreset(
    id: 'FunAudioLLM/CosyVoice2-0.5B',
    name: 'CosyVoice2-0.5B',
    description: '多语言语音合成',
  ),
  VoicePreset(
    id: 'IndexTeam/IndexTTS-2',
    name: 'IndexTTS-2',
    description: 'B站情感语音合成',
  ),
  VoicePreset(
    id: 'fnlp/MOSS-TTSD-v0.5',
    name: 'MOSS-TTSD-v0.5',
    description: '高表现力对话语音',
  ),
];

const kSiliconFlowVoices = <String, List<VoicePreset>>{
  'FunAudioLLM/CosyVoice2-0.5B': [
    VoicePreset(id: 'alex', name: 'Alex', description: '沉稳男声'),
    VoicePreset(id: 'benjamin', name: 'Benjamin', description: '低沉男声'),
    VoicePreset(id: 'charles', name: 'Charles', description: '磁性男声'),
    VoicePreset(id: 'david', name: 'David', description: '欢快男声'),
    VoicePreset(id: 'anna', name: 'Anna', description: '沉稳女声'),
    VoicePreset(id: 'bella', name: 'Bella', description: '激情女声'),
    VoicePreset(id: 'claire', name: 'Claire', description: '温柔女声'),
    VoicePreset(id: 'diana', name: 'Diana', description: '欢快女声'),
  ],
  'IndexTeam/IndexTTS-2': [
    VoicePreset(id: 'alex', name: 'Alex', description: '沉稳男声'),
    VoicePreset(id: 'benjamin', name: 'Benjamin', description: '低沉男声'),
    VoicePreset(id: 'charles', name: 'Charles', description: '磁性男声'),
    VoicePreset(id: 'david', name: 'David', description: '欢快男声'),
    VoicePreset(id: 'anna', name: 'Anna', description: '沉稳女声'),
    VoicePreset(id: 'bella', name: 'Bella', description: '激情女声'),
    VoicePreset(id: 'claire', name: 'Claire', description: '温柔女声'),
    VoicePreset(id: 'diana', name: 'Diana', description: '欢快女声'),
  ],
  'fnlp/MOSS-TTSD-v0.5': [
    VoicePreset(id: 'alex', name: 'Alex', description: '沉稳男声'),
    VoicePreset(id: 'benjamin', name: 'Benjamin', description: '低沉男声'),
    VoicePreset(id: 'charles', name: 'Charles', description: '磁性男声'),
    VoicePreset(id: 'david', name: 'David', description: '欢快男声'),
    VoicePreset(id: 'anna', name: 'Anna', description: '沉稳女声'),
    VoicePreset(id: 'bella', name: 'Bella', description: '激情女声'),
    VoicePreset(id: 'claire', name: 'Claire', description: '温柔女声'),
    VoicePreset(id: 'diana', name: 'Diana', description: '欢快女声'),
  ],
};

// ---------------------------------------------------------------------------
// Azure
// ---------------------------------------------------------------------------

const kAzureVoices = <VoicePreset>[
  VoicePreset(id: 'zh-CN-XiaoxiaoNeural', name: '晓晓', description: '标准女声'),
  VoicePreset(id: 'zh-CN-YunxiNeural', name: '云希', description: '标准男声'),
  VoicePreset(id: 'zh-CN-YunjianNeural', name: '云健', description: '新闻播报男声'),
  VoicePreset(id: 'zh-CN-XiaoyiNeural', name: '晓伊', description: '儿童女声'),
  VoicePreset(id: 'zh-CN-YunyangNeural', name: '云扬', description: '专业新闻男声'),
  VoicePreset(id: 'zh-CN-XiaohanNeural', name: '晓涵', description: '情感女声'),
  VoicePreset(id: 'zh-CN-XiaomoNeural', name: '晓墨', description: '温暖女声'),
  VoicePreset(id: 'zh-CN-XiaoxuanNeural', name: '晓萱', description: '轻快女声'),
  VoicePreset(id: 'zh-CN-XiaoruiNeural', name: '晓蕊', description: '老年女声'),
  VoicePreset(id: 'zh-CN-YunzeNeural', name: '云泽', description: '广播男声'),
  VoicePreset(id: 'en-US-JennyNeural', name: 'Jenny', description: '英文女声'),
  VoicePreset(id: 'en-US-GuyNeural', name: 'Guy', description: '英文男声'),
  VoicePreset(id: 'en-US-AriaNeural', name: 'Aria', description: '英文情感女声'),
  VoicePreset(id: 'ja-JP-NanamiNeural', name: 'Nanami', description: '日文女声'),
  VoicePreset(id: 'ko-KR-SunHiNeural', name: 'SunHi', description: '韩文女声'),
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
    description: '超低延迟模型',
  ),
  VoicePreset(
    id: 'eleven_monolingual_v1',
    name: 'English v1',
    description: '英语专用模型',
  ),
];

const kElevenLabsOutputFormats = <VoicePreset>[
  VoicePreset(
    id: 'mp3_44100_128',
    name: 'MP3 44.1kHz 128kbps',
    description: '高质量',
  ),
  VoicePreset(
    id: 'mp3_44100_64',
    name: 'MP3 44.1kHz 64kbps',
    description: '标准质量',
  ),
  VoicePreset(
    id: 'mp3_22050_32',
    name: 'MP3 22.05kHz 32kbps',
    description: '低带宽',
  ),
  VoicePreset(id: 'pcm_16000', name: 'PCM 16kHz', description: '原始 PCM'),
  VoicePreset(id: 'pcm_22050', name: 'PCM 22.05kHz', description: '原始 PCM 高采样'),
  VoicePreset(id: 'pcm_24000', name: 'PCM 24kHz', description: '原始 PCM 24k'),
  VoicePreset(
    id: 'pcm_44100',
    name: 'PCM 44.1kHz',
    description: '原始 PCM CD 质量',
  ),
  VoicePreset(id: 'ulaw_8000', name: 'μ-law 8kHz', description: '电话质量'),
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
