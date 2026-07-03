#include "dex/dex_parser.h"
#include <fstream>
#include <sstream>
#include <cstring>

namespace dex {

template<typename T>
static T read_le(const uint8_t* p) {
    T val = 0;
    for (size_t i = 0; i < sizeof(T); i++) {
        val |= static_cast<T>(p[i]) << (i * 8);
    }
    return val;
}

bool DexParser::parse(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) return false;

    file.seekg(0, std::ios::end);
    size_t size = file.tellg();
    file.seekg(0, std::ios::beg);

    data_.resize(size);
    file.read(reinterpret_cast<char*>(data_.data()), size);
    file.close();

    return parse_header() && parse_strings() && parse_types() && parse_classes();
}

bool DexParser::parse(const std::vector<uint8_t>& data) {
    data_ = data;
    return parse_header() && parse_strings() && parse_types() && parse_classes();
}

bool DexParser::parse_header() {
    if (data_.size() < sizeof(DexHeader)) return false;

    std::memcpy(&header_, data_.data(), sizeof(DexHeader));

    if (std::memcmp(header_.magic, "dex\n", 4) != 0) {
        return false;
    }

    return true;
}

bool DexParser::parse_strings() {
    if (header_.string_ids_off + header_.string_ids_size * 4 > data_.size()) {
        return false;
    }

    string_ids_.resize(header_.string_ids_size);
    strings_.resize(header_.string_ids_size);

    for (uint32_t i = 0; i < header_.string_ids_size; i++) {
        string_ids_[i] = read_le<uint32_t>(&data_[header_.string_ids_off + i * 4]);
        strings_[i] = read_string_at(string_ids_[i]);
    }

    return true;
}

bool DexParser::parse_types() {
    if (header_.type_ids_off + header_.type_ids_size * 4 > data_.size()) {
        return false;
    }

    type_ids_.resize(header_.type_ids_size);
    types_.resize(header_.type_ids_size);

    for (uint32_t i = 0; i < header_.type_ids_size; i++) {
        uint32_t string_idx = read_le<uint32_t>(&data_[header_.type_ids_off + i * 4]);
        type_ids_[i] = string_idx;
        if (string_idx < strings_.size()) {
            types_[i] = strings_[string_idx];
        }
    }

    return true;
}

bool DexParser::parse_classes() {
    if (header_.class_defs_off + header_.class_defs_size * 32 > data_.size()) {
        return false;
    }

    classes_.resize(header_.class_defs_size);

    for (uint32_t i = 0; i < header_.class_defs_size; i++) {
        size_t offset = header_.class_defs_off + i * 32;
        ClassDef& cd = classes_[i];
        
        cd.class_idx = read_le<uint32_t>(&data_[offset]);
        cd.access_flags = read_le<uint32_t>(&data_[offset + 4]);
        cd.superclass_idx = read_le<uint32_t>(&data_[offset + 8]);
        cd.interfaces_off = read_le<uint32_t>(&data_[offset + 12]);
        cd.source_file_idx = read_le<uint32_t>(&data_[offset + 16]);
        cd.annotations_off = read_le<uint32_t>(&data_[offset + 20]);
        cd.class_data_off = read_le<uint32_t>(&data_[offset + 24]);
        cd.static_values_off = read_le<uint32_t>(&data_[offset + 28]);
    }

    return true;
}

std::string DexParser::read_string_at(uint32_t offset) const {
    if (offset >= data_.size()) return "";

    size_t pos = offset;
    uint32_t len = read_uleb128(pos);
    
    if (pos + len > data_.size()) return "";

    return std::string(reinterpret_cast<const char*>(&data_[pos]), len);
}

uint32_t DexParser::read_uleb128(size_t& offset) const {
    uint32_t result = 0;
    int shift = 0;
    
    while (offset < data_.size()) {
        uint8_t b = data_[offset++];
        result |= (b & 0x7F) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
    }
    
    return result;
}

std::string DexParser::get_class_name(uint32_t idx) const {
    if (idx < types_.size()) {
        return types_[idx];
    }
    return "";
}

