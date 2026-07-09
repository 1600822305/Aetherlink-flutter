#include "arsc/arsc_parser.h"
#include <fstream>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <sstream>

namespace arsc {

// Chunk types
static const uint16_t RES_NULL_TYPE = 0x0000;
static const uint16_t RES_STRING_POOL_TYPE = 0x0001;
static const uint16_t RES_TABLE_TYPE = 0x0002;
static const uint16_t RES_TABLE_PACKAGE_TYPE = 0x0200;
static const uint16_t RES_TABLE_TYPE_TYPE = 0x0201;
static const uint16_t RES_TABLE_TYPE_SPEC_TYPE = 0x0202;

// String pool flags
static const uint32_t SORTED_FLAG = 1 << 0;
static const uint32_t UTF8_FLAG = 1 << 8;

bool ArscParser::parse(const std::string& path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file) return false;
    
    auto size = file.tellg();
    if (size <= 0) return false;
    
    std::vector<uint8_t> data(static_cast<size_t>(size));
    file.seekg(0);
    file.read(reinterpret_cast<char*>(data.data()), size);
    
    return parse(data);
}

bool ArscParser::parse(const std::vector<uint8_t>& data) {
    if (data.size() < 12) return false;
    
    data_ = data;
    strings_.clear();
    resources_.clear();
    id_to_index_.clear();
    
    // Read table header
    uint16_t type = read_le<uint16_t>(0);
    uint16_t header_size = read_le<uint16_t>(2);
    uint32_t size = read_le<uint32_t>(4);
    
    if (type != RES_TABLE_TYPE) return false;
    if (size > data_.size()) return false;
    
    uint32_t package_count = read_le<uint32_t>(8);
    
    size_t offset = header_size;
    
    while (offset + 8 <= data_.size()) {
        uint16_t chunk_type = read_le<uint16_t>(offset);
        uint16_t chunk_header_size = read_le<uint16_t>(offset + 2);
        uint32_t chunk_size = read_le<uint32_t>(offset + 4);
        
        if (chunk_size < 8 || offset + chunk_size > data_.size()) break;
        
        switch (chunk_type) {
            case RES_STRING_POOL_TYPE:
                parse_string_pool(offset, chunk_size);
                break;
            case RES_TABLE_PACKAGE_TYPE:
                parse_package(offset, chunk_size);
                break;
        }
        
        offset += chunk_size;
    }
    
    return true;
}

bool ArscParser::parse_string_pool(size_t offset, size_t size) {
    if (offset + 28 > data_.size()) return false;
    
    uint16_t header_size = read_le<uint16_t>(offset + 2);
    uint32_t string_count = read_le<uint32_t>(offset + 8);
    uint32_t style_count = read_le<uint32_t>(offset + 12);
    uint32_t flags = read_le<uint32_t>(offset + 16);
    uint32_t strings_start = read_le<uint32_t>(offset + 20);
    
    bool is_utf8 = (flags & UTF8_FLAG) != 0;
    
    size_t string_offsets_start = offset + header_size;
    size_t strings_data_start = offset + strings_start;
    
    for (uint32_t i = 0; i < string_count; i++) {
        if (string_offsets_start + i * 4 + 4 > data_.size()) break;
        
        uint32_t str_offset = read_le<uint32_t>(string_offsets_start + i * 4);
        size_t abs_offset = strings_data_start + str_offset;
        
        if (abs_offset >= data_.size()) {
            strings_.push_back("");
            continue;
        }
        
        std::string str = read_string_at(abs_offset, is_utf8);
        strings_.push_back(str);
    }
    
    return true;
}

