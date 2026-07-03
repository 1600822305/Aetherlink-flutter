#pragma once

#include <cstdint>
#include <string>
#include <unordered_map>

namespace axml {

// 复杂类型单位（dimension 和 fraction）
enum ComplexUnit {
    COMPLEX_UNIT_PX = 0,    // 像素
    COMPLEX_UNIT_DIP = 1,   // 设备独立像素 (dp)
    COMPLEX_UNIT_SP = 2,    // 缩放独立像素 (sp)
    COMPLEX_UNIT_PT = 3,    // 点
    COMPLEX_UNIT_IN = 4,    // 英寸
    COMPLEX_UNIT_MM = 5,    // 毫米
    COMPLEX_UNIT_FRACTION = 0,         // 百分比 (%)
    COMPLEX_UNIT_FRACTION_PARENT = 1   // 父容器百分比 (%p)
};

// 属性值类型 (完整列表参考 axmldec)
enum ResourceValueType : uint8_t {
    TYPE_NULL = 0x00,           // 空值
    TYPE_REFERENCE = 0x01,      // 资源引用 @resource
    TYPE_ATTRIBUTE = 0x02,      // 属性引用 ?attr
    TYPE_STRING = 0x03,         // 字符串
    TYPE_FLOAT = 0x04,          // 浮点数
    TYPE_DIMENSION = 0x05,      // 尺寸值 (100dp, 50sp)
    TYPE_FRACTION = 0x06,       // 百分比值 (50%, 25%p)
    TYPE_DYNAMIC_REFERENCE = 0x07,  // 动态资源引用
    
    TYPE_FIRST_INT = 0x10,
    TYPE_INT_DEC = 0x10,        // 十进制整数
    TYPE_INT_HEX = 0x11,        // 十六进制整数
    TYPE_INT_BOOLEAN = 0x12,    // 布尔值
    
