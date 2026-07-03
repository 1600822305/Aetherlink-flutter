#include "xml/axml_parser.h"
#include <sstream>
#include <cstring>
#include <functional>

namespace axml {

static const uint16_t RES_NULL_TYPE = 0x0000;
static const uint16_t RES_STRING_POOL_TYPE = 0x0001;
static const uint16_t RES_TABLE_TYPE = 0x0002;
static const uint16_t RES_XML_TYPE = 0x0003;
static const uint16_t RES_XML_START_NAMESPACE_TYPE = 0x0100;
static const uint16_t RES_XML_END_NAMESPACE_TYPE = 0x0101;
static const uint16_t RES_XML_START_ELEMENT_TYPE = 0x0102;
static const uint16_t RES_XML_END_ELEMENT_TYPE = 0x0103;
static const uint16_t RES_XML_CDATA_TYPE = 0x0104;
static const uint16_t RES_XML_RESOURCE_MAP_TYPE = 0x0180;

// 类型常量直接使用 android_resources.h 中定义的 ResourceValueType 枚举

template<typename T>
static T read_le(const uint8_t* p) {
    T val = 0;
    for (size_t i = 0; i < sizeof(T); i++) {
        val |= static_cast<T>(p[i]) << (i * 8);
    }
    return val;
}

template<typename T>
static void write_le(uint8_t* p, T val) {
    for (size_t i = 0; i < sizeof(T); i++) {
        p[i] = static_cast<uint8_t>(val >> (i * 8));
    }
}

bool AxmlParser::parse(const std::vector<uint8_t>& data) {
    data_ = data;
    
    if (data_.size() < 8) return false;
    
    uint16_t type = read_le<uint16_t>(&data_[0]);
    uint16_t header_size = read_le<uint16_t>(&data_[2]);
    uint32_t file_size = read_le<uint32_t>(&data_[4]);
    
    if (type != RES_XML_TYPE) return false;
    if (file_size > data_.size()) return false;
    
    size_t offset = header_size;
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint16_t chunk_header_size = read_le<uint16_t>(&data_[offset + 2]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        switch (chunk_type) {
            case RES_STRING_POOL_TYPE:
                parse_string_pool(offset);
                break;
            case RES_XML_RESOURCE_MAP_TYPE:
                parse_resource_map(offset);
                break;
            case RES_XML_START_ELEMENT_TYPE:
            case RES_XML_END_ELEMENT_TYPE:
            case RES_XML_START_NAMESPACE_TYPE:
            case RES_XML_END_NAMESPACE_TYPE:
            case RES_XML_CDATA_TYPE:
                break;
        }
        
        offset += chunk_size;
    }
    
    parse_elements(offset);
    
    return true;
}

bool AxmlParser::parse_string_pool(size_t& offset) {
    if (offset + 28 > data_.size()) return false;
    
    uint32_t string_count = read_le<uint32_t>(&data_[offset + 8]);
    uint32_t style_count = read_le<uint32_t>(&data_[offset + 12]);
    uint32_t flags = read_le<uint32_t>(&data_[offset + 16]);
    uint32_t strings_start = read_le<uint32_t>(&data_[offset + 20]);
    uint32_t styles_start = read_le<uint32_t>(&data_[offset + 24]);
    
    bool is_utf8 = (flags & (1 << 8)) != 0;
    
    string_pool_.clear();
    string_pool_.reserve(string_count);
    
    size_t offsets_start = offset + 28;
    
    for (uint32_t i = 0; i < string_count; i++) {
        uint32_t string_offset = read_le<uint32_t>(&data_[offsets_start + i * 4]);
        size_t str_pos = offset + strings_start + string_offset;
        
        if (str_pos >= data_.size()) {
            string_pool_.push_back("");
            continue;
        }
        
        std::string str;
        if (is_utf8) {
            uint8_t len1 = data_[str_pos];
            str_pos++;
            if (len1 & 0x80) str_pos++;
            
            uint8_t len2 = data_[str_pos];
            str_pos++;
            if (len2 & 0x80) {
                len2 = ((len2 & 0x7F) << 8) | data_[str_pos];
                str_pos++;
            }
            
            if (str_pos + len2 <= data_.size()) {
                str = std::string(reinterpret_cast<const char*>(&data_[str_pos]), len2);
            }
        } else {
            uint16_t len = read_le<uint16_t>(&data_[str_pos]);
            str_pos += 2;
            if (len & 0x8000) {
                len = ((len & 0x7FFF) << 16) | read_le<uint16_t>(&data_[str_pos]);
                str_pos += 2;
            }
            
            for (uint16_t j = 0; j < len && str_pos + 2 <= data_.size(); j++) {
                uint16_t ch = read_le<uint16_t>(&data_[str_pos]);
                str_pos += 2;
                if (ch < 0x80) {
                    str += static_cast<char>(ch);
                } else if (ch < 0x800) {
                    str += static_cast<char>(0xC0 | (ch >> 6));
                    str += static_cast<char>(0x80 | (ch & 0x3F));
                } else {
                    str += static_cast<char>(0xE0 | (ch >> 12));
                    str += static_cast<char>(0x80 | ((ch >> 6) & 0x3F));
                    str += static_cast<char>(0x80 | (ch & 0x3F));
                }
            }
        }
        
        string_pool_.push_back(str);
    }
    
    return true;
}

bool AxmlParser::parse_resource_map(size_t& offset) {
    return true;
}

bool AxmlParser::parse_elements(size_t& offset) {
    std::vector<Element*> element_stack;
    
    size_t pos = 8;
    
    while (pos < data_.size()) {
        if (pos + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[pos]);
        uint16_t chunk_header_size = read_le<uint16_t>(&data_[pos + 2]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[pos + 4]);
        
        if (chunk_size == 0 || pos + chunk_size > data_.size()) break;
        
        if (chunk_type == RES_XML_START_ELEMENT_TYPE) {
            if (pos + 28 > data_.size()) break;
            
            uint32_t ns_idx = read_le<uint32_t>(&data_[pos + 16]);
            uint32_t name_idx = read_le<uint32_t>(&data_[pos + 20]);
            uint16_t attr_start = read_le<uint16_t>(&data_[pos + 24]);
            uint16_t attr_size = read_le<uint16_t>(&data_[pos + 26]);
            uint16_t attr_count = read_le<uint16_t>(&data_[pos + 28]);
            
            Element elem;
            if (ns_idx != 0xFFFFFFFF && ns_idx < string_pool_.size()) {
                elem.namespace_uri = string_pool_[ns_idx];
            }
            if (name_idx < string_pool_.size()) {
                elem.name = string_pool_[name_idx];
            }
            
            // Attributes start after: chunk header (16) + attr_start offset
            size_t attr_pos = pos + 16 + attr_start;
            for (uint16_t i = 0; i < attr_count && attr_pos + 20 <= data_.size(); i++) {
                Attribute attr;
                
                uint32_t attr_ns = read_le<uint32_t>(&data_[attr_pos]);
                uint32_t attr_name = read_le<uint32_t>(&data_[attr_pos + 4]);
                uint32_t attr_raw = read_le<uint32_t>(&data_[attr_pos + 8]);
                uint16_t attr_type = read_le<uint16_t>(&data_[attr_pos + 14]);
                uint32_t attr_data = read_le<uint32_t>(&data_[attr_pos + 16]);
                
                if (attr_ns != 0xFFFFFFFF && attr_ns < string_pool_.size()) {
                    attr.namespace_uri = string_pool_[attr_ns];
                }
                if (attr_name < string_pool_.size()) {
                    attr.name = string_pool_[attr_name];
                }
                
                attr.type = attr_type >> 8;
                attr.data = attr_data;
                
                if (attr_raw != 0xFFFFFFFF && attr_raw < string_pool_.size()) {
                    attr.value = string_pool_[attr_raw];
                } else {
                    switch (attr.type) {
                        case ResourceValueType::TYPE_STRING:
                            if (attr_data < string_pool_.size()) {
                                attr.value = string_pool_[attr_data];
                            }
                            break;
                        case ResourceValueType::TYPE_INT_DEC:
                            attr.value = std::to_string(static_cast<int32_t>(attr_data));
                            break;
                        case ResourceValueType::TYPE_INT_HEX: {
                            std::ostringstream ss;
                            ss << "0x" << std::hex << attr_data;
                            attr.value = ss.str();
                            break;
                        }
                        case ResourceValueType::TYPE_INT_BOOLEAN:
                            attr.value = attr_data ? "true" : "false";
                            break;
                        case ResourceValueType::TYPE_REFERENCE: {
                            std::ostringstream ss;
                            ss << "@0x" << std::hex << attr_data;
                            attr.value = ss.str();
                            break;
                        }
                        case ResourceValueType::TYPE_ATTRIBUTE: {
                            std::ostringstream ss;
                            ss << "?0x" << std::hex << attr_data;
                            attr.value = ss.str();
                            break;
                        }
                        case ResourceValueType::TYPE_DIMENSION:
                            attr.value = parse_complex_value(attr_data, false);
                            break;
                        case ResourceValueType::TYPE_FRACTION:
                            attr.value = parse_complex_value(attr_data, true);
                            break;
                        case ResourceValueType::TYPE_FLOAT: {
                            float f;
                            std::memcpy(&f, &attr_data, sizeof(f));
                            attr.value = std::to_string(f);
                            break;
                        }
                        case ResourceValueType::TYPE_INT_COLOR_ARGB8:
                        case ResourceValueType::TYPE_INT_COLOR_RGB8:
                        case ResourceValueType::TYPE_INT_COLOR_ARGB4:
                        case ResourceValueType::TYPE_INT_COLOR_RGB4:
                            attr.value = format_color(attr_data, attr.type);
                            break;
                        default:
                            attr.value = std::to_string(attr_data);
                            break;
                    }
                }
                
                elem.attributes.push_back(attr);
                attr_pos += attr_size > 0 ? attr_size : 20;
            }
            
            if (element_stack.empty()) {
                root_ = elem;
                element_stack.push_back(&root_);
            } else {
                element_stack.back()->children.push_back(elem);
                element_stack.push_back(&element_stack.back()->children.back());
            }
        } else if (chunk_type == RES_XML_END_ELEMENT_TYPE) {
            if (!element_stack.empty()) {
                element_stack.pop_back();
            }
        }
        
        pos += chunk_size;
    }
    
    return true;
}

std::string AxmlParser::to_xml(int indent) const {
    return element_to_xml(root_, indent);
}

std::string AxmlParser::element_to_xml(const Element& elem, int indent) const {
    std::stringstream ss;
    std::string ind(indent * 2, ' ');
    
    ss << ind << "<" << elem.name;
    
    for (const auto& attr : elem.attributes) {
        ss << " ";
        if (!attr.namespace_uri.empty()) {
            size_t pos = attr.namespace_uri.rfind('/');
            if (pos != std::string::npos) {
                ss << attr.namespace_uri.substr(pos + 1) << ":";
            }
        }
        ss << attr.name << "=\"" << attr.value << "\"";
    }
    
    if (elem.children.empty() && elem.text.empty()) {
        ss << "/>\n";
    } else {
        ss << ">\n";
        
        for (const auto& child : elem.children) {
            ss << element_to_xml(child, indent + 1);
        }
        
        if (!elem.text.empty()) {
            ss << ind << "  " << elem.text << "\n";
        }
        
        ss << ind << "</" << elem.name << ">\n";
    }
    
    return ss.str();
}

std::string AxmlParser::get_attribute_value(const Element& elem, const std::string& name) const {
    for (const auto& attr : elem.attributes) {
        if (attr.name == name) {
            return attr.value;
        }
    }
    return "";
}

std::string AxmlParser::get_package_name() const {
    return get_attribute_value(root_, "package");
}

std::string AxmlParser::get_version_name() const {
    return get_attribute_value(root_, "versionName");
}

int AxmlParser::get_version_code() const {
    std::string val = get_attribute_value(root_, "versionCode");
    return val.empty() ? 0 : std::stoi(val);
}

std::string AxmlParser::get_min_sdk() const {
    for (const auto& child : root_.children) {
        if (child.name == "uses-sdk") {
            return get_attribute_value(child, "minSdkVersion");
        }
    }
    return "";
}

std::string AxmlParser::get_target_sdk() const {
    for (const auto& child : root_.children) {
        if (child.name == "uses-sdk") {
            return get_attribute_value(child, "targetSdkVersion");
        }
    }
    return "";
}

std::vector<std::string> AxmlParser::get_permissions() const {
    std::vector<std::string> perms;
    for (const auto& child : root_.children) {
        if (child.name == "uses-permission") {
            std::string name = get_attribute_value(child, "name");
            if (!name.empty()) {
                perms.push_back(name);
            }
        }
    }
    return perms;
}

std::vector<std::string> AxmlParser::get_activities() const {
    std::vector<std::string> activities;
    for (const auto& child : root_.children) {
        if (child.name == "application") {
            for (const auto& app_child : child.children) {
                if (app_child.name == "activity") {
                    std::string name = get_attribute_value(app_child, "name");
                    if (!name.empty()) {
                        activities.push_back(name);
                    }
                }
            }
        }
    }
    return activities;
}

std::vector<std::string> AxmlParser::get_services() const {
    std::vector<std::string> services;
    for (const auto& child : root_.children) {
        if (child.name == "application") {
            for (const auto& app_child : child.children) {
                if (app_child.name == "service") {
                    std::string name = get_attribute_value(app_child, "name");
                    if (!name.empty()) {
                        services.push_back(name);
                    }
                }
            }
        }
    }
    return services;
}

std::vector<std::string> AxmlParser::get_receivers() const {
    std::vector<std::string> receivers;
    for (const auto& child : root_.children) {
        if (child.name == "application") {
            for (const auto& app_child : child.children) {
                if (app_child.name == "receiver") {
                    std::string name = get_attribute_value(app_child, "name");
                    if (!name.empty()) {
                        receivers.push_back(name);
                    }
                }
            }
        }
    }
    return receivers;
}

std::string AxmlParser::get_info() const {
    std::stringstream ss;
    
    ss << "AndroidManifest Info:\n";
    ss << "  Package: " << get_package_name() << "\n";
    ss << "  Version Name: " << get_version_name() << "\n";
    ss << "  Version Code: " << get_version_code() << "\n";
    ss << "  Min SDK: " << get_min_sdk() << "\n";
    ss << "  Target SDK: " << get_target_sdk() << "\n";
    
    auto perms = get_permissions();
    ss << "  Permissions: " << perms.size() << "\n";
    for (const auto& p : perms) {
        ss << "    - " << p << "\n";
    }
    
    auto activities = get_activities();
    ss << "  Activities: " << activities.size() << "\n";
    
    auto services = get_services();
    ss << "  Services: " << services.size() << "\n";
    
    auto receivers = get_receivers();
    ss << "  Receivers: " << receivers.size() << "\n";
    
    return ss.str();
}

bool AxmlEditor::load(const std::vector<uint8_t>& data) {
    data_ = data;
    return parse_internal();
}

bool AxmlEditor::parse_internal() {
    if (data_.size() < 8) return false;
    
    uint16_t type = read_le<uint16_t>(&data_[0]);
    if (type != 0x0003) return false;
    
    size_t offset = 8;
    string_pool_.clear();
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        if (chunk_type == 0x0001) {
            chunk_info_.string_pool_offset = offset;
            chunk_info_.string_pool_size = chunk_size;
            
            uint32_t string_count = read_le<uint32_t>(&data_[offset + 8]);
            uint32_t flags = read_le<uint32_t>(&data_[offset + 16]);
            uint32_t strings_start = read_le<uint32_t>(&data_[offset + 20]);
            bool is_utf8 = (flags & (1 << 8)) != 0;
            
            size_t offsets_start = offset + 28;
            
            for (uint32_t i = 0; i < string_count; i++) {
                uint32_t str_offset = read_le<uint32_t>(&data_[offsets_start + i * 4]);
                size_t str_pos = offset + strings_start + str_offset;
                
                std::string str;
                if (str_pos < data_.size()) {
                    if (is_utf8) {
                        str_pos++;
                        if (str_pos < data_.size() && (data_[str_pos - 1] & 0x80)) str_pos++;
                        uint8_t len = data_[str_pos++];
                        if (len & 0x80) {
                            len = ((len & 0x7F) << 8) | data_[str_pos++];
                        }
                        if (str_pos + len <= data_.size()) {
                            str = std::string(reinterpret_cast<const char*>(&data_[str_pos]), len);
                        }
                    } else {
                        uint16_t len = read_le<uint16_t>(&data_[str_pos]);
                        str_pos += 2;
                        for (uint16_t j = 0; j < len && str_pos + 2 <= data_.size(); j++) {
                            uint16_t ch = read_le<uint16_t>(&data_[str_pos]);
                            str_pos += 2;
                            if (ch < 0x80) str += static_cast<char>(ch);
                            else if (ch < 0x800) {
                                str += static_cast<char>(0xC0 | (ch >> 6));
                                str += static_cast<char>(0x80 | (ch & 0x3F));
                            } else {
                                str += static_cast<char>(0xE0 | (ch >> 12));
                                str += static_cast<char>(0x80 | ((ch >> 6) & 0x3F));
                                str += static_cast<char>(0x80 | (ch & 0x3F));
                            }
                        }
                    }
                }
                string_pool_.push_back(str);
            }
        } else if (chunk_type == 0x0180) {
            chunk_info_.resource_map_offset = offset;
            chunk_info_.resource_map_size = chunk_size;
            // 解析资源ID映射表
            resource_ids_.clear();
            size_t res_count = (chunk_size - 8) / 4;
            for (size_t i = 0; i < res_count && offset + 8 + i * 4 + 4 <= data_.size(); i++) {
                uint32_t res_id = read_le<uint32_t>(&data_[offset + 8 + i * 4]);
                resource_ids_.push_back(res_id);
            }
        } else if (chunk_type == 0x0102) {
            chunk_info_.xml_content_offset = offset;
            break;
        }
        
        offset += chunk_size;
    }
    