std::vector<MethodInfo> DexParser::get_methods() const {
    std::vector<MethodInfo> methods;
    
    if (header_.method_ids_off == 0 || header_.method_ids_size == 0) {
        return methods;
    }

    for (uint32_t i = 0; i < header_.method_ids_size; i++) {
        size_t offset = header_.method_ids_off + i * 8;
        if (offset + 8 > data_.size()) break;

        uint16_t class_idx = read_le<uint16_t>(&data_[offset]);
        uint16_t proto_idx = read_le<uint16_t>(&data_[offset + 2]);
        uint32_t name_idx = read_le<uint32_t>(&data_[offset + 4]);

        MethodInfo info;
        info.class_name = get_class_name(class_idx);
        if (name_idx < strings_.size()) {
            info.method_name = strings_[name_idx];
        }
        info.prototype = get_proto_string(proto_idx);
        info.access_flags = 0;
        info.code_off = 0;
        
        methods.push_back(info);
    }

    return methods;
}

std::vector<FieldInfo> DexParser::get_fields() const {
    std::vector<FieldInfo> fields;
    
    if (header_.field_ids_off == 0 || header_.field_ids_size == 0) {
        return fields;
    }

    for (uint32_t i = 0; i < header_.field_ids_size; i++) {
        size_t offset = header_.field_ids_off + i * 8;
        if (offset + 8 > data_.size()) break;

        uint16_t class_idx = read_le<uint16_t>(&data_[offset]);
        uint16_t type_idx = read_le<uint16_t>(&data_[offset + 2]);
        uint32_t name_idx = read_le<uint32_t>(&data_[offset + 4]);

        FieldInfo info;
        info.class_name = get_class_name(class_idx);
        info.type_name = get_class_name(type_idx);
        if (name_idx < strings_.size()) {
            info.field_name = strings_[name_idx];
        }
        info.access_flags = 0;
        
        fields.push_back(info);
    }

    return fields;
}

std::vector<std::string> DexParser::get_class_methods(const std::string& class_name) const {
    std::vector<std::string> result;
    auto methods = get_methods();
    
    for (const auto& m : methods) {
        if (m.class_name == class_name) {
            result.push_back(m.method_name);
        }
    }
    
    return result;
}

std::string DexParser::get_info() const {
    std::stringstream ss;
    
    ss << "DEX File Info:\n";
    ss << "  Version: " << std::string(reinterpret_cast<const char*>(header_.magic + 4), 3) << "\n";
    ss << "  File Size: " << header_.file_size << " bytes\n";
    ss << "  Strings: " << header_.string_ids_size << "\n";
    ss << "  Types: " << header_.type_ids_size << "\n";
    ss << "  Protos: " << header_.proto_ids_size << "\n";
    ss << "  Fields: " << header_.field_ids_size << "\n";
    ss << "  Methods: " << header_.method_ids_size << "\n";
    ss << "  Classes: " << header_.class_defs_size << "\n";
    
    return ss.str();
}

