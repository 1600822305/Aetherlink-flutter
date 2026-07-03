#include "apk/apk_handler.h"
#include "apk/zip_utils.h"
#include <algorithm>

namespace apk {

bool ApkHandler::open(const std::string& path) {
    ZipReader reader;
    if (!reader.open(path)) {
        return false;
    }

    path_ = path;
    entries_.clear();

    reader.extract_all([this](const std::string& name, const std::vector<uint8_t>& data) {
        FileEntry entry;
        entry.name = name;
        entry.data = data;
        entry.is_directory = !name.empty() && name.back() == '/';
        entries_.push_back(entry);
    });

    reader.close();
    is_open_ = true;
    return true;
}

bool ApkHandler::create(const std::string& path) {
    path_ = path;
    entries_.clear();
    is_open_ = true;
    return true;
}

bool ApkHandler::save(const std::string& path) {
    if (!is_open_) return false;

    ZipWriter writer;
    
    for (const auto& entry : entries_) {
        if (!entry.is_directory) {
            // Let ZipWriter handle compression decisions
            writer.add_file(entry.name, entry.data, true);
        }
    }

    return writer.save(path);
}

void ApkHandler::close() {
    entries_.clear();
    path_.clear();
    is_open_ = false;
}

std::vector<std::string> ApkHandler::list_files() const {
    std::vector<std::string> names;
    for (const auto& entry : entries_) {
        names.push_back(entry.name);
    }
    return names;
}

bool ApkHandler::extract_file(const std::string& name, std::vector<uint8_t>& data) const {
    for (const auto& entry : entries_) {
        if (entry.name == name) {
            data = entry.data;
            return true;
        }
    }
    return false;
}

bool ApkHandler::replace_file(const std::string& name, const std::vector<uint8_t>& data) {
    for (auto& entry : entries_) {
        if (entry.name == name) {
            entry.data = data;
            return true;
        }
    }
    return false;
}

bool ApkHandler::add_file(const std::string& name, const std::vector<uint8_t>& data) {
    for (const auto& entry : entries_) {
        if (entry.name == name) {
            return false;
        }
    }
    
    FileEntry entry;
    entry.name = name;
    entry.data = data;
    entry.is_directory = false;
    entries_.push_back(entry);
    return true;
}

bool ApkHandler::delete_file(const std::string& name) {
    auto it = std::remove_if(entries_.begin(), entries_.end(),
        [&name](const FileEntry& entry) { return entry.name == name; });
    
    if (it != entries_.end()) {
        entries_.erase(it, entries_.end());
        return true;
    }
    return false;
}

void ApkHandler::remove_files_by_pattern(const std::string& pattern) {
    entries_.erase(
        std::remove_if(entries_.begin(), entries_.end(),
            [&pattern](const FileEntry& entry) {
                return entry.name.find(pattern) != std::string::npos;
            }),
        entries_.end()
    );
}

} // namespace apk