    AxmlParser parser;
    if (parser.parse(data_)) {
        root_ = parser.root();
        return true;
    }
    return false;
}

std::vector<uint8_t> AxmlEditor::save() {
    rebuild_binary();
    return data_;
}

void AxmlEditor::search_element(const Element& elem, const std::string& path, int& index,
                                 const std::string& attr_name, const std::string& value_pattern,
                                 std::vector<SearchResult>& results) const {
    std::string current_path = path.empty() ? elem.name : path + "/" + elem.name;
    
    for (const auto& attr : elem.attributes) {
        bool match = false;
        if (!attr_name.empty() && !value_pattern.empty()) {
            match = (attr.name.find(attr_name) != std::string::npos) && 
                    (attr.value.find(value_pattern) != std::string::npos);
        } else if (!attr_name.empty()) {
            match = attr.name.find(attr_name) != std::string::npos;
        } else if (!value_pattern.empty()) {
            match = attr.value.find(value_pattern) != std::string::npos;
        }
        
        if (match) {
            SearchResult r;
            r.element_path = current_path;
            r.element_name = elem.name;
            r.attribute_name = attr.name;
            r.attribute_value = attr.value;
            r.element_index = index;
            results.push_back(r);
        }
    }
    
    index++;
    
    for (const auto& child : elem.children) {
        search_element(child, current_path, index, attr_name, value_pattern, results);
    }
}

