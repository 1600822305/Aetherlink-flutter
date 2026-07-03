#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <map>
#include "android_resources.h"

namespace axml {

struct Attribute {
    std::string namespace_uri;
    std::string name;
    std::string value;
    uint32_t type;
    uint32_t data;
};

struct Element {
    std::string namespace_uri;
    std::string name;
    std::vector<Attribute> attributes;
    std::vector<Element> children;
    std::string text;
};

class AxmlParser {
public:
    AxmlParser() = default;
    ~AxmlParser() = default;

    bool parse(const std::vector<uint8_t>& data);
    
    const Element& root() const { return root_; }
    std::string to_xml(int indent = 0) const;
    
    std::string get_package_name() const;
    std::string get_version_name() const;
    int get_version_code() const;
    std::string get_min_sdk() const;
    std::string get_target_sdk() const;
    std::vector<std::string> get_permissions() const;
    std::vector<std::string> get_activities() const;
    std::vector<std::string> get_services() const;
    std::vector<std::string> get_receivers() const;

    std::string get_info() const;

private:
    std::vector<uint8_t> data_;
    std::vector<std::string> string_pool_;
    Element root_;

    bool parse_string_pool(size_t& offset);
    bool parse_resource_map(size_t& offset);
    bool parse_elements(size_t& offset);
    
    std::string element_to_xml(const Element& elem, int indent) const;
    std::string get_attribute_value(const Element& elem, const std::string& name) const;
};

struct ResourceValue {
    uint8_t type;
    uint32_t data;
    std::string string_value;
};

struct SearchResult {
    std::string element_path;
    std::string element_name;
    std::string attribute_name;
    std::string attribute_value;
    int element_index;
};

class AxmlEditor {
public:
    AxmlEditor() = default;
    ~AxmlEditor() = default;

    bool load(const std::vector<uint8_t>& data);
    std::vector<uint8_t> save();
    bool is_loaded() const { return !data_.empty(); }

    bool set_package_name(const std::string& name);
    bool set_version_name(const std::string& name);
    bool set_version_code(int code);
    bool set_min_sdk(int sdk);
    bool set_target_sdk(int sdk);
    
    // Permission management
    bool add_permission(const std::string& permission);
    bool remove_permission(const std::string& permission);
    
    // Activity management
    bool add_activity(const std::string& activity_name, bool exported = false);
    bool remove_activity(const std::string& activity_name);
    
    // Generic element management
    bool add_element(const std::string& parent_path, const std::string& element_name,
                     const std::vector<std::pair<std::string, std::string>>& attributes);
    bool remove_element(const std::string& element_path);

    std::vector<SearchResult> search_by_attribute(const std::string& attr_name, const std::string& value_pattern) const;
    std::vector<SearchResult> search_by_element(const std::string& element_name) const;
    std::vector<SearchResult> search_by_value(const std::string& value_pattern) const;
    
    bool set_attribute(const std::string& element_path, const std::string& attr_name, const std::string& new_value);
    bool set_attribute_by_index(int element_index, const std::string& attr_name, const std::string& new_value);

    const Element& root() const { return root_; }
    const std::vector<std::string>& string_pool() const { return string_pool_; }

private:
    std::vector<uint8_t> data_;
    std::vector<std::string> string_pool_;
    Element root_;
    std::vector<uint32_t> resource_ids_;
    
    struct ChunkInfo {
        size_t string_pool_offset;
        size_t string_pool_size;
        size_t resource_map_offset;
        size_t resource_map_size;
        size_t xml_content_offset;
    };
    ChunkInfo chunk_info_;

    bool parse_internal();
    int find_or_add_string(const std::string& str);
    bool rebuild_binary();
    void search_element(const Element& elem, const std::string& path, int& index,
                        const std::string& attr_name, const std::string& value_pattern,
                        std::vector<SearchResult>& results) const;
    
    // Helper methods for element manipulation
    std::vector<uint8_t> create_start_element(const std::string& name,
                                               const std::vector<std::pair<std::string, std::string>>& attrs,
                                               uint32_t line_number = 1);
    std::vector<uint8_t> create_end_element(const std::string& name, uint32_t line_number = 1);
    bool insert_element_after(size_t offset, const std::vector<uint8_t>& element_data);
    bool remove_element_at(size_t start_offset, size_t end_offset);
    size_t find_element_end(size_t start_offset);
    size_t find_parent_element_end(const std::string& parent_name);
};

} // namespace axml
