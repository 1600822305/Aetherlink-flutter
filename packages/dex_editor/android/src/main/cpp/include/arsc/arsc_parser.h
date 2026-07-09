#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <unordered_map>

namespace arsc {

// Resource types
enum class ResourceType : uint16_t {
    NULL_TYPE = 0x00,
    STRING_POOL = 0x01,
    TABLE = 0x02,
    XML = 0x03,
    TABLE_PACKAGE = 0x0200,
    TABLE_TYPE = 0x0201,
    TABLE_TYPE_SPEC = 0x0202,
};

struct StringPoolHeader {
    uint32_t string_count;
    uint32_t style_count;
    uint32_t flags;
    uint32_t strings_start;
    uint32_t styles_start;
};

struct ResourceEntry {
    uint32_t id;           // Full resource ID (0xPPTTEEEE)
    std::string name;      // Resource name
    std::string type;      // Type name (string, drawable, etc.)
    std::string value;     // Value (for simple types)
    std::string package;   // Package name
    std::string config;    // 配置限定符/variant，如 "default"/"zh-rCN"/"xxhdpi"/"v21"
};

struct StringResource {
    uint32_t index;
    std::string value;
};

class ArscParser {
public:
    ArscParser() = default;
    ~ArscParser() = default;

    bool parse(const std::vector<uint8_t>& data);
    bool parse(const std::string& path);

    // Get all strings from string pool
    const std::vector<std::string>& strings() const { return strings_; }
    
    // Get all resources
    const std::vector<ResourceEntry>& resources() const { return resources_; }
    
    // Get package name
    const std::string& package_name() const { return package_name_; }
    
    // Search strings
    std::vector<StringResource> search_strings(const std::string& pattern) const;
    
    // Search resources by name or type
    std::vector<ResourceEntry> search_resources(const std::string& pattern, 
                                                 const std::string& type = "") const;
    
    // Get resource by ID
    const ResourceEntry* get_resource(uint32_t id) const;

    // Read a resource's value(s) by full ID, one entry per config qualifier.
    // Returns a JSON string: {id,type,name,package,configs:[{config,valueType,valueTypeName,value}]}
    std::string get_resource_value_json(uint32_t id) const;

    // Set a resource's value by full ID.
    //  - config_filter: only apply to matching config ("" requires a unique config)
    //  - value_type: one of "auto"|"string"|"int"|"hex"|"bool"|"color"|"reference"|"float"
    //  - new_value: textual value, parsed per value_type
    // On success fills `out` with new arsc bytes and returns true; else sets `error`.
    bool set_resource_value(uint32_t id, const std::string& config_filter,
                            const std::string& value_type, const std::string& new_value,
                            std::vector<uint8_t>& out, std::string& error) const;

    // Get summary info
    std::string get_info() const;

private:
    // One resolved simple entry occurrence (per config) for a given resource id.
    struct ConfigEntry {
        std::string config;   // human-readable qualifier ("default", "zh", "xxhdpi"...)
        size_t value_pos;     // absolute offset of the Res_value within data_
        uint8_t value_type;   // Res_value dataType
        uint32_t value_data;  // Res_value data
        bool complex;         // bag/map entry (not settable)
    };

    // Collect all simple entry occurrences of `id` across configs.
    std::vector<ConfigEntry> collect_config_entries(uint32_t id) const;

    // Decode a ResTable_config at `off` into a readable qualifier string.
    std::string config_to_string(size_t off) const;

    // Global string pool location (first string pool chunk after table header).
    bool locate_global_pool(size_t& pool_off, size_t& pool_size, bool& is_utf8) const;

    // Rebuild the global string pool with `value` appended (or reuse existing),
    // returning the new pool bytes and the string index to reference.
    bool build_pool_with_string(const std::string& value, std::vector<uint8_t>& new_pool,
                                uint32_t& index, std::string& error) const;

    std::string decode_value(uint8_t type, uint32_t data) const;
    std::vector<uint8_t> data_;
    std::vector<std::string> strings_;
    std::vector<ResourceEntry> resources_;
    std::string package_name_;
    uint32_t package_id_ = 0;
    
    std::unordered_map<uint32_t, size_t> id_to_index_;
    
    bool parse_string_pool(size_t offset, size_t size);
    bool parse_package(size_t offset, size_t size);
    bool parse_type_spec(size_t offset, size_t size, const std::string& type_name);
    bool parse_type(size_t offset, size_t size, const std::string& type_name);
    
    std::string read_string_at(size_t offset, bool utf8) const;
    
    template<typename T>
    T read_le(size_t offset) const {
        T val = 0;
        for (size_t i = 0; i < sizeof(T); i++) {
            val |= static_cast<T>(data_[offset + i]) << (i * 8);
        }
        return val;
    }
};

} // namespace arsc