std::string ArscParser::read_string_at(size_t offset, bool utf8) const {
    if (offset >= data_.size()) return "";
    
    if (utf8) {
        // UTF-8 format: charLen (1-2 bytes), byteLen (1-2 bytes), data
        uint8_t char_len = data_[offset];
        offset++;
        if (char_len & 0x80) {
            offset++; // Skip high byte
        }
        
        if (offset >= data_.size()) return "";
        
        uint8_t byte_len = data_[offset];
        offset++;
        if (byte_len & 0x80) {
            byte_len = ((byte_len & 0x7F) << 8) | data_[offset];
            offset++;
        }
        
        if (offset + byte_len > data_.size()) return "";
        
        return std::string(reinterpret_cast<const char*>(&data_[offset]), byte_len);
    } else {
        // UTF-16 format: len (2 bytes), data
        if (offset + 2 > data_.size()) return "";
        
        uint16_t len = read_le<uint16_t>(offset);
        offset += 2;
        
        if (len & 0x8000) {
            len = ((len & 0x7FFF) << 16) | read_le<uint16_t>(offset);
            offset += 2;
        }
        
        std::string result;
        for (uint16_t i = 0; i < len && offset + 2 <= data_.size(); i++) {
            uint16_t ch = read_le<uint16_t>(offset);
            offset += 2;
            if (ch == 0) break;
            if (ch < 0x80) {
                result += static_cast<char>(ch);
            } else if (ch < 0x800) {
                result += static_cast<char>(0xC0 | (ch >> 6));
                result += static_cast<char>(0x80 | (ch & 0x3F));
            } else {
                result += static_cast<char>(0xE0 | (ch >> 12));
                result += static_cast<char>(0x80 | ((ch >> 6) & 0x3F));
                result += static_cast<char>(0x80 | (ch & 0x3F));
            }
        }
        return result;
    }
}

bool ArscParser::parse_package(size_t offset, size_t size) {
    if (offset + 288 > data_.size()) return false;
    
    uint16_t header_size = read_le<uint16_t>(offset + 2);
    package_id_ = read_le<uint32_t>(offset + 8);
    
    // Read package name (128 chars, UTF-16)
    std::string pkg_name;
    for (int i = 0; i < 128; i++) {
        uint16_t ch = read_le<uint16_t>(offset + 12 + i * 2);
        if (ch == 0) break;
        if (ch < 128) pkg_name += static_cast<char>(ch);
    }
    package_name_ = pkg_name;
    
    uint32_t type_strings_offset = read_le<uint32_t>(offset + 268);
    uint32_t key_strings_offset = read_le<uint32_t>(offset + 276);
    
    // Parse type and key string pools
    std::vector<std::string> type_strings;
    std::vector<std::string> key_strings;
    
    size_t pkg_start = offset;
    
    // Parse chunks within package
    size_t chunk_offset = offset + header_size;
    std::string current_type;
    
    while (chunk_offset + 8 <= offset + size) {
        uint16_t chunk_type = read_le<uint16_t>(chunk_offset);
        uint16_t chunk_header_size = read_le<uint16_t>(chunk_offset + 2);
        uint32_t chunk_size = read_le<uint32_t>(chunk_offset + 4);
        
        if (chunk_size < 8 || chunk_offset + chunk_size > offset + size) break;
        
        switch (chunk_type) {
            case RES_STRING_POOL_TYPE: {
                // Parse as type or key strings based on position
                size_t rel_offset = chunk_offset - pkg_start;
                std::vector<std::string> pool_strings;
                
                uint32_t str_count = read_le<uint32_t>(chunk_offset + 8);
                uint32_t flags = read_le<uint32_t>(chunk_offset + 16);
                uint32_t str_start = read_le<uint32_t>(chunk_offset + 20);
                bool is_utf8 = (flags & UTF8_FLAG) != 0;
                
                size_t offsets_start = chunk_offset + chunk_header_size;
                size_t data_start = chunk_offset + str_start;
                
                for (uint32_t i = 0; i < str_count; i++) {
                    if (offsets_start + i * 4 + 4 > data_.size()) break;
                    uint32_t str_off = read_le<uint32_t>(offsets_start + i * 4);
                    std::string s = read_string_at(data_start + str_off, is_utf8);
                    pool_strings.push_back(s);
                }
                
                if (rel_offset == type_strings_offset) {
                    type_strings = pool_strings;
                } else if (rel_offset == key_strings_offset) {
                    key_strings = pool_strings;
                }
                break;
            }
            case RES_TABLE_TYPE_SPEC_TYPE: {
                uint8_t type_id = data_[chunk_offset + 8];
                if (type_id > 0 && type_id <= type_strings.size()) {
                    current_type = type_strings[type_id - 1];
                }
                break;
            }
            case RES_TABLE_TYPE_TYPE: {
                uint8_t type_id = data_[chunk_offset + 8];
                uint32_t entry_count = read_le<uint32_t>(chunk_offset + 12);
                uint32_t entries_start = read_le<uint32_t>(chunk_offset + 16);
                
                std::string type_name;
                if (type_id > 0 && type_id <= type_strings.size()) {
                    type_name = type_strings[type_id - 1];
                }
                
                size_t offsets_start = chunk_offset + chunk_header_size;
                size_t entries_data = chunk_offset + entries_start;
                // 该 type 块的配置限定符（variant）；ResTable_config 位于 chunk_offset+20。
                std::string type_config = config_to_string(chunk_offset + 20);
                
                for (uint32_t i = 0; i < entry_count; i++) {
                    if (offsets_start + i * 4 + 4 > data_.size()) break;
                    
                    uint32_t entry_offset = read_le<uint32_t>(offsets_start + i * 4);
                    if (entry_offset == 0xFFFFFFFF) continue;
                    
                    size_t entry_pos = entries_data + entry_offset;
                    if (entry_pos + 8 > data_.size()) continue;
                    
                    uint16_t entry_size = read_le<uint16_t>(entry_pos);
                    uint16_t entry_flags = read_le<uint16_t>(entry_pos + 2);
                    uint32_t key_index = read_le<uint32_t>(entry_pos + 4);
                    
                    ResourceEntry res;
                    res.id = (package_id_ << 24) | (type_id << 16) | i;
                    res.type = type_name;
                    res.package = package_name_;
                    res.config = type_config;
                    
                    if (key_index < key_strings.size()) {
                        res.name = key_strings[key_index];
                    }
                    
                    // Read value if simple entry
                    if (!(entry_flags & 0x0001) && entry_pos + entry_size + 8 <= data_.size()) {
                        size_t value_pos = entry_pos + 8;
                        uint8_t value_type = data_[value_pos + 3];
                        uint32_t value_data = read_le<uint32_t>(value_pos + 4);
                        
                        switch (value_type) {
                            case 0x03: // String
                                if (value_data < strings_.size()) {
                                    res.value = strings_[value_data];
                                }
                                break;
                            case 0x10: // Int dec
                                res.value = std::to_string(static_cast<int32_t>(value_data));
                                break;
                            case 0x11: // Int hex
                                res.value = "0x" + ([](uint32_t v) {
                                    char buf[16];
                                    snprintf(buf, sizeof(buf), "%08X", v);
                                    return std::string(buf);
                                })(value_data);
                                break;
                            case 0x12: // Boolean
                                res.value = value_data ? "true" : "false";
                                break;
                            case 0x1C: // Color
                            case 0x1D:
                            case 0x1E:
                            case 0x1F:
                                res.value = "#" + ([](uint32_t v) {
                                    char buf[16];
                                    snprintf(buf, sizeof(buf), "%08X", v);
                                    return std::string(buf);
                                })(value_data);
                                break;
                        }
                    }
                    
                    id_to_index_[res.id] = resources_.size();
                    resources_.push_back(res);
                }
                break;
            }
        }
        
        chunk_offset += chunk_size;
    }
    
    return true;
}