std::vector<SearchResult> AxmlEditor::search_by_attribute(const std::string& attr_name, const std::string& value_pattern) const {
    std::vector<SearchResult> results;
    int index = 0;
    search_element(root_, "", index, attr_name, value_pattern, results);
    return results;
}

std::vector<SearchResult> AxmlEditor::search_by_element(const std::string& element_name) const {
    std::vector<SearchResult> results;
    
    std::function<void(const Element&, const std::string&, int&)> search_fn;
    search_fn = [&](const Element& elem, const std::string& path, int& index) {
        std::string current_path = path.empty() ? elem.name : path + "/" + elem.name;
        
        if (elem.name.find(element_name) != std::string::npos) {
            for (const auto& attr : elem.attributes) {
                SearchResult r;
                r.element_path = current_path;
                r.element_name = elem.name;
                r.attribute_name = attr.name;
                r.attribute_value = attr.value;
                r.element_index = index;
                results.push_back(r);
            }
        }
        
        index++;
        for (const auto& child : elem.children) {
            search_fn(child, current_path, index);
        }
    };
    
    int index = 0;
    search_fn(root_, "", index);
    return results;
}

std::vector<SearchResult> AxmlEditor::search_by_value(const std::string& value_pattern) const {
    return search_by_attribute("", value_pattern);
}

