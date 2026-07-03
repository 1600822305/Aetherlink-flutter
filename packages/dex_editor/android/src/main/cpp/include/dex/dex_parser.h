#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <unordered_map>
#include <map>

namespace dex {

struct DexHeader {
    uint8_t magic[8];
    uint32_t checksum;
    uint8_t signature[20];
    uint32_t file_size;
    uint32_t header_size;
    uint32_t endian_tag;
    uint32_t link_size;
    uint32_t link_off;
    uint32_t map_off;
    uint32_t string_ids_size;
    uint32_t string_ids_off;
    uint32_t type_ids_size;
    uint32_t type_ids_off;
    uint32_t proto_ids_size;
    uint32_t proto_ids_off;
    uint32_t field_ids_size;
    uint32_t field_ids_off;
    uint32_t method_ids_size;
    uint32_t method_ids_off;
    uint32_t class_defs_size;
    uint32_t class_defs_off;
    uint32_t data_size;
    uint32_t data_off;
};

struct ClassDef {
    uint32_t class_idx;
    uint32_t access_flags;
    uint32_t superclass_idx;
    uint32_t interfaces_off;
    uint32_t source_file_idx;
    uint32_t annotations_off;
    uint32_t class_data_off;
    uint32_t static_values_off;
};

struct CodeItem {
    uint16_t registers_size;
    uint16_t ins_size;
    uint16_t outs_size;
    uint16_t tries_size;
    uint32_t debug_info_off;
    uint32_t insns_size;  // in 16-bit code units
    std::vector<uint8_t> insns;
    uint32_t code_off;    // offset of code_item in DEX file
};

struct MethodInfo {
    std::string class_name;
    std::string method_name;
    std::string prototype;
    uint32_t access_flags;
    uint32_t code_off;
};

struct FieldInfo {
    std::string class_name;
    std::string field_name;
    std::string type_name;
    uint32_t access_flags;
};

class DexParser {
public:
    DexParser() = default;
    ~DexParser() = default;

    bool parse(const std::vector<uint8_t>& data);
    bool parse(const std::string& path);

    const DexHeader& header() const { return header_; }
    const std::vector<std::string>& strings() const { return strings_; }
    const std::vector<std::string>& types() const { return types_; }
    const std::vector<ClassDef>& classes() const { return classes_; }
    std::vector<MethodInfo> get_methods() const;
    std::vector<FieldInfo> get_fields() const;

    std::string get_class_name(uint32_t idx) const;
    std::vector<std::string> get_class_methods(const std::string& class_name) const;
    
    // Get method code for disassembly
    bool get_method_code(const std::string& class_name, const std::string& method_name, CodeItem& code) const;
    
    // Get all method codes at once (optimized batch operation)
    std::unordered_map<std::string, CodeItem> get_all_method_codes() const;
    
    // Get all method signatures for reference resolution
    std::vector<std::string> get_method_signatures() const;
    std::vector<std::string> get_field_signatures() const;
    
    // Get full method signature with parameters and return type
    std::string get_full_method_signature(uint32_t method_idx) const;
    std::string get_proto_string(uint32_t proto_idx) const;
    
    // Cross-reference analysis
    struct XRef {
        std::string caller_class;
        std::string caller_method;
        uint32_t offset;
    };
    std::vector<XRef> find_method_xrefs(const std::string& class_name, const std::string& method_name) const;
    std::vector<XRef> find_field_xrefs(const std::string& class_name, const std::string& field_name) const;

    std::string get_info() const;
    
    const std::vector<uint8_t>& data() const { return data_; }

private:
    DexHeader header_;
    std::vector<uint8_t> data_;
    std::vector<std::string> strings_;
    std::vector<std::string> types_;
    std::vector<ClassDef> classes_;
    std::vector<uint32_t> string_ids_;
    std::vector<uint32_t> type_ids_;

    bool parse_header();
    bool parse_strings();
    bool parse_types();
    bool parse_classes();

    std::string read_string_at(uint32_t offset) const;
    uint32_t read_uleb128(size_t& offset) const;
};

} // namespace dex
