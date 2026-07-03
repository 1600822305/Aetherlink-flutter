#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <unordered_map>
#include <memory>
#include "dex_parser.h"

namespace dex {

// Access flags
enum AccessFlags : uint32_t {
    ACC_PUBLIC = 0x0001,
    ACC_PRIVATE = 0x0002,
    ACC_PROTECTED = 0x0004,
    ACC_STATIC = 0x0008,
    ACC_FINAL = 0x0010,
    ACC_SYNCHRONIZED = 0x0020,
    ACC_VOLATILE = 0x0040,
    ACC_BRIDGE = 0x0040,
    ACC_TRANSIENT = 0x0080,
    ACC_VARARGS = 0x0080,
    ACC_NATIVE = 0x0100,
    ACC_INTERFACE = 0x0200,
    ACC_ABSTRACT = 0x0400,
    ACC_STRICT = 0x0800,
    ACC_SYNTHETIC = 0x1000,
    ACC_ANNOTATION = 0x2000,
    ACC_ENUM = 0x4000,
    ACC_CONSTRUCTOR = 0x10000,
    ACC_DECLARED_SYNCHRONIZED = 0x20000,
};

// Method prototype
struct Prototype {
    std::string return_type;
    std::vector<std::string> param_types;
    
    Prototype() : return_type("V") {}
    Prototype(const std::string& ret) : return_type(ret) {}
    Prototype(const std::string& ret, std::initializer_list<std::string> params)
        : return_type(ret), param_types(params) {}
    
    std::string to_string() const;
};

// Method definition for building
struct MethodDef {
    std::string name;
    Prototype prototype;
    uint32_t access_flags;
    uint16_t registers_size;
    uint16_t ins_size;
    uint16_t outs_size;
    std::vector<uint8_t> code;  // bytecode
};

// Field definition for building
struct FieldDef {
    std::string name;
    std::string type;
    uint32_t access_flags;
};

// Class definition for building
struct ClassBuilder {
    std::string class_name;
    std::string super_class;
    uint32_t access_flags;
    std::vector<std::string> interfaces;
    std::vector<FieldDef> static_fields;
    std::vector<FieldDef> instance_fields;
    std::vector<MethodDef> direct_methods;   // static, private, constructor
    std::vector<MethodDef> virtual_methods;  // other methods
    
    ClassBuilder(const std::string& name) 
        : class_name(name), super_class("Ljava/lang/Object;"), access_flags(ACC_PUBLIC) {}
    
    ClassBuilder& set_super(const std::string& s) { super_class = s; return *this; }
    ClassBuilder& set_access(uint32_t f) { access_flags = f; return *this; }
    ClassBuilder& add_interface(const std::string& i) { interfaces.push_back(i); return *this; }
    
    // Add field
    ClassBuilder& add_field(const std::string& name, const std::string& type, uint32_t flags = ACC_PRIVATE);
    ClassBuilder& add_static_field(const std::string& name, const std::string& type, uint32_t flags = ACC_PRIVATE | ACC_STATIC);
    
    // Add method
    ClassBuilder& add_method(const MethodDef& method);
    MethodDef& create_method(const std::string& name, const Prototype& proto, uint32_t flags = ACC_PUBLIC);
};

// DEX Builder - can build DEX from scratch or modify existing
class DexBuilder {
public:
    DexBuilder();
    ~DexBuilder() = default;
    
    // Load existing DEX as base (for modification)
    bool load(const std::vector<uint8_t>& data);
    bool load(const std::string& path);
    
    // Create new class
    ClassBuilder& make_class(const std::string& class_name);
    
    // Modify existing class
    ClassBuilder* get_class(const std::string& class_name);
    
    // Add/modify method in existing class
    bool add_method(const std::string& class_name, const MethodDef& method);
    bool modify_method(const std::string& class_name, const std::string& method_name, 
                       const std::string& new_prototype, const std::vector<uint8_t>& new_code);
    
    // String/Type pool management
    uint32_t get_or_add_string(const std::string& str);
    uint32_t get_or_add_type(const std::string& type);
    uint32_t get_or_add_proto(const Prototype& proto);
    uint32_t get_or_add_field(const std::string& class_name, const std::string& field_name, const std::string& type);
    uint32_t get_or_add_method(const std::string& class_name, const std::string& method_name, const Prototype& proto);
    
    // Build final DEX
    std::vector<uint8_t> build();
    bool save(const std::string& path);
    
    // Get info
    const std::vector<std::string>& strings() const { return strings_; }
    const std::vector<std::string>& types() const { return types_; }

private:
    // String pool
    std::vector<std::string> strings_;
    std::unordered_map<std::string, uint32_t> string_map_;
    
    // Type pool
    std::vector<std::string> types_;
    std::unordered_map<std::string, uint32_t> type_map_;
    
    // Proto pool
    struct ProtoId {
        uint32_t shorty_idx;
        uint32_t return_type_idx;
        std::vector<uint32_t> param_type_idxs;
    };
    std::vector<ProtoId> protos_;
    std::unordered_map<std::string, uint32_t> proto_map_;
    
    // Field pool
    struct FieldId {
        uint16_t class_idx;
        uint16_t type_idx;
        uint32_t name_idx;
    };
    std::vector<FieldId> fields_;
    std::unordered_map<std::string, uint32_t> field_map_;
    
    // Method pool
    struct MethodId {
        uint16_t class_idx;
        uint16_t proto_idx;
        uint32_t name_idx;
    };
    std::vector<MethodId> methods_;
    std::unordered_map<std::string, uint32_t> method_map_;
    
    // Classes
    std::vector<ClassBuilder> classes_;
    std::unordered_map<std::string, size_t> class_map_;
    
    // Original data (if loaded from existing DEX)
    std::vector<uint8_t> original_data_;
    bool has_original_ = false;
    
    // Helper functions
    void write_uleb128(std::vector<uint8_t>& out, uint32_t value);
    void write_sleb128(std::vector<uint8_t>& out, int32_t value);
    std::string get_shorty(const Prototype& proto) const;
    
    // Build sections
    std::vector<uint8_t> build_string_data();
    std::vector<uint8_t> build_type_list(const std::vector<uint32_t>& type_idxs);
    std::vector<uint8_t> build_class_data(const ClassBuilder& cls);
    std::vector<uint8_t> build_code_item(const MethodDef& method);
    
    // Checksum and signature
    uint32_t compute_checksum(const std::vector<uint8_t>& data);
    void compute_signature(std::vector<uint8_t>& data);
};

} // namespace dex