bool AxmlEditor::set_attribute(const std::string& element_path, const std::string& attr_name, const std::string& new_value) {
    // 智能解析 new_value 的类型
    bool is_int = false;
    int32_t int_value = 0;
    bool is_bool = false;
    bool bool_value = false;
    bool is_color = false;
    uint32_t color_data = 0;
    uint8_t color_type = 0;
    bool is_dimension = false;
    bool is_fraction = false;
    uint32_t complex_data = 0;
    
    // 检查布尔值
    if (new_value == "true" || new_value == "false") {
        is_bool = true;
        bool_value = (new_value == "true");
    }
    // 检查颜色值 #RRGGBB 或 #AARRGGBB
    else if (parse_color_string(new_value, color_data, color_type)) {
        is_color = true;
    }
    // 检查尺寸值 (dp, sp, px, pt, in, mm)
    else if (encode_complex_value(new_value, complex_data, is_dimension)) {
        is_fraction = !is_dimension;
    }
    // 检查整数
    else {
        try {
            size_t pos;
            long long parsed = std::stoll(new_value, &pos);
            if (pos == new_value.length()) {
                is_int = true;
                int_value = static_cast<int32_t>(parsed);
            }
        } catch (...) {
            is_int = false;
        }
    }
    
    // 记录原始字符串池大小
    size_t original_pool_size = string_pool_.size();
    int new_string_idx = -1;
    
    // 对于字符串类型的值，需要添加到字符串池
    if (!is_int) {
        new_string_idx = find_or_add_string(new_value);
        
        // 如果添加了新字符串，需要重建字符串池
        bool need_rebuild = (string_pool_.size() > original_pool_size);
        if (need_rebuild) {
            rebuild_binary();
        }
    }
    
    size_t offset = chunk_info_.xml_content_offset;
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        if (chunk_type == 0x0102) {
            uint32_t name_idx = read_le<uint32_t>(&data_[offset + 20]);
            std::string elem_name = (name_idx < string_pool_.size()) ? string_pool_[name_idx] : "";
            
            // 元素匹配：精确匹配或路径包含元素名（元素名不能为空）
            bool elem_match = element_path.empty() || 
                              (elem_name == element_path) ||
                              (!elem_name.empty() && element_path.find(elem_name) != std::string::npos);
            
            if (elem_match) {
                uint16_t attr_count = read_le<uint16_t>(&data_[offset + 28]);
                uint16_t attr_start = read_le<uint16_t>(&data_[offset + 24]);
                uint16_t attr_size = 20;
                
                // Attributes start after: chunk header (16) + attr_start offset
                size_t attr_pos = offset + 16 + attr_start;
                for (uint16_t i = 0; i < attr_count && attr_pos + 20 <= data_.size(); i++) {
                    uint32_t attr_name_idx = read_le<uint32_t>(&data_[attr_pos + 4]);
                    std::string current_attr_name = (attr_name_idx < string_pool_.size()) ? string_pool_[attr_name_idx] : "";
                    
                    // 尝试通过资源ID映射获取属性名
                    std::string res_attr_name;
                    if (attr_name_idx < resource_ids_.size()) {
                        const char* res_name = get_android_attr_name(resource_ids_[attr_name_idx]);
                        if (res_name) {
                            res_attr_name = res_name;
                        }
                    }
                    
                    // 匹配：字符串池名称或资源ID映射名称
                    bool name_match = (current_attr_name == attr_name) || 
                                      (!res_attr_name.empty() && res_attr_name == attr_name);
                    
                    if (name_match) {
                        uint16_t attr_type_field = read_le<uint16_t>(&data_[attr_pos + 14]);
                        uint8_t attr_type = attr_type_field >> 8;
                        
                        // 根据原始属性类型决定如何修改
                        if (attr_type == ResourceValueType::TYPE_STRING) {
                            // 字符串类型：修改 rawValue 和 data 为新字符串索引
                            if (new_string_idx < 0) {
                                new_string_idx = find_or_add_string(new_value);
                                if (string_pool_.size() > original_pool_size) {
                                    rebuild_binary();
                                    return set_attribute(element_path, attr_name, new_value);
                                }
                            }
                            write_le<uint32_t>(&data_[attr_pos + 8], static_cast<uint32_t>(new_string_idx));
                            write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(new_string_idx));
                        } else if (attr_type == ResourceValueType::TYPE_INT_DEC || attr_type == ResourceValueType::TYPE_INT_HEX) {
                            // 整数类型
                            if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else if (new_value.length() > 2 && (new_value.substr(0, 2) == "0x" || new_value.substr(0, 2) == "0X")) {
                                try {
                                    uint32_t hex_val = std::stoul(new_value, nullptr, 16);
                                    write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                    write_le<uint32_t>(&data_[attr_pos + 16], hex_val);
                                } catch (...) {
                                    return false;
                                }
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_INT_BOOLEAN) {
                            // 布尔类型
                            bool bval = (new_value == "true" || new_value == "1" || (is_int && int_value != 0));
                            write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                            write_le<uint32_t>(&data_[attr_pos + 16], bval ? 0xFFFFFFFF : 0);
                        } else if (attr_type == ResourceValueType::TYPE_REFERENCE || attr_type == ResourceValueType::TYPE_ATTRIBUTE) {
                            // 资源引用类型 @resource 或 ?attr
                            if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else if (!new_value.empty() && (new_value[0] == '@' || new_value[0] == '?')) {
                                try {
                                    uint32_t res_id = std::stoul(new_value.substr(1), nullptr, 0);
                                    write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                    write_le<uint32_t>(&data_[attr_pos + 16], res_id);
                                } catch (...) {
                                    return false;
                                }
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_DIMENSION) {
                            // 尺寸类型 (dp, sp, px, pt, in, mm)
                            uint32_t dim_data = 0;
                            bool is_dim = false;
                            if (encode_complex_value(new_value, dim_data, is_dim)) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], dim_data);
                            } else if (is_int) {
                                // 整数作为像素处理
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value) << 8);
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_FRACTION) {
                            // 百分比类型 (%, %p)
                            uint32_t frac_data = 0;
                            bool is_dim = false;
                            if (encode_complex_value(new_value, frac_data, is_dim)) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], frac_data);
                            } else {
                                return false;
                            }
                        } else if (attr_type >= ResourceValueType::TYPE_INT_COLOR_ARGB8 && attr_type <= ResourceValueType::TYPE_INT_COLOR_RGB4) {
                            // 颜色类型
                            uint32_t clr_data = 0;
                            uint8_t clr_type = 0;
                            if (parse_color_string(new_value, clr_data, clr_type)) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], clr_data);
                            } else if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_FLOAT) {
                            // 浮点类型
                            try {
                                float fval = std::stof(new_value);
                                uint32_t fdata;
                                std::memcpy(&fdata, &fval, sizeof(fdata));
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], fdata);
                            } catch (...) {
                                return false;
                            }
                        } else {
                            // 其他类型：智能处理
                            if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else {
                                if (new_string_idx < 0) {
                                    new_string_idx = find_or_add_string(new_value);
                                    if (string_pool_.size() > original_pool_size) {
                                        rebuild_binary();
                                        return set_attribute(element_path, attr_name, new_value);
                                    }
                                }
                                write_le<uint32_t>(&data_[attr_pos + 8], static_cast<uint32_t>(new_string_idx));
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(new_string_idx));
                            }
                        }
                        
                        parse_internal();
                        return true;
                    }
                    attr_pos += attr_size;
                }
            }
        }
        
        offset += chunk_size;
    }
    
    return false;
}