std::vector<StringResource> ArscParser::search_strings(const std::string& pattern) const {
    std::vector<StringResource> results;
    std::string lower_pattern = pattern;
    std::transform(lower_pattern.begin(), lower_pattern.end(), lower_pattern.begin(), ::tolower);
    
    for (size_t i = 0; i < strings_.size(); i++) {
        std::string lower_str = strings_[i];
        std::transform(lower_str.begin(), lower_str.end(), lower_str.begin(), ::tolower);
        
        if (lower_str.find(lower_pattern) != std::string::npos) {
            results.push_back({static_cast<uint32_t>(i), strings_[i]});
        }
    }
    
    return results;
}

std::vector<ResourceEntry> ArscParser::search_resources(const std::string& pattern, 
                                                         const std::string& type) const {
    std::vector<ResourceEntry> results;
    std::string lower_pattern = pattern;
    std::transform(lower_pattern.begin(), lower_pattern.end(), lower_pattern.begin(), ::tolower);
    
    for (const auto& res : resources_) {
        if (!type.empty() && res.type != type) continue;
        
        std::string lower_name = res.name;
        std::transform(lower_name.begin(), lower_name.end(), lower_name.begin(), ::tolower);
        
        std::string lower_value = res.value;
        std::transform(lower_value.begin(), lower_value.end(), lower_value.begin(), ::tolower);
        
        if (lower_name.find(lower_pattern) != std::string::npos ||
            lower_value.find(lower_pattern) != std::string::npos) {
            results.push_back(res);
        }
    }
    
    return results;
}

const ResourceEntry* ArscParser::get_resource(uint32_t id) const {
    auto it = id_to_index_.find(id);
    if (it != id_to_index_.end() && it->second < resources_.size()) {
        return &resources_[it->second];
    }
    return nullptr;
}

// ==================== 按 ID 读写 resources.arsc 值 ====================

