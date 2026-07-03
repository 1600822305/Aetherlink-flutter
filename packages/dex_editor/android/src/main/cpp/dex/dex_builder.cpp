#include "dex/dex_builder.h"
#include <fstream>
#include <algorithm>
#include <cstring>
#include <sstream>

namespace dex {

template<typename T>
static void write_le(std::vector<uint8_t>& out, T val) {
    for (size_t i = 0; i < sizeof(T); i++) {
        out.push_back(static_cast<uint8_t>(val >> (i * 8)));
    }
}

template<typename T>
static T read_le(const uint8_t* p) {
    T val = 0;
    for (size_t i = 0; i < sizeof(T); i++) {
        val |= static_cast<T>(p[i]) << (i * 8);
    }
    return val;
}

// Prototype implementation
std::string Prototype::to_string() const {
    std::string result = "(";
    for (const auto& p : param_types) {
        result += p;
    }
    result += ")" + return_type;
    return result;
}

// ClassBuilder implementation
ClassBuilder& ClassBuilder::add_field(const std::string& name, const std::string& type, uint32_t flags) {
    instance_fields.push_back({name, type, flags});
    return *this;
}

ClassBuilder& ClassBuilder::add_static_field(const std::string& name, const std::string& type, uint32_t flags) {
    static_fields.push_back({name, type, flags});
    return *this;
}

ClassBuilder& ClassBuilder::add_method(const MethodDef& method) {
    if (method.access_flags & (ACC_STATIC | ACC_PRIVATE | ACC_CONSTRUCTOR)) {
        direct_methods.push_back(method);
    } else {
        virtual_methods.push_back(method);
    }
    return *this;
}

MethodDef& ClassBuilder::create_method(const std::string& name, const Prototype& proto, uint32_t flags) {
    MethodDef method;
    method.name = name;
    method.prototype = proto;
    method.access_flags = flags;
    method.registers_size = 1;
    method.ins_size = 0;
    method.outs_size = 0;
    
    if (flags & (ACC_STATIC | ACC_PRIVATE | ACC_CONSTRUCTOR)) {
        direct_methods.push_back(method);
        return direct_methods.back();
    } else {
        virtual_methods.push_back(method);
        return virtual_methods.back();
    }
}

// DexBuilder implementation
DexBuilder::DexBuilder() {
    // Add default strings that are commonly needed
}

bool DexBuilder::load(const std::vector<uint8_t>& data) {
    if (data.size() < sizeof(DexHeader)) return false;
    
    DexHeader header;
    std::memcpy(&header, data.data(), sizeof(DexHeader));
    
    if (std::memcmp(header.magic, "dex\n", 4) != 0) return false;
    
    original_data_ = data;
    has_original_ = true;
    
    // Parse string pool
    for (uint32_t i = 0; i < header.string_ids_size; i++) {
        uint32_t str_off = read_le<uint32_t>(&data[header.string_ids_off + i * 4]);
        
        // Read ULEB128 length
        size_t pos = str_off;
        uint32_t len = 0;
        int shift = 0;
        while (pos < data.size()) {
            uint8_t b = data[pos++];
            len |= (b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift += 7;
        }
        
        std::string str(reinterpret_cast<const char*>(&data[pos]), len);
        strings_.push_back(str);
        string_map_[str] = i;
    }
    
    // Parse type pool
    for (uint32_t i = 0; i < header.type_ids_size; i++) {
        uint32_t str_idx = read_le<uint32_t>(&data[header.type_ids_off + i * 4]);
        if (str_idx < strings_.size()) {
            types_.push_back(strings_[str_idx]);
            type_map_[strings_[str_idx]] = i;
        }
    }
    
    // Parse proto pool
    for (uint32_t i = 0; i < header.proto_ids_size; i++) {
        size_t off = header.proto_ids_off + i * 12;
        ProtoId proto;
        proto.shorty_idx = read_le<uint32_t>(&data[off]);
        proto.return_type_idx = read_le<uint32_t>(&data[off + 4]);
        uint32_t params_off = read_le<uint32_t>(&data[off + 8]);
        
        if (params_off != 0 && params_off + 4 <= data.size()) {
            uint32_t param_count = read_le<uint32_t>(&data[params_off]);
            for (uint32_t j = 0; j < param_count && params_off + 4 + (j + 1) * 2 <= data.size(); j++) {
                uint16_t type_idx = read_le<uint16_t>(&data[params_off + 4 + j * 2]);
                proto.param_type_idxs.push_back(type_idx);
            }
        }
        
        protos_.push_back(proto);
        
        // Build proto string for map
        std::string proto_str = "(";
        for (auto idx : proto.param_type_idxs) {
            if (idx < types_.size()) proto_str += types_[idx];
        }
        proto_str += ")";
        if (proto.return_type_idx < types_.size()) {
            proto_str += types_[proto.return_type_idx];
        }
        proto_map_[proto_str] = i;
    }
    
    // Parse field pool
    for (uint32_t i = 0; i < header.field_ids_size; i++) {
        size_t off = header.field_ids_off + i * 8;
        FieldId field;
        field.class_idx = read_le<uint16_t>(&data[off]);
        field.type_idx = read_le<uint16_t>(&data[off + 2]);
        field.name_idx = read_le<uint32_t>(&data[off + 4]);
        fields_.push_back(field);
        
        std::string field_key;
        if (field.class_idx < types_.size()) field_key += types_[field.class_idx];
        field_key += "->";
        if (field.name_idx < strings_.size()) field_key += strings_[field.name_idx];
        field_key += ":";
        if (field.type_idx < types_.size()) field_key += types_[field.type_idx];
        field_map_[field_key] = i;
    }
    
    // Parse method pool
    for (uint32_t i = 0; i < header.method_ids_size; i++) {
        size_t off = header.method_ids_off + i * 8;
        MethodId method;
        method.class_idx = read_le<uint16_t>(&data[off]);
        method.proto_idx = read_le<uint16_t>(&data[off + 2]);
        method.name_idx = read_le<uint32_t>(&data[off + 4]);
        methods_.push_back(method);
        
        std::string method_key;
        if (method.class_idx < types_.size()) method_key += types_[method.class_idx];
        method_key += "->";
        if (method.name_idx < strings_.size()) method_key += strings_[method.name_idx];
        if (method.proto_idx < protos_.size()) {
            const auto& proto = protos_[method.proto_idx];
            method_key += "(";
            for (auto idx : proto.param_type_idxs) {
                if (idx < types_.size()) method_key += types_[idx];
            }
            method_key += ")";
            if (proto.return_type_idx < types_.size()) {
                method_key += types_[proto.return_type_idx];
            }
        }
        method_map_[method_key] = i;
    }
    
    return true;
}

bool DexBuilder::load(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) return false;
    
    file.seekg(0, std::ios::end);
    size_t size = file.tellg();
    file.seekg(0, std::ios::beg);
    
    std::vector<uint8_t> data(size);
    file.read(reinterpret_cast<char*>(data.data()), size);
    
    return load(data);
}

ClassBuilder& DexBuilder::make_class(const std::string& class_name) {
    auto it = class_map_.find(class_name);
    if (it != class_map_.end()) {
        return classes_[it->second];
    }
    
    classes_.emplace_back(class_name);
    class_map_[class_name] = classes_.size() - 1;
    
    // Ensure class type is in type pool
    get_or_add_type(class_name);
    
    return classes_.back();
}

ClassBuilder* DexBuilder::get_class(const std::string& class_name) {
    auto it = class_map_.find(class_name);
    if (it != class_map_.end()) {
        return &classes_[it->second];
    }
    return nullptr;
}

bool DexBuilder::add_method(const std::string& class_name, const MethodDef& method) {
    ClassBuilder* cls = get_class(class_name);
    if (!cls) {
        cls = &make_class(class_name);
    }
    cls->add_method(method);
    return true;
}

bool DexBuilder::modify_method(const std::string& class_name, const std::string& method_name,
                                const std::string& new_prototype, const std::vector<uint8_t>& new_code) {
    ClassBuilder* cls = get_class(class_name);
    if (!cls) return false;
    
    // Find and modify method
    for (auto& m : cls->direct_methods) {
        if (m.name == method_name) {
            // Parse new prototype
            // Format: (params)return
            size_t paren_end = new_prototype.find(')');
            if (paren_end != std::string::npos) {
                m.prototype.return_type = new_prototype.substr(paren_end + 1);
                m.prototype.param_types.clear();
                
                std::string params = new_prototype.substr(1, paren_end - 1);
                size_t i = 0;
                while (i < params.size()) {
                    if (params[i] == 'L') {
                        size_t end = params.find(';', i);
                        if (end != std::string::npos) {
                            m.prototype.param_types.push_back(params.substr(i, end - i + 1));
                            i = end + 1;
                        } else break;
                    } else if (params[i] == '[') {
                        size_t start = i;
                        while (i < params.size() && params[i] == '[') i++;
                        if (i < params.size()) {
                            if (params[i] == 'L') {
                                size_t end = params.find(';', i);
                                if (end != std::string::npos) {
                                    m.prototype.param_types.push_back(params.substr(start, end - start + 1));
                                    i = end + 1;
                                } else break;
                            } else {
                                m.prototype.param_types.push_back(params.substr(start, i - start + 1));
                                i++;
                            }
                        }
                    } else {
                        m.prototype.param_types.push_back(std::string(1, params[i]));
                        i++;
                    }
                }
            }
            m.code = new_code;
            return true;
        }
    }
    
    for (auto& m : cls->virtual_methods) {
        if (m.name == method_name) {
            // Same logic as above
            size_t paren_end = new_prototype.find(')');
            if (paren_end != std::string::npos) {
                m.prototype.return_type = new_prototype.substr(paren_end + 1);
                m.prototype.param_types.clear();
                // ... (same parsing logic)
            }
            m.code = new_code;
            return true;
        }
    }
    
    return false;
}

uint32_t DexBuilder::get_or_add_string(const std::string& str) {
    auto it = string_map_.find(str);
    if (it != string_map_.end()) {
        return it->second;
    }
    
    uint32_t idx = strings_.size();
    strings_.push_back(str);
    string_map_[str] = idx;
    return idx;
}

uint32_t DexBuilder::get_or_add_type(const std::string& type) {
    auto it = type_map_.find(type);
    if (it != type_map_.end()) {
        return it->second;
    }
    
    get_or_add_string(type);
    
    uint32_t idx = types_.size();
    types_.push_back(type);
    type_map_[type] = idx;
    return idx;
}

uint32_t DexBuilder::get_or_add_proto(const Prototype& proto) {
    std::string proto_str = proto.to_string();
    auto it = proto_map_.find(proto_str);
    if (it != proto_map_.end()) {
        return it->second;
    }
    
    ProtoId pid;
    pid.shorty_idx = get_or_add_string(get_shorty(proto));
    pid.return_type_idx = get_or_add_type(proto.return_type);
    for (const auto& p : proto.param_types) {
        pid.param_type_idxs.push_back(get_or_add_type(p));
    }
    
    uint32_t idx = protos_.size();
    protos_.push_back(pid);
    proto_map_[proto_str] = idx;
    return idx;
}

uint32_t DexBuilder::get_or_add_field(const std::string& class_name, const std::string& field_name, const std::string& type) {
    std::string key = class_name + "->" + field_name + ":" + type;
    auto it = field_map_.find(key);
    if (it != field_map_.end()) {
        return it->second;
    }
    
    FieldId fid;
    fid.class_idx = get_or_add_type(class_name);
    fid.type_idx = get_or_add_type(type);
    fid.name_idx = get_or_add_string(field_name);
    
    uint32_t idx = fields_.size();
    fields_.push_back(fid);
    field_map_[key] = idx;
    return idx;
}

uint32_t DexBuilder::get_or_add_method(const std::string& class_name, const std::string& method_name, const Prototype& proto) {
    std::string key = class_name + "->" + method_name + proto.to_string();
    auto it = method_map_.find(key);
    if (it != method_map_.end()) {
        return it->second;
    }
    
    MethodId mid;
    mid.class_idx = get_or_add_type(class_name);
    mid.proto_idx = get_or_add_proto(proto);
    mid.name_idx = get_or_add_string(method_name);
    
    uint32_t idx = methods_.size();
    methods_.push_back(mid);
    method_map_[key] = idx;
    return idx;
}

std::string DexBuilder::get_shorty(const Prototype& proto) const {
    std::string shorty;
    
    // Return type shorty
    if (proto.return_type.empty() || proto.return_type == "V") {
        shorty += 'V';
    } else if (proto.return_type[0] == 'L' || proto.return_type[0] == '[') {
        shorty += 'L';
    } else {
        shorty += proto.return_type[0];
    }
    
    // Param shorty
    for (const auto& p : proto.param_types) {
        if (p[0] == 'L' || p[0] == '[') {
            shorty += 'L';
        } else {
            shorty += p[0];
        }
    }
    
    return shorty;
}

void DexBuilder::write_uleb128(std::vector<uint8_t>& out, uint32_t value) {
    do {
        uint8_t b = value & 0x7F;
        value >>= 7;
        if (value != 0) b |= 0x80;
        out.push_back(b);
    } while (value != 0);
}

void DexBuilder::write_sleb128(std::vector<uint8_t>& out, int32_t value) {
    bool more = true;
    while (more) {
        uint8_t b = value & 0x7F;
        value >>= 7;
        if ((value == 0 && (b & 0x40) == 0) || (value == -1 && (b & 0x40) != 0)) {
            more = false;
        } else {
            b |= 0x80;
        }
        out.push_back(b);
    }
}

std::vector<uint8_t> DexBuilder::build_code_item(const MethodDef& method) {
    std::vector<uint8_t> out;
    
    write_le<uint16_t>(out, method.registers_size);
    write_le<uint16_t>(out, method.ins_size);
    write_le<uint16_t>(out, method.outs_size);
    write_le<uint16_t>(out, 0);  // tries_size
    write_le<uint32_t>(out, 0);  // debug_info_off
    write_le<uint32_t>(out, method.code.size() / 2);  // insns_size in 16-bit units
    
    out.insert(out.end(), method.code.begin(), method.code.end());
    
    // Align to 4 bytes
    while (out.size() % 4 != 0) {
        out.push_back(0);
    }
    
    return out;
}

std::vector<uint8_t> DexBuilder::build_class_data(const ClassBuilder& cls) {
    std::vector<uint8_t> out;
    
    write_uleb128(out, cls.static_fields.size());
    write_uleb128(out, cls.instance_fields.size());
    write_uleb128(out, cls.direct_methods.size());
    write_uleb128(out, cls.virtual_methods.size());
    
    // Static fields (field_idx_diff, access_flags)
    uint32_t prev_idx = 0;
    for (const auto& f : cls.static_fields) {
        uint32_t idx = get_or_add_field(cls.class_name, f.name, f.type);
        write_uleb128(out, idx - prev_idx);
        write_uleb128(out, f.access_flags);
        prev_idx = idx;
    }
    
    // Instance fields
    prev_idx = 0;
    for (const auto& f : cls.instance_fields) {
        uint32_t idx = get_or_add_field(cls.class_name, f.name, f.type);
        write_uleb128(out, idx - prev_idx);
        write_uleb128(out, f.access_flags);
        prev_idx = idx;
    }
    
    // Note: method code offsets are placeholders, will be filled during final build
    // Direct methods
    prev_idx = 0;
    for (const auto& m : cls.direct_methods) {
        uint32_t idx = get_or_add_method(cls.class_name, m.name, m.prototype);
        write_uleb128(out, idx - prev_idx);
        write_uleb128(out, m.access_flags);
        write_uleb128(out, 0);  // code_off placeholder
        prev_idx = idx;
    }
    
    // Virtual methods
    prev_idx = 0;
    for (const auto& m : cls.virtual_methods) {
        uint32_t idx = get_or_add_method(cls.class_name, m.name, m.prototype);
        write_uleb128(out, idx - prev_idx);
        write_uleb128(out, m.access_flags);
        write_uleb128(out, 0);  // code_off placeholder
        prev_idx = idx;
    }
    
    return out;
}

uint32_t DexBuilder::compute_checksum(const std::vector<uint8_t>& data) {
    uint32_t s1 = 1, s2 = 0;
    for (size_t i = 12; i < data.size(); i++) {
        s1 = (s1 + data[i]) % 65521;
        s2 = (s2 + s1) % 65521;
    }
    return (s2 << 16) | s1;
}

std::vector<uint8_t> DexBuilder::build() {
    if (has_original_ && classes_.empty()) {
        return original_data_;
    }
    
    std::vector<uint8_t> out;
    out.resize(0x70, 0);  // Header
    std::memcpy(out.data(), "dex\n035\0", 8);
    
    // === Data Section (variable-size items first) ===
    uint32_t data_start = out.size();
    
    // 1. String data
    std::vector<uint32_t> string_data_offs;
    for (const auto& s : strings_) {
        string_data_offs.push_back(out.size());
        write_uleb128(out, s.size());
        out.insert(out.end(), s.begin(), s.end());
        out.push_back(0);
    }
    while (out.size() % 4 != 0) out.push_back(0);
    
    // 2. Type lists for protos
    std::vector<uint32_t> type_list_offs;
    for (const auto& p : protos_) {
        if (p.param_type_idxs.empty()) {
            type_list_offs.push_back(0);
        } else {
            while (out.size() % 4 != 0) out.push_back(0);
            type_list_offs.push_back(out.size());
            write_le<uint32_t>(out, p.param_type_idxs.size());
            for (auto idx : p.param_type_idxs) {
                write_le<uint16_t>(out, idx);
            }
            while (out.size() % 4 != 0) out.push_back(0);
        }
    }
    
    // 3. Code items
    std::vector<uint32_t> code_item_offs;
    std::vector<std::pair<size_t, size_t>> class_method_indices;  // class_idx -> (start, count)
    
    for (size_t ci = 0; ci < classes_.size(); ci++) {
        const auto& cls = classes_[ci];
        size_t start = code_item_offs.size();
        
        for (const auto& m : cls.direct_methods) {
            if (m.code.empty()) {
                code_item_offs.push_back(0);
            } else {
                while (out.size() % 4 != 0) out.push_back(0);
                code_item_offs.push_back(out.size());
                auto code_data = build_code_item(m);
                out.insert(out.end(), code_data.begin(), code_data.end());
            }
        }
        for (const auto& m : cls.virtual_methods) {
            if (m.code.empty()) {
                code_item_offs.push_back(0);
            } else {
                while (out.size() % 4 != 0) out.push_back(0);
                code_item_offs.push_back(out.size());
                auto code_data = build_code_item(m);
                out.insert(out.end(), code_data.begin(), code_data.end());
            }
        }
        class_method_indices.push_back({start, code_item_offs.size() - start});
    }
    
    // 4. Class data items
    std::vector<uint32_t> class_data_offs;
    size_t code_idx = 0;
    for (size_t ci = 0; ci < classes_.size(); ci++) {
        const auto& cls = classes_[ci];
        if (cls.static_fields.empty() && cls.instance_fields.empty() &&
            cls.direct_methods.empty() && cls.virtual_methods.empty()) {
            class_data_offs.push_back(0);
            continue;
        }
        
        class_data_offs.push_back(out.size());
        
        write_uleb128(out, cls.static_fields.size());
        write_uleb128(out, cls.instance_fields.size());
        write_uleb128(out, cls.direct_methods.size());
        write_uleb128(out, cls.virtual_methods.size());
        
        // Fields
        uint32_t prev_idx = 0;
        for (const auto& f : cls.static_fields) {
            uint32_t idx = field_map_[cls.class_name + "->" + f.name + ":" + f.type];
            write_uleb128(out, idx - prev_idx);
            write_uleb128(out, f.access_flags);
            prev_idx = idx;
        }
        prev_idx = 0;
        for (const auto& f : cls.instance_fields) {
            uint32_t idx = field_map_[cls.class_name + "->" + f.name + ":" + f.type];
            write_uleb128(out, idx - prev_idx);
            write_uleb128(out, f.access_flags);
            prev_idx = idx;
        }
        
        // Methods with code offsets
        prev_idx = 0;
        for (const auto& m : cls.direct_methods) {
            uint32_t idx = method_map_[cls.class_name + "->" + m.name + m.prototype.to_string()];
            write_uleb128(out, idx - prev_idx);
            write_uleb128(out, m.access_flags);
            write_uleb128(out, code_item_offs[code_idx++]);
            prev_idx = idx;
        }
        prev_idx = 0;
        for (const auto& m : cls.virtual_methods) {
            uint32_t idx = method_map_[cls.class_name + "->" + m.name + m.prototype.to_string()];
            write_uleb128(out, idx - prev_idx);
            write_uleb128(out, m.access_flags);
            write_uleb128(out, code_item_offs[code_idx++]);
            prev_idx = idx;
        }
    }
    while (out.size() % 4 != 0) out.push_back(0);
    
    // === Fixed-size sections ===
    
    // String IDs
    uint32_t string_ids_off = out.size();
    for (uint32_t off : string_data_offs) {
        write_le<uint32_t>(out, off);
    }
    
    // Type IDs
    uint32_t type_ids_off = out.size();
    for (const auto& t : types_) {
        auto it = string_map_.find(t);
        write_le<uint32_t>(out, it != string_map_.end() ? it->second : 0);
    }
    
    // Proto IDs with type_list offsets
    uint32_t proto_ids_off = out.size();
    for (size_t i = 0; i < protos_.size(); i++) {
        write_le<uint32_t>(out, protos_[i].shorty_idx);
        write_le<uint32_t>(out, protos_[i].return_type_idx);
        write_le<uint32_t>(out, type_list_offs[i]);
    }
    
    // Field IDs
    uint32_t field_ids_off = out.size();
    for (const auto& f : fields_) {
        write_le<uint16_t>(out, f.class_idx);
        write_le<uint16_t>(out, f.type_idx);
        write_le<uint32_t>(out, f.name_idx);
    }
    
    // Method IDs
    uint32_t method_ids_off = out.size();
    for (const auto& m : methods_) {
        write_le<uint16_t>(out, m.class_idx);
        write_le<uint16_t>(out, m.proto_idx);
        write_le<uint32_t>(out, m.name_idx);
    }
    
    // Class defs
    uint32_t class_defs_off = out.size();
    for (size_t i = 0; i < classes_.size(); i++) {
        const auto& cls = classes_[i];
        auto it = type_map_.find(cls.class_name);
        write_le<uint32_t>(out, it != type_map_.end() ? it->second : 0);
        write_le<uint32_t>(out, cls.access_flags);
        auto super_it = type_map_.find(cls.super_class);
        write_le<uint32_t>(out, super_it != type_map_.end() ? super_it->second : 0xFFFFFFFF);
        write_le<uint32_t>(out, 0);  // interfaces_off
        write_le<uint32_t>(out, 0xFFFFFFFF);  // source_file_idx
        write_le<uint32_t>(out, 0);  // annotations_off
        write_le<uint32_t>(out, class_data_offs[i]);
        write_le<uint32_t>(out, 0);  // static_values_off
    }
    
    // Map list
    uint32_t map_off = out.size();
    uint32_t map_count = 0;
    std::vector<std::tuple<uint16_t, uint32_t, uint32_t>> map_items;
    
    map_items.push_back({0x0000, 1, 0});  // header
    if (!strings_.empty()) map_items.push_back({0x0001, (uint32_t)strings_.size(), string_ids_off});
    if (!types_.empty()) map_items.push_back({0x0002, (uint32_t)types_.size(), type_ids_off});
    if (!protos_.empty()) map_items.push_back({0x0003, (uint32_t)protos_.size(), proto_ids_off});
    if (!fields_.empty()) map_items.push_back({0x0004, (uint32_t)fields_.size(), field_ids_off});
    if (!methods_.empty()) map_items.push_back({0x0005, (uint32_t)methods_.size(), method_ids_off});
    if (!classes_.empty()) map_items.push_back({0x0006, (uint32_t)classes_.size(), class_defs_off});
    map_items.push_back({0x1000, 1, map_off});  // map_list itself
    
    write_le<uint32_t>(out, map_items.size());
    for (const auto& item : map_items) {
        write_le<uint16_t>(out, std::get<0>(item));
        write_le<uint16_t>(out, 0);  // unused
        write_le<uint32_t>(out, std::get<1>(item));
        write_le<uint32_t>(out, std::get<2>(item));
    }
    
    // Update header
    DexHeader* header = reinterpret_cast<DexHeader*>(out.data());
    header->file_size = out.size();
    header->header_size = 0x70;
    header->endian_tag = 0x12345678;
    header->map_off = map_off;
    header->string_ids_size = strings_.size();
    header->string_ids_off = strings_.empty() ? 0 : string_ids_off;
    header->type_ids_size = types_.size();
    header->type_ids_off = types_.empty() ? 0 : type_ids_off;
    header->proto_ids_size = protos_.size();
    header->proto_ids_off = protos_.empty() ? 0 : proto_ids_off;
    header->field_ids_size = fields_.size();
    header->field_ids_off = fields_.empty() ? 0 : field_ids_off;
    header->method_ids_size = methods_.size();
    header->method_ids_off = methods_.empty() ? 0 : method_ids_off;
    header->class_defs_size = classes_.size();
    header->class_defs_off = classes_.empty() ? 0 : class_defs_off;
    header->data_size = out.size() - data_start;
    header->data_off = data_start;
    
    // Compute checksum
    header->checksum = compute_checksum(out);
    
    return out;
}

bool DexBuilder::save(const std::string& path) {
    auto data = build();
    std::ofstream file(path, std::ios::binary);
    if (!file) return false;
    file.write(reinterpret_cast<const char*>(data.data()), data.size());
    return true;
}

} // namespace dex