bool AxmlEditor::set_attribute_by_index(int element_index, const std::string& attr_name, const std::string& new_value) {
    // 智能解析 new_value 的类型
    bool is_int = false;
    int32_t int_value = 0;
    
    // 检查整数
    try {
        size_t pos;
        long long parsed = std::stoll(new_value, &pos);
        if (pos == new_value.length()) {
            is_int = true;
            int_value = static_cast<int32_t>(parsed);
        }
    } catch (...) {
        is_int = false;
    }
    
    // 记录原始字符串池大小
    size_t original_pool_size = string_pool_.size();
    int new_string_idx = -1;
    
    // 对于纯字符串类型的值，需要添加到字符串池
    if (!is_int) {
        new_string_idx = find_or_add_string(new_value);
        
        // 如果添加了新字符串，需要重建字符串池
        bool need_rebuild = (string_pool_.size() > original_pool_size);
        if (need_rebuild) {
            rebuild_binary();
        }
    }
    
    int current_index = 0;
    size_t offset = chunk_info_.xml_content_offset;
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        if (chunk_type == 0x0102) {
            if (current_index == element_index) {
                uint16_t attr_count = read_le<uint16_t>(&data_[offset + 28]);
                uint16_t attr_start = read_le<uint16_t>(&data_[offset + 24]);
                uint16_t attr_size = 20;
                
                size_t attr_pos = offset + 16 + attr_start;
                for (uint16_t i = 0; i < attr_count && attr_pos + 20 <= data_.size(); i++) {
                    uint32_t attr_name_idx = read_le<uint32_t>(&data_[attr_pos + 4]);
                    std::string current_attr_name = (attr_name_idx < string_pool_.size()) ? string_pool_[attr_name_idx] : "";
                    
                    // 尝试通过资源ID映射获取属性名
                    std::string res_attr_name;
                    if (attr_name_idx < resource_ids_.size()) {
                        const char* res_name = get_android_attr_name(resource_ids_[attr_name_idx]);
                        if (res_name) {
                            res_attr_name = res_name;
                        }
                    }
                    
                    // 匹配：字符串池名称或资源ID映射名称
                    bool name_match = (current_attr_name == attr_name) || 
                                      (!res_attr_name.empty() && res_attr_name == attr_name);
                    
                    if (name_match) {
                        uint16_t attr_type_field = read_le<uint16_t>(&data_[attr_pos + 14]);
                        uint8_t attr_type = attr_type_field >> 8;
                        
                        // 根据原始属性类型决定如何修改
                        if (attr_type == ResourceValueType::TYPE_STRING) {
                            if (new_string_idx < 0) {
                                new_string_idx = find_or_add_string(new_value);
                                if (string_pool_.size() > original_pool_size) {
                                    rebuild_binary();
                                    return set_attribute_by_index(element_index, attr_name, new_value);
                                }
                            }
                            write_le<uint32_t>(&data_[attr_pos + 8], static_cast<uint32_t>(new_string_idx));
                            write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(new_string_idx));
                        } else if (attr_type == ResourceValueType::TYPE_INT_DEC || attr_type == ResourceValueType::TYPE_INT_HEX) {
                            if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else if (new_value.length() > 2 && (new_value.substr(0, 2) == "0x" || new_value.substr(0, 2) == "0X")) {
                                try {
                                    uint32_t hex_val = std::stoul(new_value, nullptr, 16);
                                    write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                    write_le<uint32_t>(&data_[attr_pos + 16], hex_val);
                                } catch (...) {
                                    return false;
                                }
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_INT_BOOLEAN) {
                            bool bval = (new_value == "true" || new_value == "1" || (is_int && int_value != 0));
                            write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                            write_le<uint32_t>(&data_[attr_pos + 16], bval ? 0xFFFFFFFF : 0);
                        } else if (attr_type == ResourceValueType::TYPE_REFERENCE || attr_type == ResourceValueType::TYPE_ATTRIBUTE) {
                            if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else if (!new_value.empty() && (new_value[0] == '@' || new_value[0] == '?')) {
                                try {
                                    uint32_t res_id = std::stoul(new_value.substr(1), nullptr, 0);
                                    write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                    write_le<uint32_t>(&data_[attr_pos + 16], res_id);
                                } catch (...) {
                                    return false;
                                }
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_DIMENSION) {
                            uint32_t dim_data = 0;
                            bool is_dim = false;
                            if (encode_complex_value(new_value, dim_data, is_dim)) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], dim_data);
                            } else if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value) << 8);
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_FRACTION) {
                            uint32_t frac_data = 0;
                            bool is_dim = false;
                            if (encode_complex_value(new_value, frac_data, is_dim)) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], frac_data);
                            } else {
                                return false;
                            }
                        } else if (attr_type >= ResourceValueType::TYPE_INT_COLOR_ARGB8 && attr_type <= ResourceValueType::TYPE_INT_COLOR_RGB4) {
                            uint32_t clr_data = 0;
                            uint8_t clr_type = 0;
                            if (parse_color_string(new_value, clr_data, clr_type)) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], clr_data);
                            } else if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else {
                                return false;
                            }
                        } else if (attr_type == ResourceValueType::TYPE_FLOAT) {
                            try {
                                float fval = std::stof(new_value);
                                uint32_t fdata;
                                std::memcpy(&fdata, &fval, sizeof(fdata));
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], fdata);
                            } catch (...) {
                                return false;
                            }
                        } else {
                            if (is_int) {
                                write_le<uint32_t>(&data_[attr_pos + 8], 0xFFFFFFFF);
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(int_value));
                            } else {
                                if (new_string_idx < 0) {
                                    new_string_idx = find_or_add_string(new_value);
                                    if (string_pool_.size() > original_pool_size) {
                                        rebuild_binary();
                                        return set_attribute_by_index(element_index, attr_name, new_value);
                                    }
                                }
                                write_le<uint32_t>(&data_[attr_pos + 8], static_cast<uint32_t>(new_string_idx));
                                write_le<uint32_t>(&data_[attr_pos + 16], static_cast<uint32_t>(new_string_idx));
                            }
                        }
                        
                        parse_internal();
                        return true;
                    }
                    attr_pos += attr_size;
                }
            }
            current_index++;
        }
        
        offset += chunk_size;
    }
    
    return false;
}

bool AxmlEditor::set_package_name(const std::string& name) {
    return set_attribute("manifest", "package", name);
}

bool AxmlEditor::set_version_name(const std::string& name) {
    return set_attribute("manifest", "versionName", name);
}

bool AxmlEditor::set_version_code(int code) {
    return set_attribute("manifest", "versionCode", std::to_string(code));
}

bool AxmlEditor::set_min_sdk(int sdk) {
    // 先搜索uses-sdk元素的索引
    auto results = search_by_attribute("minSdkVersion", "");
    for (const auto& r : results) {
        if (r.element_name == "uses-sdk") {
            return set_attribute_by_index(r.element_index, "minSdkVersion", std::to_string(sdk));
        }
    }
    return set_attribute("uses-sdk", "minSdkVersion", std::to_string(sdk));
}

bool AxmlEditor::set_target_sdk(int sdk) {
    // 先搜索uses-sdk元素的索引
    auto results = search_by_attribute("targetSdkVersion", "");
    for (const auto& r : results) {
        if (r.element_name == "uses-sdk") {
            return set_attribute_by_index(r.element_index, "targetSdkVersion", std::to_string(sdk));
        }
    }
    return set_attribute("uses-sdk", "targetSdkVersion", std::to_string(sdk));
}