static std::string value_type_name(uint8_t t) {
    switch (t) {
        case 0x00: return "null";
        case 0x01: return "reference";
        case 0x02: return "attribute";
        case 0x03: return "string";
        case 0x04: return "float";
        case 0x05: return "dimension";
        case 0x06: return "fraction";
        case 0x10: return "int_dec";
        case 0x11: return "int_hex";
        case 0x12: return "int_boolean";
        case 0x1C: return "int_color_argb8";
        case 0x1D: return "int_color_rgb8";
        case 0x1E: return "int_color_argb4";
        case 0x1F: return "int_color_rgb4";
        default:   return "unknown";
    }
}

std::string ArscParser::decode_value(uint8_t type, uint32_t data) const {
    char buf[32];
    switch (type) {
        case 0x03: // String
            return (data < strings_.size()) ? strings_[data] : std::string();
        case 0x10: // int dec
            return std::to_string(static_cast<int32_t>(data));
        case 0x11: // int hex
            snprintf(buf, sizeof(buf), "0x%08X", data);
            return buf;
        case 0x12: // boolean
            return data ? "true" : "false";
        case 0x1C: case 0x1D: case 0x1E: case 0x1F: // color
            snprintf(buf, sizeof(buf), "#%08X", data);
            return buf;
        case 0x01: // reference
            snprintf(buf, sizeof(buf), "@0x%08X", data);
            return buf;
        case 0x04: { // float
            float f;
            std::memcpy(&f, &data, sizeof(f));
            snprintf(buf, sizeof(buf), "%g", f);
            return buf;
        }
        default:
            snprintf(buf, sizeof(buf), "0x%08X", data);
            return buf;
    }
}

std::string ArscParser::config_to_string(size_t off) const {
    if (off + 4 > data_.size()) return "default";
    uint32_t cfg_size = read_le<uint32_t>(off);
    if (cfg_size == 0) return "default";

    std::vector<std::string> parts;
    // language (off+8), country (off+10): 2 ASCII chars each, 0 = absent.
    if (cfg_size >= 12 && off + 12 <= data_.size()) {
        char l0 = static_cast<char>(data_[off + 8]);
        char l1 = static_cast<char>(data_[off + 9]);
        std::string lang;
        if (l0 != 0 && (l0 & 0x80) == 0) { lang += l0; if (l1 != 0) lang += l1; }
        char c0 = static_cast<char>(data_[off + 10]);
        char c1 = static_cast<char>(data_[off + 11]);
        std::string country;
        if (c0 != 0 && (c0 & 0x80) == 0) { country += c0; if (c1 != 0) country += c1; }
        if (!lang.empty()) {
            parts.push_back(country.empty() ? lang : (lang + "-r" + country));
        }
    }
    // density (off+14, uint16)
    if (cfg_size >= 16 && off + 16 <= data_.size()) {
        uint16_t density = read_le<uint16_t>(off + 14);
        switch (density) {
            case 0: break;
            case 120: parts.push_back("ldpi"); break;
            case 160: parts.push_back("mdpi"); break;
            case 213: parts.push_back("tvdpi"); break;
            case 240: parts.push_back("hdpi"); break;
            case 320: parts.push_back("xhdpi"); break;
            case 480: parts.push_back("xxhdpi"); break;
            case 640: parts.push_back("xxxhdpi"); break;
            case 0xFFFE: parts.push_back("anydpi"); break;
            case 0xFFFF: parts.push_back("nodpi"); break;
            default: parts.push_back(std::to_string(density) + "dpi"); break;
        }
    }
    // sdkVersion (off+24, uint16)
    if (cfg_size >= 26 && off + 26 <= data_.size()) {
        uint16_t sdk = read_le<uint16_t>(off + 24);
        if (sdk != 0) parts.push_back("v" + std::to_string(sdk));
    }

    if (parts.empty()) return "default";
    std::string out;
    for (size_t i = 0; i < parts.size(); i++) {
        if (i) out += "-";
        out += parts[i];
    }
    return out;
}