    TYPE_FIRST_COLOR_INT = 0x1c,
    TYPE_INT_COLOR_ARGB8 = 0x1c,   // #AARRGGBB
    TYPE_INT_COLOR_RGB8 = 0x1d,    // #RRGGBB
    TYPE_INT_COLOR_ARGB4 = 0x1e,   // #ARGB
    TYPE_INT_COLOR_RGB4 = 0x1f,    // #RGB
    TYPE_LAST_COLOR_INT = 0x1f,
    TYPE_LAST_INT = 0x1f
};

// 解析复杂类型值 (dimension/fraction)
inline std::string parse_complex_value(uint32_t data, bool is_fraction) {
    constexpr float MANTISSA_MULT = 1.0f / (1 << 8);
    constexpr float RADIX_MULTS[] = {
        MANTISSA_MULT * 1.0f,
        MANTISSA_MULT * 1.0f / (1 << 7),
        MANTISSA_MULT * 1.0f / (1 << 15),
        MANTISSA_MULT * 1.0f / (1 << 23)
    };
    
    float value = static_cast<int32_t>(data & 0xffffff00) * RADIX_MULTS[(data >> 4) & 0x3];
    uint8_t unit = data & 0xf;
    
    char buf[64];
    if (is_fraction) {
        value *= 100.0f;
        switch (unit) {
            case COMPLEX_UNIT_FRACTION:
                snprintf(buf, sizeof(buf), "%.2f%%", value);
                break;
            case COMPLEX_UNIT_FRACTION_PARENT:
                snprintf(buf, sizeof(buf), "%.2f%%p", value);
                break;
            default:
                snprintf(buf, sizeof(buf), "%.2f", value);
        }
    } else {
        // 整数值去掉小数点
        if (value == static_cast<int>(value)) {
            switch (unit) {
                case COMPLEX_UNIT_PX:
                    snprintf(buf, sizeof(buf), "%dpx", static_cast<int>(value));
                    break;
                case COMPLEX_UNIT_DIP:
                    snprintf(buf, sizeof(buf), "%ddp", static_cast<int>(value));
                    break;
                case COMPLEX_UNIT_SP:
                    snprintf(buf, sizeof(buf), "%dsp", static_cast<int>(value));
                    break;
                case COMPLEX_UNIT_PT:
                    snprintf(buf, sizeof(buf), "%dpt", static_cast<int>(value));
                    break;
                case COMPLEX_UNIT_IN:
                    snprintf(buf, sizeof(buf), "%din", static_cast<int>(value));
                    break;
                case COMPLEX_UNIT_MM:
                    snprintf(buf, sizeof(buf), "%dmm", static_cast<int>(value));
                    break;
                default:
                    snprintf(buf, sizeof(buf), "%d", static_cast<int>(value));
            }
        } else {
            switch (unit) {
                case COMPLEX_UNIT_PX:
                    snprintf(buf, sizeof(buf), "%.2fpx", value);
                    break;
                case COMPLEX_UNIT_DIP:
                    snprintf(buf, sizeof(buf), "%.2fdp", value);
                    break;
                case COMPLEX_UNIT_SP:
                    snprintf(buf, sizeof(buf), "%.2fsp", value);
                    break;
                case COMPLEX_UNIT_PT:
                    snprintf(buf, sizeof(buf), "%.2fpt", value);
                    break;
                case COMPLEX_UNIT_IN:
                    snprintf(buf, sizeof(buf), "%.2fin", value);
                    break;
                case COMPLEX_UNIT_MM:
                    snprintf(buf, sizeof(buf), "%.2fmm", value);
                    break;
                default:
                    snprintf(buf, sizeof(buf), "%.2f", value);
            }
        }
    }
    return std::string(buf);
}

// 编码复杂类型值
inline bool encode_complex_value(const std::string& str, uint32_t& data, bool& is_dimension) {
    float value = 0.0f;
    uint8_t unit = 0;
    is_dimension = true;
    
    // 尝试解析尺寸值
    char unit_str[8] = {0};
    if (sscanf(str.c_str(), "%f%7s", &value, unit_str) >= 1) {
        std::string unit_s = unit_str;
        
        if (unit_s == "dp" || unit_s == "dip") {
            unit = COMPLEX_UNIT_DIP;
        } else if (unit_s == "sp") {
            unit = COMPLEX_UNIT_SP;
        } else if (unit_s == "px") {
            unit = COMPLEX_UNIT_PX;
        } else if (unit_s == "pt") {
            unit = COMPLEX_UNIT_PT;
        } else if (unit_s == "in") {
            unit = COMPLEX_UNIT_IN;
        } else if (unit_s == "mm") {
            unit = COMPLEX_UNIT_MM;
        } else if (unit_s == "%" || unit_s == "%p") {
            is_dimension = false;
            unit = (unit_s == "%p") ? COMPLEX_UNIT_FRACTION_PARENT : COMPLEX_UNIT_FRACTION;
            value /= 100.0f;  // 百分比需要除以100
        } else if (unit_s.empty()) {
            // 纯数值
            unit = COMPLEX_UNIT_PX;
        } else {
            return false;
        }
        
        // 编码值
        constexpr float MANTISSA_MULT = 1.0f / (1 << 8);
        int radix = 0;
        float encoded_value = value / MANTISSA_MULT;
        
        // 选择合适的基数
        if (encoded_value >= 0x800000 || encoded_value <= -0x800000) {
            radix = 0;
        } else if (encoded_value >= 0x10000 || encoded_value <= -0x10000) {
            radix = 1;
            encoded_value *= (1 << 7);
        } else if (encoded_value >= 0x200 || encoded_value <= -0x200) {
            radix = 2;
            encoded_value *= (1 << 15);
        } else {
            radix = 3;
            encoded_value *= (1 << 23);
        }
        
        int32_t mantissa = static_cast<int32_t>(encoded_value) & 0xffffff00;
        if (mantissa == 0 && value != 0) {
            mantissa = static_cast<int32_t>(value) << 8;
        }
        
        data = (mantissa & 0xffffff00) | ((radix & 0x3) << 4) | (unit & 0xf);
        return true;
    }
    
    return false;
}

// 解析颜色值为字符串
inline std::string format_color(uint32_t data, uint8_t type) {
    char buf[16];
    switch (type) {
        case TYPE_INT_COLOR_ARGB8:
            snprintf(buf, sizeof(buf), "#%08X", data);
            break;
        case TYPE_INT_COLOR_RGB8:
            snprintf(buf, sizeof(buf), "#%06X", data & 0xFFFFFF);
            break;
        case TYPE_INT_COLOR_ARGB4:
            snprintf(buf, sizeof(buf), "#%04X", data & 0xFFFF);
            break;
        case TYPE_INT_COLOR_RGB4:
            snprintf(buf, sizeof(buf), "#%03X", data & 0xFFF);
            break;
        default:
            snprintf(buf, sizeof(buf), "#%08X", data);
    }
    return std::string(buf);
}

// 解析颜色字符串为值
inline bool parse_color_string(const std::string& str, uint32_t& data, uint8_t& type) {
    if (str.empty() || str[0] != '#') return false;
    
    std::string hex = str.substr(1);
    try {
        data = std::stoul(hex, nullptr, 16);
        
        switch (hex.length()) {
            case 8:  // #AARRGGBB
                type = TYPE_INT_COLOR_ARGB8;
                break;
            case 6:  // #RRGGBB
                type = TYPE_INT_COLOR_RGB8;
                // 补充 alpha 通道
                data |= 0xFF000000;
                break;
            case 4:  // #ARGB
                type = TYPE_INT_COLOR_ARGB4;
                break;
            case 3:  // #RGB
                type = TYPE_INT_COLOR_RGB4;
                break;
            default:
                return false;
        }
        return true;
    } catch (...) {
        return false;
    }
}

// Android 属性资源 ID 映射表 (基于 axmldec)
// 资源 ID 格式: 0x01010XXX (android:xxx 属性)
inline const char* get_android_attr_name(uint32_t res_id) {
    static const std::unordered_map<uint32_t, const char*> ANDROID_ATTRS = {
        // 核心属性 0x01010000 - 0x010100ff
        {0x01010000, "theme"},
        {0x01010001, "label"},
        {0x01010002, "icon"},
        {0x01010003, "name"},
        {0x01010004, "manageSpaceActivity"},
        {0x01010005, "allowClearUserData"},
        {0x01010006, "permission"},
        {0x01010007, "readPermission"},
        {0x01010008, "writePermission"},
        {0x01010009, "protectionLevel"},
        {0x0101000a, "permissionGroup"},
        {0x0101000b, "sharedUserId"},
        {0x0101000c, "hasCode"},
        {0x0101000d, "persistent"},
        {0x0101000e, "enabled"},
        {0x0101000f, "debuggable"},
        {0x01010010, "exported"},
        {0x01010011, "process"},
        {0x01010012, "taskAffinity"},
        {0x01010013, "multiprocess"},
        {0x01010014, "finishOnTaskLaunch"},
        {0x01010015, "clearTaskOnLaunch"},
        {0x01010016, "stateNotNeeded"},
        {0x01010017, "excludeFromRecents"},
        {0x01010018, "authorities"},
        {0x01010019, "syncable"},
        {0x0101001a, "initOrder"},
        {0x0101001b, "grantUriPermissions"},
        {0x0101001c, "priority"},
        {0x0101001d, "launchMode"},
        {0x0101001e, "screenOrientation"},
        {0x0101001f, "configChanges"},
        {0x01010020, "description"},
        {0x01010021, "targetPackage"},
        {0x01010022, "handleProfiling"},
        {0x01010023, "functionalTest"},
        {0x01010024, "value"},
        {0x01010025, "resource"},
        {0x01010026, "mimeType"},
        {0x01010027, "scheme"},
        {0x01010028, "host"},
        {0x01010029, "port"},
        {0x0101002a, "path"},
        {0x0101002b, "pathPrefix"},
        {0x0101002c, "pathPattern"},
        {0x0101002d, "action"},
        {0x0101002e, "data"},
        {0x0101002f, "targetClass"},
        
        // 视图属性
        {0x010100d0, "id"},
        {0x010100d1, "tag"},
        {0x010100d2, "scrollX"},
        {0x010100d3, "scrollY"},
        {0x010100d4, "background"},
        {0x010100d5, "padding"},
        {0x010100d6, "paddingLeft"},
        {0x010100d7, "paddingTop"},
        {0x010100d8, "paddingRight"},
        {0x010100d9, "paddingBottom"},
        {0x010100da, "focusable"},
        {0x010100db, "focusableInTouchMode"},
        {0x010100dc, "visibility"},
        {0x010100dd, "fitsSystemWindows"},
        {0x010100de, "scrollbars"},
        {0x010100df, "fadingEdge"},
        {0x010100e0, "fadingEdgeLength"},
        {0x010100e1, "nextFocusLeft"},
        {0x010100e2, "nextFocusRight"},
        {0x010100e3, "nextFocusUp"},
        {0x010100e4, "nextFocusDown"},
        {0x010100e5, "clickable"},
        {0x010100e6, "longClickable"},
        {0x010100e7, "saveEnabled"},
        {0x010100e8, "drawingCacheQuality"},
        {0x010100e9, "duplicateParentState"},
        
        // 布局属性
        {0x010100f4, "layout_width"},
        {0x010100f5, "layout_height"},
        {0x010100f6, "layout_margin"},
        {0x010100f7, "layout_marginLeft"},
        {0x010100f8, "layout_marginTop"},
        {0x010100f9, "layout_marginRight"},
        {0x010100fa, "layout_marginBottom"},
        
        // 文本属性
        {0x01010095, "textSize"},
        {0x01010096, "typeface"},
        {0x01010097, "textStyle"},
        {0x01010098, "textColor"},
        {0x01010099, "textColorHighlight"},
        {0x0101009a, "textColorHint"},
        {0x0101009b, "textColorLink"},
        
        // gravity
        {0x010100af, "gravity"},
        {0x010100b3, "layout_gravity"},
        
        // 方向
        {0x010100c4, "orientation"},
        
        // 更多文本属性
        {0x0101014f, "text"},
        {0x01010150, "hint"},
        
        // 尺寸
        {0x01010140, "minWidth"},
        {0x01010141, "minHeight"},
        {0x0101011f, "maxWidth"},
        {0x01010120, "maxHeight"},
        
        // SDK 版本
        {0x0101020c, "minSdkVersion"},
        {0x01010270, "targetSdkVersion"},
        {0x01010271, "maxSdkVersion"},
        
        // 版本信息
        {0x0101021b, "versionCode"},
        {0x0101021c, "versionName"},
        
        // 应用属性
        {0x01010224, "installLocation"},
        {0x0101026c, "largeHeap"},
        {0x0101028e, "hardwareAccelerated"},
        {0x010102b7, "supportsRtl"},
        {0x01010473, "extractNativeLibs"},
        {0x010104d6, "usesCleartextTraffic"},
        
        // Activity 属性
        {0x0101022b, "windowSoftInputMode"},
        {0x01010362, "parentActivityName"},
        
        // Service 属性
        {0x01010020, "foregroundServiceType"},
        
        // 权限相关
        {0x01010003, "name"},
        
        // 更多属性可以按需添加...
    };
    
    auto it = ANDROID_ATTRS.find(res_id);
    if (it != ANDROID_ATTRS.end()) {
        return it->second;
    }
    return nullptr;
}

// 反向查找：属性名 -> 资源 ID
inline uint32_t get_android_attr_id(const std::string& name) {
    static const std::unordered_map<std::string, uint32_t> NAME_TO_ID = {
        {"theme", 0x01010000},
        {"label", 0x01010001},
        {"icon", 0x01010002},
        {"name", 0x01010003},
        {"permission", 0x01010006},
        {"readPermission", 0x01010007},
        {"writePermission", 0x01010008},
        {"protectionLevel", 0x01010009},
        {"sharedUserId", 0x0101000b},
        {"hasCode", 0x0101000c},
        {"persistent", 0x0101000d},
        {"enabled", 0x0101000e},
        {"debuggable", 0x0101000f},
        {"exported", 0x01010010},
        {"process", 0x01010011},
        {"taskAffinity", 0x01010012},
        {"launchMode", 0x0101001d},
        {"screenOrientation", 0x0101001e},
        {"configChanges", 0x0101001f},
        {"description", 0x01010020},
        {"value", 0x01010024},
        {"resource", 0x01010025},
        {"mimeType", 0x01010026},
        {"scheme", 0x01010027},
        {"host", 0x01010028},
        {"port", 0x01010029},
        {"path", 0x0101002a},
        {"pathPrefix", 0x0101002b},
        {"pathPattern", 0x0101002c},
        {"action", 0x0101002d},
        {"data", 0x0101002e},
        
        {"id", 0x010100d0},
        {"tag", 0x010100d1},
        {"background", 0x010100d4},
        {"padding", 0x010100d5},
        {"paddingLeft", 0x010100d6},
        {"paddingTop", 0x010100d7},
        {"paddingRight", 0x010100d8},
        {"paddingBottom", 0x010100d9},
        {"focusable", 0x010100da},
        {"visibility", 0x010100dc},
        {"clickable", 0x010100e5},
        
        {"layout_width", 0x010100f4},
        {"layout_height", 0x010100f5},
        {"layout_margin", 0x010100f6},
        {"layout_marginLeft", 0x010100f7},
        {"layout_marginTop", 0x010100f8},
        {"layout_marginRight", 0x010100f9},
        {"layout_marginBottom", 0x010100fa},
        
        {"textSize", 0x01010095},
        {"typeface", 0x01010096},
        {"textStyle", 0x01010097},
        {"textColor", 0x01010098},
        
        {"gravity", 0x010100af},
        {"layout_gravity", 0x010100b3},
        {"orientation", 0x010100c4},
        
        {"text", 0x0101014f},
        {"hint", 0x01010150},
        
        {"minWidth", 0x01010140},
        {"minHeight", 0x01010141},
        {"maxWidth", 0x0101011f},
        {"maxHeight", 0x01010120},
        
        {"minSdkVersion", 0x0101020c},
        {"targetSdkVersion", 0x01010270},
        {"maxSdkVersion", 0x01010271},
        
        {"versionCode", 0x0101021b},
        {"versionName", 0x0101021c},
        
        {"installLocation", 0x01010224},
        {"largeHeap", 0x0101026c},
        {"hardwareAccelerated", 0x0101028e},
        {"supportsRtl", 0x010102b7},
        {"extractNativeLibs", 0x01010473},
        {"usesCleartextTraffic", 0x010104d6},
        
        {"windowSoftInputMode", 0x0101022b},
        {"parentActivityName", 0x01010362},
    };
    
    auto it = NAME_TO_ID.find(name);
    if (it != NAME_TO_ID.end()) {
        return it->second;
    }
    return 0;
}

} // namespace axml