bool AxmlEditor::add_permission(const std::string& permission) {
    // Android namespace URI
    const std::string android_ns = "http://schemas.android.com/apk/res/android";
    
    // Add required strings to string pool
    int name_attr_idx = find_or_add_string("name");
    int perm_value_idx = find_or_add_string(permission);
    int uses_perm_idx = find_or_add_string("uses-permission");
    int android_ns_idx = find_or_add_string(android_ns);
    
    // Rebuild string pool after adding new strings
    rebuild_binary();
    
    // Find the position right after <manifest> opening tag (after first RES_XML_START_ELEMENT_TYPE)
    size_t insert_offset = 0;
    size_t offset = chunk_info_.xml_content_offset;
    bool found_manifest = false;
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        if (chunk_type == 0x0102) { // RES_XML_START_ELEMENT_TYPE
            uint32_t name_idx = read_le<uint32_t>(&data_[offset + 20]);
            if (name_idx < string_pool_.size() && string_pool_[name_idx] == "manifest") {
                insert_offset = offset + chunk_size;
                found_manifest = true;
                break;
            }
        }
        
        offset += chunk_size;
    }
    
    if (!found_manifest) return false;
    
    // Create uses-permission element
    // Start element chunk: header(16) + extended(20) + attrs(attr_count * 20)
    std::vector<uint8_t> start_elem(16 + 20 + 20); // 56 bytes total, 1 attribute
    
    // Chunk header
    write_le<uint16_t>(&start_elem[0], 0x0102); // RES_XML_START_ELEMENT_TYPE
    write_le<uint16_t>(&start_elem[2], 16);     // header size
    write_le<uint32_t>(&start_elem[4], static_cast<uint32_t>(start_elem.size())); // chunk size
    
    // Extended header
    write_le<uint32_t>(&start_elem[8], 1);       // line number
    write_le<uint32_t>(&start_elem[12], 0xFFFFFFFF); // comment (none)
    
    // Element info
    write_le<uint32_t>(&start_elem[16], 0xFFFFFFFF); // namespace (none)
    write_le<uint32_t>(&start_elem[20], uses_perm_idx); // name
    write_le<uint16_t>(&start_elem[24], 0x14);  // attribute start (20 bytes after element start)
    write_le<uint16_t>(&start_elem[26], 0x14);  // attribute size (20 bytes per attr)
    write_le<uint16_t>(&start_elem[28], 1);     // attribute count
    write_le<uint16_t>(&start_elem[30], 0);     // id index
    write_le<uint16_t>(&start_elem[32], 0);     // class index
    write_le<uint16_t>(&start_elem[34], 0);     // style index
    
    // Attribute: android:name="permission"
    size_t attr_offset = 36;
    write_le<uint32_t>(&start_elem[attr_offset + 0], android_ns_idx);  // namespace
    write_le<uint32_t>(&start_elem[attr_offset + 4], name_attr_idx);   // name (index of "name")
    write_le<uint32_t>(&start_elem[attr_offset + 8], perm_value_idx);  // rawValue (string index)
    write_le<uint16_t>(&start_elem[attr_offset + 12], 8);              // size
    write_le<uint8_t>(&start_elem[attr_offset + 14], 0);               // res0
    write_le<uint8_t>(&start_elem[attr_offset + 15], 0x03);            // dataType: TYPE_STRING
    write_le<uint32_t>(&start_elem[attr_offset + 16], perm_value_idx); // data (string index)
    
    // End element chunk
    std::vector<uint8_t> end_elem(24);
    write_le<uint16_t>(&end_elem[0], 0x0103);   // RES_XML_END_ELEMENT_TYPE
    write_le<uint16_t>(&end_elem[2], 16);       // header size
    write_le<uint32_t>(&end_elem[4], 24);       // chunk size
    write_le<uint32_t>(&end_elem[8], 1);        // line number
    write_le<uint32_t>(&end_elem[12], 0xFFFFFFFF); // comment
    write_le<uint32_t>(&end_elem[16], 0xFFFFFFFF); // namespace (none)
    write_le<uint32_t>(&end_elem[20], uses_perm_idx); // name
    
    // Insert both chunks
    std::vector<uint8_t> new_data;
    new_data.reserve(data_.size() + start_elem.size() + end_elem.size());
    
    new_data.insert(new_data.end(), data_.begin(), data_.begin() + insert_offset);
    new_data.insert(new_data.end(), start_elem.begin(), start_elem.end());
    new_data.insert(new_data.end(), end_elem.begin(), end_elem.end());
    new_data.insert(new_data.end(), data_.begin() + insert_offset, data_.end());
    
    // Update file size in header
    uint32_t new_file_size = static_cast<uint32_t>(new_data.size());
    write_le<uint32_t>(&new_data[4], new_file_size);
    
    data_ = std::move(new_data);
    
    // Re-parse to update internal state
    parse_internal();
    
    return true;
}

bool AxmlEditor::remove_permission(const std::string& permission) {
    size_t offset = chunk_info_.xml_content_offset;
    size_t perm_start = 0;
    size_t perm_end = 0;
    bool found = false;
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        if (chunk_type == 0x0102) { // RES_XML_START_ELEMENT_TYPE
            uint32_t name_idx = read_le<uint32_t>(&data_[offset + 20]);
            if (name_idx < string_pool_.size() && string_pool_[name_idx] == "uses-permission") {
                // Check if this is the permission we're looking for
                uint16_t attr_count = read_le<uint16_t>(&data_[offset + 28]);
                uint16_t attr_start = read_le<uint16_t>(&data_[offset + 24]);
                
                // Attributes start after: chunk header (16) + element info start + attr_start offset
                size_t attr_pos = offset + 16 + attr_start;
                for (uint16_t i = 0; i < attr_count && attr_pos + 20 <= data_.size(); i++) {
                    uint32_t attr_name_idx = read_le<uint32_t>(&data_[attr_pos + 4]);
                    uint32_t attr_value_idx = read_le<uint32_t>(&data_[attr_pos + 8]);
                    
                    if (attr_name_idx < string_pool_.size() && string_pool_[attr_name_idx] == "name" &&
                        attr_value_idx < string_pool_.size() && string_pool_[attr_value_idx] == permission) {
                        perm_start = offset;
                        found = true;
                        break;
                    }
                    attr_pos += 20;
                }
                
                if (found) {
                    // Find the matching end element
                    size_t search_offset = offset + chunk_size;
                    while (search_offset < data_.size()) {
                        if (search_offset + 8 > data_.size()) break;
                        
                        uint16_t search_type = read_le<uint16_t>(&data_[search_offset]);
                        uint32_t search_size = read_le<uint32_t>(&data_[search_offset + 4]);
                        
                        if (search_type == 0x0103) { // RES_XML_END_ELEMENT_TYPE
                            uint32_t end_name_idx = read_le<uint32_t>(&data_[search_offset + 20]);
                            if (end_name_idx == name_idx) {
                                perm_end = search_offset + search_size;
                                break;
                            }
                        }
                        search_offset += search_size;
                    }
                    break;
                }
            }
        }
        
        offset += chunk_size;
    }
    
    if (!found || perm_end <= perm_start) return false;
    
    // Remove the element
    std::vector<uint8_t> new_data;
    new_data.reserve(data_.size() - (perm_end - perm_start));
    
    new_data.insert(new_data.end(), data_.begin(), data_.begin() + perm_start);
    new_data.insert(new_data.end(), data_.begin() + perm_end, data_.end());
    
    // Update file size
    uint32_t new_file_size = static_cast<uint32_t>(new_data.size());
    write_le<uint32_t>(&new_data[4], new_file_size);
    
    data_ = std::move(new_data);
    
    // Re-parse
    parse_internal();
    
    return true;
}