std::vector<ArscParser::ConfigEntry> ArscParser::collect_config_entries(uint32_t id) const {
    std::vector<ConfigEntry> out;
    uint8_t want_pkg = static_cast<uint8_t>((id >> 24) & 0xFF);
    uint8_t want_type = static_cast<uint8_t>((id >> 16) & 0xFF);
    uint32_t want_entry = id & 0xFFFF;

    if (data_.size() < 12) return out;
    uint16_t table_header = read_le<uint16_t>(2);
    size_t offset = table_header;

    while (offset + 8 <= data_.size()) {
        uint16_t chunk_type = read_le<uint16_t>(offset);
        uint32_t chunk_size = read_le<uint32_t>(offset + 4);
        if (chunk_size < 8 || offset + chunk_size > data_.size()) break;

        if (chunk_type == RES_TABLE_PACKAGE_TYPE) {
            uint16_t pkg_header = read_le<uint16_t>(offset + 2);
            uint32_t pkg_id = read_le<uint32_t>(offset + 8);
            if (static_cast<uint8_t>(pkg_id & 0xFF) == want_pkg) {
                size_t c = offset + pkg_header;
                size_t pkg_end = offset + chunk_size;
                while (c + 8 <= pkg_end) {
                    uint16_t ct = read_le<uint16_t>(c);
                    uint16_t chs = read_le<uint16_t>(c + 2);
                    uint32_t cs = read_le<uint32_t>(c + 4);
                    if (cs < 8 || c + cs > pkg_end) break;

                    if (ct == RES_TABLE_TYPE_TYPE) {
                        uint8_t type_id = data_[c + 8];
                        if (type_id == want_type) {
                            uint32_t entry_count = read_le<uint32_t>(c + 12);
                            uint32_t entries_start = read_le<uint32_t>(c + 16);
                            size_t offsets_start = c + chs;
                            if (want_entry < entry_count &&
                                offsets_start + want_entry * 4 + 4 <= data_.size()) {
                                uint32_t eo = read_le<uint32_t>(offsets_start + want_entry * 4);
                                if (eo != 0xFFFFFFFF) {
                                    size_t entry_pos = c + entries_start + eo;
                                    if (entry_pos + 8 <= data_.size()) {
                                        uint16_t entry_size = read_le<uint16_t>(entry_pos);
                                        uint16_t entry_flags = read_le<uint16_t>(entry_pos + 2);
                                        ConfigEntry ce;
                                        ce.config = config_to_string(c + 20);
                                        ce.complex = (entry_flags & 0x0001) != 0;
                                        size_t vpos = entry_pos + entry_size;
                                        if (!ce.complex && vpos + 8 <= data_.size()) {
                                            ce.value_pos = vpos;
                                            ce.value_type = data_[vpos + 3];
                                            ce.value_data = read_le<uint32_t>(vpos + 4);
                                        } else {
                                            ce.value_pos = 0;
                                            ce.value_type = 0;
                                            ce.value_data = 0;
                                        }
                                        out.push_back(ce);
                                    }
                                }
                            }
                        }
                    }
                    c += cs;
                }
            }
        }
        offset += chunk_size;
    }
    return out;
}

std::string ArscParser::get_resource_value_json(uint32_t id) const {
    std::ostringstream oss;
    const ResourceEntry* meta = get_resource(id);
    auto entries = collect_config_entries(id);

    auto esc = [](const std::string& s) {
        std::string o;
        for (char c : s) {
            switch (c) {
                case '"': o += "\\\""; break;
                case '\\': o += "\\\\"; break;
                case '\n': o += "\\n"; break;
                case '\r': o += "\\r"; break;
                case '\t': o += "\\t"; break;
                default:
                    if (static_cast<unsigned char>(c) < 0x20) {
                        char b[8]; snprintf(b, sizeof(b), "\\u%04x", c); o += b;
                    } else o += c;
            }
        }
        return o;
    };

    char idbuf[16];
    snprintf(idbuf, sizeof(idbuf), "0x%08X", id);
    oss << "{\"id\":\"" << idbuf << "\"";
    oss << ",\"name\":\"" << (meta ? esc(meta->name) : "") << "\"";
    oss << ",\"type\":\"" << (meta ? esc(meta->type) : "") << "\"";
    oss << ",\"package\":\"" << (meta ? esc(meta->package) : "") << "\"";
    oss << ",\"found\":" << ((meta || !entries.empty()) ? "true" : "false");
    oss << ",\"configs\":[";
    for (size_t i = 0; i < entries.size(); i++) {
        const auto& e = entries[i];
        if (i) oss << ",";
        oss << "{\"config\":\"" << esc(e.config) << "\"";
        if (e.complex) {
            oss << ",\"complex\":true";
        } else {
            oss << ",\"valueType\":" << static_cast<int>(e.value_type);
            oss << ",\"valueTypeName\":\"" << value_type_name(e.value_type) << "\"";
            oss << ",\"value\":\"" << esc(decode_value(e.value_type, e.value_data)) << "\"";
        }
        oss << "}";
    }
    oss << "]}";
    return oss.str();
}

