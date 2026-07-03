#include "arsc/arsc_parser.h"
#include <fstream>
#include <algorithm>
#include <cstring>
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