bool AxmlEditor::add_activity(const std::string& activity_name, bool exported) {
    const std::string android_ns = "http://schemas.android.com/apk/res/android";
    
    // Add required strings
    int name_attr_idx = find_or_add_string("name");
    int exported_attr_idx = find_or_add_string("exported");
    int activity_value_idx = find_or_add_string(activity_name);
    int activity_tag_idx = find_or_add_string("activity");
    int application_idx = find_or_add_string("application");
    int android_ns_idx = find_or_add_string(android_ns);
    
    // Rebuild string pool
    rebuild_binary();
    
    // Find application element's end position (insert before </application>)
    size_t insert_offset = 0;
    size_t offset = chunk_info_.xml_content_offset;
    bool in_application = false;
    int depth = 0;
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        if (chunk_type == 0x0102) { // Start element
            uint32_t name_idx = read_le<uint32_t>(&data_[offset + 20]);
            if (name_idx < string_pool_.size() && string_pool_[name_idx] == "application") {
                in_application = true;
                depth = 1;
            } else if (in_application) {
                depth++;
            }
        } else if (chunk_type == 0x0103) { // End element
            if (in_application) {
                depth--;
                if (depth == 0) {
                    // This is </application>
                    insert_offset = offset;
                    break;
                }
            }
        }
        
        offset += chunk_size;
    }
    
    if (insert_offset == 0) return false;
    
    // Create activity element with 2 attributes: name and exported
    std::vector<uint8_t> start_elem(16 + 20 + 40); // header + ext + 2 attrs
    
    write_le<uint16_t>(&start_elem[0], 0x0102);
    write_le<uint16_t>(&start_elem[2], 16);
    write_le<uint32_t>(&start_elem[4], static_cast<uint32_t>(start_elem.size()));
    write_le<uint32_t>(&start_elem[8], 1);
    write_le<uint32_t>(&start_elem[12], 0xFFFFFFFF);
    write_le<uint32_t>(&start_elem[16], 0xFFFFFFFF);
    write_le<uint32_t>(&start_elem[20], activity_tag_idx);
    write_le<uint16_t>(&start_elem[24], 0x14);
    write_le<uint16_t>(&start_elem[26], 0x14);
    write_le<uint16_t>(&start_elem[28], 2);
    write_le<uint16_t>(&start_elem[30], 0);
    write_le<uint16_t>(&start_elem[32], 0);
    write_le<uint16_t>(&start_elem[34], 0);
    
    // Attr 1: android:name
    size_t attr_offset = 36;
    write_le<uint32_t>(&start_elem[attr_offset + 0], android_ns_idx);
    write_le<uint32_t>(&start_elem[attr_offset + 4], name_attr_idx);
    write_le<uint32_t>(&start_elem[attr_offset + 8], activity_value_idx);
    write_le<uint16_t>(&start_elem[attr_offset + 12], 8);
    write_le<uint8_t>(&start_elem[attr_offset + 14], 0);
    write_le<uint8_t>(&start_elem[attr_offset + 15], 0x03);
    write_le<uint32_t>(&start_elem[attr_offset + 16], activity_value_idx);
    
    // Attr 2: android:exported
    attr_offset += 20;
    write_le<uint32_t>(&start_elem[attr_offset + 0], android_ns_idx);
    write_le<uint32_t>(&start_elem[attr_offset + 4], exported_attr_idx);
    write_le<uint32_t>(&start_elem[attr_offset + 8], 0xFFFFFFFF);
    write_le<uint16_t>(&start_elem[attr_offset + 12], 8);
    write_le<uint8_t>(&start_elem[attr_offset + 14], 0);
    write_le<uint8_t>(&start_elem[attr_offset + 15], 0x12);  // TYPE_INT_BOOLEAN
    write_le<uint32_t>(&start_elem[attr_offset + 16], exported ? 0xFFFFFFFF : 0);
    
    // End element
    std::vector<uint8_t> end_elem(24);
    write_le<uint16_t>(&end_elem[0], 0x0103);
    write_le<uint16_t>(&end_elem[2], 16);
    write_le<uint32_t>(&end_elem[4], 24);
    write_le<uint32_t>(&end_elem[8], 1);
    write_le<uint32_t>(&end_elem[12], 0xFFFFFFFF);
    write_le<uint32_t>(&end_elem[16], 0xFFFFFFFF);
    write_le<uint32_t>(&end_elem[20], activity_tag_idx);
    
    // Insert
    std::vector<uint8_t> new_data;
    new_data.reserve(data_.size() + start_elem.size() + end_elem.size());
    new_data.insert(new_data.end(), data_.begin(), data_.begin() + insert_offset);
    new_data.insert(new_data.end(), start_elem.begin(), start_elem.end());
    new_data.insert(new_data.end(), end_elem.begin(), end_elem.end());
    new_data.insert(new_data.end(), data_.begin() + insert_offset, data_.end());
    
    write_le<uint32_t>(&new_data[4], static_cast<uint32_t>(new_data.size()));
    data_ = std::move(new_data);
    
    parse_internal();
    return true;
}

bool AxmlEditor::remove_activity(const std::string& activity_name) {
    size_t offset = chunk_info_.xml_content_offset;
    size_t activity_start = 0;
    size_t activity_end = 0;
    bool found = false;
    int depth = 0;
    
    while (offset < data_.size()) {
        if (offset + 8 > data_.size()) break;
        
        uint16_t chunk_type = read_le<uint16_t>(&data_[offset]);
        uint32_t chunk_size = read_le<uint32_t>(&data_[offset + 4]);
        
        if (chunk_size == 0 || offset + chunk_size > data_.size()) break;
        
        if (chunk_type == 0x0102) { // Start element
            if (!found) {
                uint32_t name_idx = read_le<uint32_t>(&data_[offset + 20]);
                if (name_idx < string_pool_.size() && string_pool_[name_idx] == "activity") {
                    // Check android:name attribute
                    uint16_t attr_count = read_le<uint16_t>(&data_[offset + 28]);
                    uint16_t attr_start = read_le<uint16_t>(&data_[offset + 24]);
                    
                    // Attributes start after: chunk header (16) + element info start + attr_start offset
                    size_t attr_pos = offset + 16 + attr_start;
                    for (uint16_t i = 0; i < attr_count && attr_pos + 20 <= data_.size(); i++) {
                        uint32_t attr_name_idx = read_le<uint32_t>(&data_[attr_pos + 4]);
                        uint32_t attr_value_idx = read_le<uint32_t>(&data_[attr_pos + 8]);
                        
                        if (attr_name_idx < string_pool_.size() && string_pool_[attr_name_idx] == "name" &&
                            attr_value_idx < string_pool_.size() && string_pool_[attr_value_idx] == activity_name) {
                            activity_start = offset;
                            found = true;
                            depth = 1;
                            break;
                        }
                        attr_pos += 20;
                    }
                }
            } else {
                depth++;
            }
        } else if (chunk_type == 0x0103) { // End element
            if (found) {
                depth--;
                if (depth == 0) {
                    activity_end = offset + chunk_size;
                    break;
                }
            }
        }
        
        offset += chunk_size;
    }
    
    if (!found || activity_end <= activity_start) return false;
    
    std::vector<uint8_t> new_data;
    new_data.reserve(data_.size() - (activity_end - activity_start));
    new_data.insert(new_data.end(), data_.begin(), data_.begin() + activity_start);
    new_data.insert(new_data.end(), data_.begin() + activity_end, data_.end());
    
    write_le<uint32_t>(&new_data[4], static_cast<uint32_t>(new_data.size()));
    data_ = std::move(new_data);
    
    parse_internal();
    return true;
}

bool AxmlEditor::add_element(const std::string& parent_path, const std::string& element_name,
                             const std::vector<std::pair<std::string, std::string>>& attributes) {
    // Generic add element - similar logic to add_activity
    // This is a simplified implementation
    return false; // TODO: implement full generic version
}

bool AxmlEditor::remove_element(const std::string& element_path) {
    // Generic remove element - similar logic to remove_activity
    return false; // TODO: implement full generic version
}

int AxmlEditor::find_or_add_string(const std::string& str) {
    for (size_t i = 0; i < string_pool_.size(); i++) {
        if (string_pool_[i] == str) {
            return static_cast<int>(i);
        }
    }
    string_pool_.push_back(str);
    return static_cast<int>(string_pool_.size() - 1);
}

// 计算 UTF-8 字符串的 Unicode 字符数量
static size_t utf8_char_count(const std::string& str) {
    size_t count = 0;
    size_t i = 0;
    while (i < str.length()) {
        uint8_t c = static_cast<uint8_t>(str[i]);
        if ((c & 0x80) == 0) {
            // ASCII: 0xxxxxxx
            i += 1;
        } else if ((c & 0xE0) == 0xC0) {
            // 2字节序列: 110xxxxx 10xxxxxx
            i += 2;
        } else if ((c & 0xF0) == 0xE0) {
            // 3字节序列: 1110xxxx 10xxxxxx 10xxxxxx
            i += 3;
        } else if ((c & 0xF8) == 0xF0) {
            // 4字节序列: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
            i += 4;
        } else {
            // 无效的 UTF-8，按单字节处理
            i += 1;
        }
        count++;
    }
    return count;
}