bool ArscParser::locate_global_pool(size_t& pool_off, size_t& pool_size, bool& is_utf8) const {
    if (data_.size() < 12) return false;
    uint16_t table_header = read_le<uint16_t>(2);
    size_t offset = table_header;
    while (offset + 8 <= data_.size()) {
        uint16_t chunk_type = read_le<uint16_t>(offset);
        uint32_t chunk_size = read_le<uint32_t>(offset + 4);
        if (chunk_size < 8 || offset + chunk_size > data_.size()) break;
        if (chunk_type == RES_STRING_POOL_TYPE) {
            pool_off = offset;
            pool_size = chunk_size;
            uint32_t flags = read_le<uint32_t>(offset + 16);
            is_utf8 = (flags & UTF8_FLAG) != 0;
            return true;
        }
        offset += chunk_size;
    }
    return false;
}

static void put_le16(std::vector<uint8_t>& v, uint16_t x) {
    v.push_back(x & 0xFF); v.push_back((x >> 8) & 0xFF);
}
static void put_le32(std::vector<uint8_t>& v, uint32_t x) {
    v.push_back(x & 0xFF); v.push_back((x >> 8) & 0xFF);
    v.push_back((x >> 16) & 0xFF); v.push_back((x >> 24) & 0xFF);
}

bool ArscParser::build_pool_with_string(const std::string& value, std::vector<uint8_t>& new_pool,
                                        uint32_t& index, std::string& error) const {
    size_t pool_off = 0, pool_size = 0;
    bool is_utf8 = false;
    if (!locate_global_pool(pool_off, pool_size, is_utf8)) {
        error = "global string pool not found";
        return false;
    }

    // Reuse an existing identical string if present.
    for (size_t i = 0; i < strings_.size(); i++) {
        if (strings_[i] == value) {
            index = static_cast<uint32_t>(i);
            new_pool.assign(data_.begin() + pool_off, data_.begin() + pool_off + pool_size);
            return true;  // pool unchanged
        }
    }

    uint16_t header_size = read_le<uint16_t>(pool_off + 2);
    uint32_t string_count = read_le<uint32_t>(pool_off + 8);
    uint32_t style_count = read_le<uint32_t>(pool_off + 12);
    uint32_t flags = read_le<uint32_t>(pool_off + 16);
    uint32_t strings_start = read_le<uint32_t>(pool_off + 20);
    uint32_t styles_start = read_le<uint32_t>(pool_off + 24);

    size_t str_region_start = pool_off + strings_start;
    size_t str_region_end;
    if (style_count > 0 && styles_start > 0) {
        str_region_end = pool_off + styles_start;
    } else {
        str_region_end = pool_off + pool_size;
    }
    if (str_region_start > data_.size() || str_region_end > data_.size() ||
        str_region_end < str_region_start) {
        error = "corrupt string pool bounds";
        return false;
    }

    // Preserve original string-data region verbatim; append the new entry.
    std::vector<uint8_t> orig_region(data_.begin() + str_region_start,
                                     data_.begin() + str_region_end);
    std::vector<uint8_t> appended;
    // Encode the new string in the pool's encoding.
    if (is_utf8) {
        size_t char_len = value.size();  // approx (bytes); AOSP tolerates >= actual
        auto put_utf8_len = [&](size_t len) {
            if (len > 0x7F) { appended.push_back(((len >> 8) & 0x7F) | 0x80); appended.push_back(len & 0xFF); }
            else appended.push_back(len & 0xFF);
        };
        put_utf8_len(char_len);
        put_utf8_len(value.size());
        appended.insert(appended.end(), value.begin(), value.end());
        appended.push_back(0);
    } else {
        // Decode UTF-8 input to UTF-16 code units.
        std::vector<uint16_t> u16;
        size_t i = 0;
        while (i < value.size()) {
            unsigned char c = value[i];
            uint32_t cp;
            if (c < 0x80) { cp = c; i += 1; }
            else if ((c >> 5) == 0x6 && i + 1 < value.size()) {
                cp = ((c & 0x1F) << 6) | (value[i+1] & 0x3F); i += 2;
            } else if ((c >> 4) == 0xE && i + 2 < value.size()) {
                cp = ((c & 0x0F) << 12) | ((value[i+1] & 0x3F) << 6) | (value[i+2] & 0x3F); i += 3;
            } else if ((c >> 3) == 0x1E && i + 3 < value.size()) {
                cp = ((c & 0x07) << 18) | ((value[i+1] & 0x3F) << 12) |
                     ((value[i+2] & 0x3F) << 6) | (value[i+3] & 0x3F); i += 4;
            } else { cp = c; i += 1; }
            if (cp > 0xFFFF) {
                cp -= 0x10000;
                u16.push_back(0xD800 | (cp >> 10));
                u16.push_back(0xDC00 | (cp & 0x3FF));
            } else {
                u16.push_back(static_cast<uint16_t>(cp));
            }
        }
        size_t char_len = u16.size();
        if (char_len > 0x7FFF) {
            appended.push_back(((char_len >> 16) & 0x7FFF) | 0x80);
            appended.push_back((char_len >> 24) & 0xFF);
        }
        appended.push_back(char_len & 0xFF);
        appended.push_back((char_len >> 8) & 0xFF);
        for (uint16_t u : u16) { appended.push_back(u & 0xFF); appended.push_back((u >> 8) & 0xFF); }
        appended.push_back(0); appended.push_back(0);
    }

    index = string_count;  // new string appended at the end
    uint32_t total_count = string_count + 1;

    // New offsets table (styles dropped on rebuild).
    std::vector<uint32_t> offsets(total_count);
    for (uint32_t i = 0; i < string_count; i++) {
        offsets[i] = read_le<uint32_t>(pool_off + header_size + i * 4);
    }
    offsets[string_count] = static_cast<uint32_t>(orig_region.size());

    uint32_t new_header = 28;
    uint32_t new_strings_offset = new_header + total_count * 4;
    size_t data_len = orig_region.size() + appended.size();
    size_t padding = (4 - (data_len % 4)) % 4;
    uint32_t total_size = new_strings_offset + static_cast<uint32_t>(data_len + padding);
    uint32_t new_flags = flags & ~SORTED_FLAG;

    new_pool.clear();
    put_le16(new_pool, RES_STRING_POOL_TYPE);
    put_le16(new_pool, new_header);
    put_le32(new_pool, total_size);
    put_le32(new_pool, total_count);
    put_le32(new_pool, 0);              // styleCount (styles dropped)
    put_le32(new_pool, new_flags);
    put_le32(new_pool, new_strings_offset);
    put_le32(new_pool, 0);              // stylesOffset
    for (uint32_t off : offsets) put_le32(new_pool, off);
    new_pool.insert(new_pool.end(), orig_region.begin(), orig_region.end());
    new_pool.insert(new_pool.end(), appended.begin(), appended.end());
    for (size_t i = 0; i < padding; i++) new_pool.push_back(0);
    return true;
}

