#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <functional>

namespace apk {

struct ZipEntry {
    std::string name;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint32_t crc32;
    uint16_t compression_method;
    uint32_t local_header_offset;
    std::vector<uint8_t> data;
};

class ZipReader {
public:
    bool open(const std::string& path);
    bool open(const std::vector<uint8_t>& data);
    void close();

    std::vector<std::string> list() const;
    bool extract(const std::string& name, std::vector<uint8_t>& out) const;
    bool extract_all(std::function<void(const std::string&, const std::vector<uint8_t>&)> callback) const;

private:
    std::vector<ZipEntry> entries_;
    std::vector<uint8_t> data_;
    bool is_open_ = false;

    bool parse_central_directory();
};

class ZipWriter {
public:
    void add_file(const std::string& name, const std::vector<uint8_t>& data, bool compress = true);
    void add_stored(const std::string& name, const std::vector<uint8_t>& data);
    bool save(const std::string& path);
    std::vector<uint8_t> finalize();

private:
    struct Entry {
        std::string name;
        std::vector<uint8_t> compressed_data;
        uint32_t uncompressed_size;
        uint32_t crc32;
        uint16_t compression_method;
        uint32_t local_header_offset;
    };
    std::vector<Entry> entries_;
};

} // namespace apk