bool DexParser::get_method_code(const std::string& class_name, const std::string& method_name, CodeItem& code) const {
    // Find the class
    for (const auto& cls : classes_) {
        std::string cls_name = get_class_name(cls.class_idx);
        if (cls_name != class_name) continue;
        
        if (cls.class_data_off == 0) continue;
        
        // Parse class_data_item
        size_t offset = cls.class_data_off;
        uint32_t static_fields_size = read_uleb128(offset);
        uint32_t instance_fields_size = read_uleb128(offset);
        uint32_t direct_methods_size = read_uleb128(offset);
        uint32_t virtual_methods_size = read_uleb128(offset);
        
        // Skip fields
        for (uint32_t i = 0; i < static_fields_size + instance_fields_size; i++) {
            read_uleb128(offset); // field_idx_diff
            read_uleb128(offset); // access_flags
        }
        
        // Parse methods
        uint32_t method_idx = 0;
        for (uint32_t i = 0; i < direct_methods_size + virtual_methods_size; i++) {
            uint32_t method_idx_diff = read_uleb128(offset);
            method_idx += method_idx_diff;
            uint32_t access_flags = read_uleb128(offset);
            uint32_t code_off = read_uleb128(offset);
            
            // Get method name from method_ids
            if (method_idx < header_.method_ids_size) {
                size_t mid_off = header_.method_ids_off + method_idx * 8;
                if (mid_off + 8 <= data_.size()) {
                    uint32_t name_idx = read_le<uint32_t>(&data_[mid_off + 4]);
                    if (name_idx < strings_.size() && strings_[name_idx] == method_name) {
                        // Found the method
                        if (code_off == 0) return false; // No code (abstract/native)
                        
                        // Parse code_item
                        if (code_off + 16 > data_.size()) return false;
                        
                        code.registers_size = read_le<uint16_t>(&data_[code_off]);
                        code.ins_size = read_le<uint16_t>(&data_[code_off + 2]);
                        code.outs_size = read_le<uint16_t>(&data_[code_off + 4]);
                        code.tries_size = read_le<uint16_t>(&data_[code_off + 6]);
                        code.debug_info_off = read_le<uint32_t>(&data_[code_off + 8]);
                        code.insns_size = read_le<uint32_t>(&data_[code_off + 12]);
                        
                        size_t insns_off = code_off + 16;
                        size_t insns_bytes = code.insns_size * 2;
                        
                        if (insns_off + insns_bytes > data_.size()) return false;
                        
                        code.insns.assign(data_.begin() + insns_off, 
                                         data_.begin() + insns_off + insns_bytes);
                        code.code_off = code_off;
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

std::unordered_map<std::string, CodeItem> DexParser::get_all_method_codes() const {
    std::unordered_map<std::string, CodeItem> result;
    
    for (const auto& cls : classes_) {
        std::string cls_name = get_class_name(cls.class_idx);
        if (cls_name.empty() || cls.class_data_off == 0) continue;
        
        // Parse class_data_item
        size_t offset = cls.class_data_off;
        uint32_t static_fields_size = read_uleb128(offset);
        uint32_t instance_fields_size = read_uleb128(offset);
        uint32_t direct_methods_size = read_uleb128(offset);
        uint32_t virtual_methods_size = read_uleb128(offset);
        
        // Skip fields
        for (uint32_t i = 0; i < static_fields_size + instance_fields_size; i++) {
            read_uleb128(offset);
            read_uleb128(offset);
        }
        
        // Parse all methods
        uint32_t method_idx = 0;
        for (uint32_t i = 0; i < direct_methods_size + virtual_methods_size; i++) {
            uint32_t method_idx_diff = read_uleb128(offset);
            method_idx += method_idx_diff;
            read_uleb128(offset); // access_flags
            uint32_t code_off = read_uleb128(offset);
            
            if (code_off == 0) continue; // No code
            if (method_idx >= header_.method_ids_size) continue;
            
            size_t mid_off = header_.method_ids_off + method_idx * 8;
            if (mid_off + 8 > data_.size()) continue;
            
            uint32_t name_idx = read_le<uint32_t>(&data_[mid_off + 4]);
            if (name_idx >= strings_.size()) continue;
            
            std::string method_name = strings_[name_idx];
            std::string key = cls_name + "|" + method_name;
            
            // Parse code_item
            if (code_off + 16 > data_.size()) continue;
            
            CodeItem code;
            code.registers_size = read_le<uint16_t>(&data_[code_off]);
            code.ins_size = read_le<uint16_t>(&data_[code_off + 2]);
            code.outs_size = read_le<uint16_t>(&data_[code_off + 4]);
            code.tries_size = read_le<uint16_t>(&data_[code_off + 6]);
            code.debug_info_off = read_le<uint32_t>(&data_[code_off + 8]);
            code.insns_size = read_le<uint32_t>(&data_[code_off + 12]);
            code.code_off = code_off;
            
            size_t insns_off = code_off + 16;
            size_t insns_bytes = code.insns_size * 2;
            
            if (insns_off + insns_bytes > data_.size()) continue;
            
            code.insns.assign(data_.begin() + insns_off, 
                             data_.begin() + insns_off + insns_bytes);
            
            result[key] = std::move(code);
        }
    }
    
    return result;
}

std::string DexParser::get_proto_string(uint32_t proto_idx) const {
    // proto_id: shorty_idx(4), return_type_idx(4), parameters_off(4)
    size_t offset = header_.proto_ids_off + proto_idx * 12;
    if (offset + 12 > data_.size()) return "()V";
    
    uint32_t return_type_idx = read_le<uint32_t>(&data_[offset + 4]);
    uint32_t params_off = read_le<uint32_t>(&data_[offset + 8]);
    
    std::string result = "(";
    
    // Parse parameters if present
    if (params_off != 0 && params_off + 4 <= data_.size()) {
        uint32_t param_count = read_le<uint32_t>(&data_[params_off]);
        for (uint32_t i = 0; i < param_count && params_off + 4 + (i + 1) * 2 <= data_.size(); i++) {
            uint16_t type_idx = read_le<uint16_t>(&data_[params_off + 4 + i * 2]);
            result += get_class_name(type_idx);
        }
    }
    
    result += ")";
    result += get_class_name(return_type_idx);
    
    return result;
}

std::string DexParser::get_full_method_signature(uint32_t method_idx) const {
    if (method_idx >= header_.method_ids_size) return "";
    
    size_t offset = header_.method_ids_off + method_idx * 8;
    if (offset + 8 > data_.size()) return "";
    
    uint16_t class_idx = read_le<uint16_t>(&data_[offset]);
    uint16_t proto_idx = read_le<uint16_t>(&data_[offset + 2]);
    uint32_t name_idx = read_le<uint32_t>(&data_[offset + 4]);
    
    std::string sig = get_class_name(class_idx) + "->";
    if (name_idx < strings_.size()) {
        sig += strings_[name_idx];
    }
    sig += get_proto_string(proto_idx);
    
    return sig;
}

std::vector<std::string> DexParser::get_method_signatures() const {
    std::vector<std::string> sigs;
    
    for (uint32_t i = 0; i < header_.method_ids_size; i++) {
        sigs.push_back(get_full_method_signature(i));
    }
    
    return sigs;
}

std::vector<std::string> DexParser::get_field_signatures() const {
    std::vector<std::string> sigs;
    
    for (uint32_t i = 0; i < header_.field_ids_size; i++) {
        size_t offset = header_.field_ids_off + i * 8;
        if (offset + 8 > data_.size()) break;
        
        uint16_t class_idx = read_le<uint16_t>(&data_[offset]);
        uint16_t type_idx = read_le<uint16_t>(&data_[offset + 2]);
        uint32_t name_idx = read_le<uint32_t>(&data_[offset + 4]);
        
        std::string sig = get_class_name(class_idx) + "->";
        if (name_idx < strings_.size()) {
            sig += strings_[name_idx];
        }
        sig += ":" + get_class_name(type_idx);
        sigs.push_back(sig);
    }
    
    return sigs;
}

std::vector<DexParser::XRef> DexParser::find_method_xrefs(const std::string& class_name, const std::string& method_name) const {
    std::vector<XRef> results;
    
    // Find the target method index
    int target_method_idx = -1;
    for (uint32_t i = 0; i < header_.method_ids_size; i++) {
        size_t offset = header_.method_ids_off + i * 8;
        if (offset + 8 > data_.size()) break;
        
        uint16_t cls_idx = read_le<uint16_t>(&data_[offset]);
        uint32_t name_idx = read_le<uint32_t>(&data_[offset + 4]);
        
        if (get_class_name(cls_idx) == class_name && 
            name_idx < strings_.size() && strings_[name_idx] == method_name) {
            target_method_idx = i;
            break;
        }
    }
    
    if (target_method_idx < 0) return results;
    
    // Scan all methods for invoke instructions
    for (const auto& cls : classes_) {
        std::string caller_class = get_class_name(cls.class_idx);
        if (caller_class.empty() || cls.class_data_off == 0) continue;
        
        size_t offset = cls.class_data_off;
        uint32_t static_fields = read_uleb128(offset);
        uint32_t instance_fields = read_uleb128(offset);
        uint32_t direct_methods = read_uleb128(offset);
        uint32_t virtual_methods = read_uleb128(offset);
        
        // Skip fields
        for (uint32_t i = 0; i < static_fields + instance_fields; i++) {
            read_uleb128(offset);
            read_uleb128(offset);
        }
        
        // Scan methods
        uint32_t method_idx = 0;
        for (uint32_t i = 0; i < direct_methods + virtual_methods; i++) {
            method_idx += read_uleb128(offset);
            read_uleb128(offset); // access_flags
            uint32_t code_off = read_uleb128(offset);
            
            if (code_off == 0) continue;
            if (code_off + 16 > data_.size()) continue;
            
            uint32_t insns_size = read_le<uint32_t>(&data_[code_off + 12]);
            size_t insns_off = code_off + 16;
            
            // Get caller method name
            std::string caller_method;
            if (method_idx < header_.method_ids_size) {
                size_t mid_off = header_.method_ids_off + method_idx * 8;
                if (mid_off + 8 <= data_.size()) {
                    uint32_t name_idx = read_le<uint32_t>(&data_[mid_off + 4]);
                    if (name_idx < strings_.size()) {
                        caller_method = strings_[name_idx];
                    }
                }
            }
            
            // Scan bytecode for invoke instructions
            for (size_t pos = 0; pos < insns_size * 2;) {
                if (insns_off + pos >= data_.size()) break;
                
                uint8_t opcode = data_[insns_off + pos];
                
                // invoke-* opcodes: 0x6e-0x72 (invoke-virtual to invoke-interface)
                // invoke-*/range: 0x74-0x78
                if ((opcode >= 0x6e && opcode <= 0x72) || (opcode >= 0x74 && opcode <= 0x78)) {
                    if (insns_off + pos + 3 <= data_.size()) {
                        uint16_t ref_idx = read_le<uint16_t>(&data_[insns_off + pos + 2]);
                        if (ref_idx == target_method_idx) {
                            XRef xref;
                            xref.caller_class = caller_class;
                            xref.caller_method = caller_method;
                            xref.offset = static_cast<uint32_t>(pos / 2);
                            results.push_back(xref);
                        }
                    }
                    pos += 6; // invoke instructions are 3 units (6 bytes)
                } else {
                    // Simple instruction size estimation
                    pos += 2;
                    if (opcode == 0x00 && pos > 2) break; // nop might indicate padding
                }
            }
        }
    }
    
    return results;
}

std::vector<DexParser::XRef> DexParser::find_field_xrefs(const std::string& class_name, const std::string& field_name) const {
    std::vector<XRef> results;
    
    // Find the target field index
    int target_field_idx = -1;
    for (uint32_t i = 0; i < header_.field_ids_size; i++) {
        size_t offset = header_.field_ids_off + i * 8;
        if (offset + 8 > data_.size()) break;
        
        uint16_t cls_idx = read_le<uint16_t>(&data_[offset]);
        uint32_t name_idx = read_le<uint32_t>(&data_[offset + 4]);
        
        if (get_class_name(cls_idx) == class_name && 
            name_idx < strings_.size() && strings_[name_idx] == field_name) {
            target_field_idx = i;
            break;
        }
    }
    
    if (target_field_idx < 0) return results;
    
    // Scan all methods for field access instructions
    for (const auto& cls : classes_) {
        std::string caller_class = get_class_name(cls.class_idx);
        if (caller_class.empty() || cls.class_data_off == 0) continue;
        
        size_t offset = cls.class_data_off;
        uint32_t static_fields = read_uleb128(offset);
        uint32_t instance_fields = read_uleb128(offset);
        uint32_t direct_methods = read_uleb128(offset);
        uint32_t virtual_methods = read_uleb128(offset);
        
        for (uint32_t i = 0; i < static_fields + instance_fields; i++) {
            read_uleb128(offset);
            read_uleb128(offset);
        }
        
        uint32_t method_idx = 0;
        for (uint32_t i = 0; i < direct_methods + virtual_methods; i++) {
            method_idx += read_uleb128(offset);
            read_uleb128(offset);
            uint32_t code_off = read_uleb128(offset);
            
            if (code_off == 0) continue;
            if (code_off + 16 > data_.size()) continue;
            
            uint32_t insns_size = read_le<uint32_t>(&data_[code_off + 12]);
            size_t insns_off = code_off + 16;
            
            std::string caller_method;
            if (method_idx < header_.method_ids_size) {
                size_t mid_off = header_.method_ids_off + method_idx * 8;
                if (mid_off + 8 <= data_.size()) {
                    uint32_t name_idx = read_le<uint32_t>(&data_[mid_off + 4]);
                    if (name_idx < strings_.size()) {
                        caller_method = strings_[name_idx];
                    }
                }
            }
            
            for (size_t pos = 0; pos < insns_size * 2;) {
                if (insns_off + pos >= data_.size()) break;
                
                uint8_t opcode = data_[insns_off + pos];
                
                // iget/iput: 0x52-0x5f, sget/sput: 0x60-0x6d
                if ((opcode >= 0x52 && opcode <= 0x5f) || (opcode >= 0x60 && opcode <= 0x6d)) {
                    if (insns_off + pos + 3 <= data_.size()) {
                        uint16_t ref_idx = read_le<uint16_t>(&data_[insns_off + pos + 2]);
                        if (ref_idx == target_field_idx) {
                            XRef xref;
                            xref.caller_class = caller_class;
                            xref.caller_method = caller_method;
                            xref.offset = static_cast<uint32_t>(pos / 2);
                            results.push_back(xref);
                        }
                    }
                    pos += 4; // field instructions are 2 units (4 bytes)
                } else {
                    pos += 2;
                    if (opcode == 0x00 && pos > 2) break;
                }
            }
        }
    }
    
    return results;
}

} // namespace dex