static bool parse_scalar(const std::string& vt, const std::string& s,
                         uint8_t& out_type, uint32_t& out_data, std::string& error) {
    auto parse_u32 = [](const std::string& str, int base) -> uint32_t {
        return static_cast<uint32_t>(strtoll(str.c_str(), nullptr, base));
    };
    if (vt == "int") {
        out_type = 0x10;
        out_data = static_cast<uint32_t>(strtol(s.c_str(), nullptr, 10));
        return true;
    }
    if (vt == "hex") {
        out_type = 0x11;
        out_data = parse_u32(s, 16);
        return true;
    }
    if (vt == "bool") {
        out_type = 0x12;
        out_data = (s == "true" || s == "1") ? 0xFFFFFFFF : 0;
        return true;
    }
    if (vt == "color") {
        std::string h = s;
        if (!h.empty() && h[0] == '#') h = h.substr(1);
        if (h.size() == 6) h = "FF" + h;  // assume opaque if no alpha
        out_data = parse_u32(h, 16);
        out_type = 0x1C;
        return true;
    }
    if (vt == "reference") {
        std::string h = s;
        if (!h.empty() && h[0] == '@') h = h.substr(1);
        if (h.rfind("0x", 0) == 0 || h.rfind("0X", 0) == 0) h = h.substr(2);
        out_data = parse_u32(h, 16);
        out_type = 0x01;
        return true;
    }
    if (vt == "float") {
        float f = strtof(s.c_str(), nullptr);
        std::memcpy(&out_data, &f, sizeof(out_data));
        out_type = 0x04;
        return true;
    }
    error = "unsupported scalar value_type: " + vt;
    return false;
}

