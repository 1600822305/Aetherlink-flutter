#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace apk {

struct FileEntry {
    std::string name;
    std::vector<uint8_t> data;
    bool is_directory;
};

class ApkHandler {
public:
    ApkHandler() = default;
    ~ApkHandler() = default;

    bool open(const std::string& path);
    bool create(const std::string& path);  // Create new empty APK
    bool save(const std::string& path);
    void close();

    std::vector<std::string> list_files() const;
    bool extract_file(const std::string& name, std::vector<uint8_t>& data) const;
    bool replace_file(const std::string& name, const std::vector<uint8_t>& data);
    bool add_file(const std::string& name, const std::vector<uint8_t>& data);
    bool delete_file(const std::string& name);
    void remove_files_by_pattern(const std::string& pattern);

    bool is_open() const { return is_open_; }
    std::string get_path() const { return path_; }

private:
    std::string path_;
    std::vector<FileEntry> entries_;
    bool is_open_ = false;
};

} // namespace apk