// 将 UTF-8 字符串转换为 UTF-16LE 编码
static std::vector<uint16_t> utf8_to_utf16(const std::string& str) {
    std::vector<uint16_t> result;
    size_t i = 0;
    while (i < str.length()) {
        uint32_t codepoint = 0;
        uint8_t c = static_cast<uint8_t>(str[i]);
        
        if ((c & 0x80) == 0) {
            codepoint = c;
            i += 1;
        } else if ((c & 0xE0) == 0xC0) {
            codepoint = (c & 0x1F) << 6;
            if (i + 1 < str.length()) {
                codepoint |= (static_cast<uint8_t>(str[i + 1]) & 0x3F);
            }
            i += 2;
        } else if ((c & 0xF0) == 0xE0) {
            codepoint = (c & 0x0F) << 12;
            if (i + 1 < str.length()) {
                codepoint |= (static_cast<uint8_t>(str[i + 1]) & 0x3F) << 6;
            }
            if (i + 2 < str.length()) {
                codepoint |= (static_cast<uint8_t>(str[i + 2]) & 0x3F);
            }
            i += 3;
        } else if ((c & 0xF8) == 0xF0) {
            codepoint = (c & 0x07) << 18;
            if (i + 1 < str.length()) {
                codepoint |= (static_cast<uint8_t>(str[i + 1]) & 0x3F) << 12;
            }
            if (i + 2 < str.length()) {
                codepoint |= (static_cast<uint8_t>(str[i + 2]) & 0x3F) << 6;
            }
            if (i + 3 < str.length()) {
                codepoint |= (static_cast<uint8_t>(str[i + 3]) & 0x3F);
            }
            i += 4;
        } else {
            i += 1;
            continue;
        }
        
        // 转换为 UTF-16
        if (codepoint <= 0xFFFF) {
            result.push_back(static_cast<uint16_t>(codepoint));
        } else {
            // 使用代理对表示超过 BMP 的字符
            codepoint -= 0x10000;
            result.push_back(static_cast<uint16_t>(0xD800 | (codepoint >> 10)));
            result.push_back(static_cast<uint16_t>(0xDC00 | (codepoint & 0x3FF)));
        }
    }
    return result;
}

bool AxmlEditor::rebuild_binary() {
    if (data_.size() < 8) return false;
    
    bool is_utf8 = true;
    if (chunk_info_.string_pool_offset + 16 < data_.size()) {
        uint32_t flags = read_le<uint32_t>(&data_[chunk_info_.string_pool_offset + 16]);
        is_utf8 = (flags & (1 << 8)) != 0;
    }
    
    std::vector<uint8_t> string_data;
    std::vector<uint32_t> string_offsets;
    
    for (const auto& str : string_pool_) {
        string_offsets.push_back(static_cast<uint32_t>(string_data.size()));
        
        if (is_utf8) {
            // UTF-8 编码格式:
            // - 字符长度 (1或2字节): Unicode 字符数量
            // - 字节长度 (1或2字节): UTF-8 字节数
            // - UTF-8 字符串数据
            // - null 终止符
            size_t char_len = utf8_char_count(str);
            size_t byte_len = str.length();
            
            // 写入字符长度
            if (char_len < 128) {
                string_data.push_back(static_cast<uint8_t>(char_len));
            } else {
                string_data.push_back(static_cast<uint8_t>((char_len >> 8) | 0x80));
                string_data.push_back(static_cast<uint8_t>(char_len & 0xFF));
            }
            
            // 写入字节长度
            if (byte_len < 128) {
                string_data.push_back(static_cast<uint8_t>(byte_len));
            } else {
                string_data.push_back(static_cast<uint8_t>((byte_len >> 8) | 0x80));
                string_data.push_back(static_cast<uint8_t>(byte_len & 0xFF));
            }
            
            // 写入 UTF-8 字符串数据
            for (char c : str) {
                string_data.push_back(static_cast<uint8_t>(c));
            }
            // null 终止符
            string_data.push_back(0);
        } else {
            // UTF-16LE 编码格式:
            // - 字符长度 (2或4字节): UTF-16 单元数量
            // - UTF-16LE 字符串数据
            // - null 终止符 (2字节)
            std::vector<uint16_t> utf16_str = utf8_to_utf16(str);
            uint32_t len = static_cast<uint32_t>(utf16_str.size());
            
            // 写入长度
            if (len < 0x8000) {
                // 短字符串格式: 2字节长度
                string_data.push_back(static_cast<uint8_t>(len & 0xFF));
                string_data.push_back(static_cast<uint8_t>((len >> 8) & 0x7F));
            } else {
                // 长字符串格式: 4字节长度，高位设置 0x8000 标志
                uint16_t high = static_cast<uint16_t>((len >> 16) & 0x7FFF) | 0x8000;
                uint16_t low = static_cast<uint16_t>(len & 0xFFFF);
                string_data.push_back(static_cast<uint8_t>(high & 0xFF));
                string_data.push_back(static_cast<uint8_t>(high >> 8));
                string_data.push_back(static_cast<uint8_t>(low & 0xFF));
                string_data.push_back(static_cast<uint8_t>(low >> 8));
            }
            
            // 写入 UTF-16LE 数据
            for (uint16_t ch : utf16_str) {
                string_data.push_back(static_cast<uint8_t>(ch & 0xFF));
                string_data.push_back(static_cast<uint8_t>(ch >> 8));
            }
            // null 终止符
            string_data.push_back(0);
            string_data.push_back(0);
        }
    }
    
    while (string_data.size() % 4 != 0) {
        string_data.push_back(0);
    }
    
    uint32_t header_size = 28;
    uint32_t offsets_size = static_cast<uint32_t>(string_pool_.size() * 4);
    uint32_t strings_start = header_size + offsets_size;
    uint32_t new_chunk_size = strings_start + static_cast<uint32_t>(string_data.size());
    
    std::vector<uint8_t> new_string_pool(new_chunk_size);
    
    write_le<uint16_t>(&new_string_pool[0], 0x0001);
    write_le<uint16_t>(&new_string_pool[2], static_cast<uint16_t>(header_size));
    write_le<uint32_t>(&new_string_pool[4], new_chunk_size);
    write_le<uint32_t>(&new_string_pool[8], static_cast<uint32_t>(string_pool_.size()));
    write_le<uint32_t>(&new_string_pool[12], 0);
    write_le<uint32_t>(&new_string_pool[16], is_utf8 ? 0x100 : 0);
    write_le<uint32_t>(&new_string_pool[20], strings_start);
    write_le<uint32_t>(&new_string_pool[24], 0);
    
    for (size_t i = 0; i < string_offsets.size(); i++) {
        write_le<uint32_t>(&new_string_pool[header_size + i * 4], string_offsets[i]);
    }
    
    std::memcpy(&new_string_pool[strings_start], string_data.data(), string_data.size());
    
    int32_t size_diff = static_cast<int32_t>(new_chunk_size) - static_cast<int32_t>(chunk_info_.string_pool_size);
    
    std::vector<uint8_t> new_data;
    new_data.reserve(data_.size() + size_diff);
    
    new_data.insert(new_data.end(), data_.begin(), data_.begin() + chunk_info_.string_pool_offset);
    new_data.insert(new_data.end(), new_string_pool.begin(), new_string_pool.end());
    new_data.insert(new_data.end(), 
                    data_.begin() + chunk_info_.string_pool_offset + chunk_info_.string_pool_size,
                    data_.end());
    
    uint32_t new_file_size = static_cast<uint32_t>(new_data.size());
    write_le<uint32_t>(&new_data[4], new_file_size);
    
    data_ = std::move(new_data);
    
    chunk_info_.string_pool_size = new_chunk_size;
    if (chunk_info_.resource_map_offset > chunk_info_.string_pool_offset) {
        chunk_info_.resource_map_offset += size_diff;
    }
    if (chunk_info_.xml_content_offset > chunk_info_.string_pool_offset) {
        chunk_info_.xml_content_offset += size_diff;
    }
    
    return true;
}

} // namespace axml