bool ArscParser::set_resource_value(uint32_t id, const std::string& config_filter,
                                    const std::string& value_type, const std::string& new_value,
                                    std::vector<uint8_t>& out, std::string& error) const {
    auto entries = collect_config_entries(id);
    if (entries.empty()) {
        error = "resource id not found or has no simple value";
        return false;
    }

    // Select target occurrences by config filter.
    std::vector<const ConfigEntry*> targets;
    std::string configs_list;
    for (const auto& e : entries) {
        if (!configs_list.empty()) configs_list += ", ";
        configs_list += e.config;
        if (config_filter.empty() || e.config == config_filter) targets.push_back(&e);
    }
    if (targets.empty()) {
        error = "config '" + config_filter + "' not found; available: " + configs_list;
        return false;
    }
    if (config_filter.empty() && targets.size() > 1) {
        error = "resource has multiple configs (" + configs_list +
                "); specify one via config";
        return false;
    }
    for (const auto* t : targets) {
        if (t->complex) { error = "complex/bag entry not settable"; return false; }
    }

    // Decide value type: explicit, or keep existing (single target).
    std::string vt = value_type;
    if (vt.empty() || vt == "auto") {
        uint8_t cur = targets[0]->value_type;
        if (cur == 0x03) vt = "string";
        else if (cur == 0x11) vt = "hex";
        else if (cur == 0x12) vt = "bool";
        else if (cur >= 0x1C && cur <= 0x1F) vt = "color";
        else if (cur == 0x01) vt = "reference";
        else if (cur == 0x04) vt = "float";
        else vt = "int";
    }

    if (vt == "string") {
        // Append/reuse in the global string pool and rebuild the file.
        size_t pool_off = 0, pool_size = 0;
        bool is_utf8 = false;
        if (!locate_global_pool(pool_off, pool_size, is_utf8)) {
            error = "global string pool not found";
            return false;
        }
        std::vector<uint8_t> new_pool;
        uint32_t index = 0;
        if (!build_pool_with_string(new_value, new_pool, index, error)) return false;

        long delta = static_cast<long>(new_pool.size()) - static_cast<long>(pool_size);

        out.clear();
        out.reserve(data_.size() + (delta > 0 ? delta : 0));
        // [0, pool_off) unchanged
        out.insert(out.end(), data_.begin(), data_.begin() + pool_off);
        // new pool
        out.insert(out.end(), new_pool.begin(), new_pool.end());
        // [pool_off+pool_size, end) copied verbatim
        out.insert(out.end(), data_.begin() + pool_off + pool_size, data_.end());

        // Patch table header total size (bytes 4..8).
        uint32_t new_total = static_cast<uint32_t>(out.size());
        out[4] = new_total & 0xFF;
        out[5] = (new_total >> 8) & 0xFF;
        out[6] = (new_total >> 16) & 0xFF;
        out[7] = (new_total >> 24) & 0xFF;

        // Patch each target entry's Res_value: type=string, data=index.
        // Value positions were in original data_ (after the pool), so shift by delta.
        for (const auto* t : targets) {
            size_t np = t->value_pos + delta;
            if (np + 8 > out.size()) { error = "value position out of range after rebuild"; return false; }
            out[np + 3] = 0x03;
            out[np + 4] = index & 0xFF;
            out[np + 5] = (index >> 8) & 0xFF;
            out[np + 6] = (index >> 16) & 0xFF;
            out[np + 7] = (index >> 24) & 0xFF;
        }
        return true;
    }

    // Scalar: in-place overwrite (no size change).
    uint8_t new_type = 0;
    uint32_t new_data = 0;
    if (!parse_scalar(vt, new_value, new_type, new_data, error)) return false;

    out = data_;
    for (const auto* t : targets) {
        size_t vp = t->value_pos;
        if (vp + 8 > out.size()) { error = "value position out of range"; return false; }
        out[vp + 3] = new_type;
        out[vp + 4] = new_data & 0xFF;
        out[vp + 5] = (new_data >> 8) & 0xFF;
        out[vp + 6] = (new_data >> 16) & 0xFF;
        out[vp + 7] = (new_data >> 24) & 0xFF;
    }
    return true;
}

std::string ArscParser::get_info() const {
    std::ostringstream oss;
    oss << "Package: " << package_name_ << "\n";
    oss << "Package ID: 0x" << std::hex << package_id_ << std::dec << "\n";
    oss << "String pool size: " << strings_.size() << "\n";
    oss << "Resource count: " << resources_.size() << "\n";
    
    // Count by type
    std::unordered_map<std::string, int> type_counts;
    for (const auto& res : resources_) {
        type_counts[res.type]++;
    }
    
    oss << "\nResources by type:\n";
    for (const auto& [type, count] : type_counts) {
        oss << "  " << type << ": " << count << "\n";
    }
    
    return oss.str();
}

} // namespace arsc
