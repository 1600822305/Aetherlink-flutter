#include "apk/zip_utils.h"
#include <fstream>
#include <cstring>
#include <algorithm>
#include <mutex>
#include <memory>
#include <cctype>
#ifdef _WIN32
#include <windows.h>
#endif

#define MINIZ_NO_STDIO
#define MINIZ_NO_ARCHIVE_APIS
#define MINIZ_NO_TIME
#define MINIZ_NO_ZLIB_APIS
#include "miniz.h"

namespace apk {

// ZIP format constants
static constexpr uint32_t ZIP_LOCAL_FILE_HEADER_SIG = 0x04034b50;
static constexpr uint32_t ZIP_CENTRAL_DIR_SIG = 0x02014b50;
static constexpr uint32_t ZIP_END_CENTRAL_DIR_SIG = 0x06054b50;

// ZIP structure sizes
static constexpr size_t ZIP_LOCAL_HEADER_SIZE = 30;
static constexpr size_t ZIP_CENTRAL_DIR_ENTRY_SIZE = 46;
static constexpr size_t ZIP_EOCD_SIZE = 22;

// RAII wrapper for miniz allocations
struct MzDeleter {
    void operator()(void* p) const { if (p) mz_free(p); }
};
using MzUniquePtr = std::unique_ptr<void, MzDeleter>;

// Thread-safe CRC32 table initialization
static std::once_flag crc32_init_flag;
static uint32_t crc32_table[256];

static void init_crc32_table() {
    std::call_once(crc32_init_flag, []() {
        for (uint32_t i = 0; i < 256; i++) {
            uint32_t c = i;
            for (int j = 0; j < 8; j++) {
                c = (c & 1) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
            }
            crc32_table[i] = c;
        }
    });
}

static uint32_t calc_crc32(const uint8_t* data, size_t len) {
    init_crc32_table();
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < len; i++) {
        crc = crc32_table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
}

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

static std::vector<uint8_t> deflate_compress(const std::vector<uint8_t>& input) {
    if (input.empty()) return input;
    
    size_t out_len = 0;
    // Use maximum compression level (MZ_BEST_COMPRESSION = 9)
    // TDEFL_WRITE_ZLIB_HEADER is NOT set - we want raw deflate for ZIP
    int flags = tdefl_create_comp_flags_from_zip_params(9, -15, MZ_DEFAULT_STRATEGY);
    MzUniquePtr pComp(tdefl_compress_mem_to_heap(input.data(), input.size(), &out_len, flags));
    
    if (!pComp) {
        return input;
    }
    
    auto* ptr = static_cast<uint8_t*>(pComp.get());
    return std::vector<uint8_t>(ptr, ptr + out_len);
}

static std::vector<uint8_t> deflate_decompress(const uint8_t* data, size_t compressed_size, size_t uncompressed_size) {
    if (compressed_size == 0 || uncompressed_size == 0) {
        return {};
    }

    size_t out_len = 0;
    MzUniquePtr pDecomp(tinfl_decompress_mem_to_heap(data, compressed_size, &out_len, 0));
    
    if (!pDecomp) {
        return {};
    }
    
    auto* ptr = static_cast<uint8_t*>(pDecomp.get());
    return std::vector<uint8_t>(ptr, ptr + out_len);
}

bool ZipReader::open(const std::string& path) {
    std::ifstream file;
#ifdef _WIN32
    // Convert UTF-8 path to wide string for Windows
    int wlen = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), (int)path.size(), nullptr, 0);
    if (wlen > 0) {
        std::wstring wpath(wlen, 0);
        MultiByteToWideChar(CP_UTF8, 0, path.c_str(), (int)path.size(), &wpath[0], wlen);
        file.open(wpath, std::ios::binary);
    }
#else
    file.open(path, std::ios::binary);
#endif
    if (!file.is_open()) return false;

    file.seekg(0, std::ios::end);
    size_t size = file.tellg();
    file.seekg(0, std::ios::beg);

    data_.resize(size);
    file.read(reinterpret_cast<char*>(data_.data()), size);
    file.close();

    return parse_central_directory();
}

bool ZipReader::open(const std::vector<uint8_t>& data) {
    data_ = data;
    return parse_central_directory();
}

void ZipReader::close() {
    data_.clear();
    entries_.clear();
    is_open_ = false;
}

bool ZipReader::parse_central_directory() {
    if (data_.size() < ZIP_EOCD_SIZE) return false;

    // Find End of Central Directory record
    size_t pos = data_.size() - ZIP_EOCD_SIZE;
    while (pos > 0) {
        if (read_le<uint32_t>(&data_[pos]) == ZIP_END_CENTRAL_DIR_SIG) {
            break;
        }
        pos--;
    }

    if (read_le<uint32_t>(&data_[pos]) != ZIP_END_CENTRAL_DIR_SIG) {
        return false;
    }

    // Bounds check for EOCD fields
    if (pos + ZIP_EOCD_SIZE > data_.size()) return false;

    uint16_t num_entries = read_le<uint16_t>(&data_[pos + 10]);
    uint32_t central_dir_offset = read_le<uint32_t>(&data_[pos + 16]);

    size_t offset = central_dir_offset;
    entries_.clear();

    for (uint16_t i = 0; i < num_entries; i++) {
        // Bounds check for central directory entry header
        if (offset + ZIP_CENTRAL_DIR_ENTRY_SIZE > data_.size()) break;
        
        if (read_le<uint32_t>(&data_[offset]) != ZIP_CENTRAL_DIR_SIG) {
            break;
        }

        ZipEntry entry;
        entry.compression_method = read_le<uint16_t>(&data_[offset + 10]);
        entry.crc32 = read_le<uint32_t>(&data_[offset + 16]);
        entry.compressed_size = read_le<uint32_t>(&data_[offset + 20]);
        entry.uncompressed_size = read_le<uint32_t>(&data_[offset + 24]);
        
        uint16_t name_len = read_le<uint16_t>(&data_[offset + 28]);
        uint16_t extra_len = read_le<uint16_t>(&data_[offset + 30]);
        uint16_t comment_len = read_le<uint16_t>(&data_[offset + 32]);
        
        // Bounds check for variable-length fields
        size_t entry_total_size = ZIP_CENTRAL_DIR_ENTRY_SIZE + name_len + extra_len + comment_len;
        if (offset + entry_total_size > data_.size()) break;
        
        entry.local_header_offset = read_le<uint32_t>(&data_[offset + 42]);
        entry.name = std::string(reinterpret_cast<char*>(&data_[offset + ZIP_CENTRAL_DIR_ENTRY_SIZE]), name_len);

        entries_.push_back(std::move(entry));
        offset += entry_total_size;
    }

    is_open_ = true;
    return true;
}

std::vector<std::string> ZipReader::list() const {
    std::vector<std::string> names;
    for (const auto& entry : entries_) {
        names.push_back(entry.name);
    }
    return names;
}

bool ZipReader::extract(const std::string& name, std::vector<uint8_t>& out) const {
    for (const auto& entry : entries_) {
        if (entry.name == name) {
            size_t offset = entry.local_header_offset;
            
            // Bounds check for local file header
            if (offset + ZIP_LOCAL_HEADER_SIZE > data_.size()) {
                return false;
            }
            
            if (read_le<uint32_t>(&data_[offset]) != ZIP_LOCAL_FILE_HEADER_SIG) {
                return false;
            }

            uint16_t name_len = read_le<uint16_t>(&data_[offset + 26]);
            uint16_t extra_len = read_le<uint16_t>(&data_[offset + 28]);
            
            size_t data_offset = offset + ZIP_LOCAL_HEADER_SIZE + name_len + extra_len;
            
            // Bounds check for file data
            if (data_offset + entry.compressed_size > data_.size()) {
                return false;
            }

            if (entry.compression_method == 0) {
                out.resize(entry.uncompressed_size);
                std::memcpy(out.data(), &data_[data_offset], entry.uncompressed_size);
            } else if (entry.compression_method == 8) {
                out = deflate_decompress(&data_[data_offset], entry.compressed_size, entry.uncompressed_size);
            } else {
                return false;
            }

            return true;
        }
    }
    return false;
}

bool ZipReader::extract_all(std::function<void(const std::string&, const std::vector<uint8_t>&)> callback) const {
    for (const auto& entry : entries_) {
        std::vector<uint8_t> data;
        if (extract(entry.name, data)) {
            callback(entry.name, data);
        }
    }
    return true;
}

// Check if file should be stored without compression
static bool should_store(const std::string& name) {
    // resources.arsc MUST be stored (Android requirement for mmap)
    if (name == "resources.arsc") return true;
    
    // Get extension
    size_t dot = name.rfind('.');
    if (dot == std::string::npos) return false;
    std::string ext = name.substr(dot);
    
    // Convert to lowercase for comparison (ASCII-safe)
    for (auto& c : ext) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    
    // Already compressed formats - no benefit from deflate
    static const char* store_exts[] = {
        ".png", ".jpg", ".jpeg", ".gif", ".webp",  // Images (already compressed)
        ".mp3", ".ogg", ".m4a", ".aac", ".flac",   // Audio
        ".mp4", ".webm", ".3gp",                    // Video
        ".zip", ".jar", ".apk",                     // Archives
        ".arsc", ".so"                              // Resources & native libs
    };
    for (const auto& e : store_exts) {
        if (ext == e) return true;
    }
    return false;
}

void ZipWriter::add_file(const std::string& name, const std::vector<uint8_t>& data, bool compress) {
    // Force STORE for certain file types
    if (should_store(name)) {
        add_stored(name, data);
        return;
    }
    
    if (compress && data.size() > 0) {
        std::vector<uint8_t> compressed = deflate_compress(data);
        if (compressed.size() < data.size()) {
            Entry entry;
            entry.name = name;
            entry.compressed_data = compressed;
            entry.uncompressed_size = static_cast<uint32_t>(data.size());
            entry.crc32 = calc_crc32(data.data(), data.size());
            entry.compression_method = 8;
            entries_.push_back(entry);
            return;
        }
    }
    add_stored(name, data);
}

void ZipWriter::add_stored(const std::string& name, const std::vector<uint8_t>& data) {
    Entry entry;
    entry.name = name;
    entry.compressed_data = data;
    entry.uncompressed_size = static_cast<uint32_t>(data.size());
    entry.crc32 = calc_crc32(data.data(), data.size());
    entry.compression_method = 0;
    entries_.push_back(entry);
}

bool ZipWriter::save(const std::string& path) {
    std::vector<uint8_t> data = finalize();
    
    std::ofstream file;
#ifdef _WIN32
    // Convert UTF-8 path to wide string for Windows
    int wlen = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), (int)path.size(), nullptr, 0);
    if (wlen > 0) {
        std::wstring wpath(wlen, 0);
        MultiByteToWideChar(CP_UTF8, 0, path.c_str(), (int)path.size(), &wpath[0], wlen);
        file.open(wpath, std::ios::binary);
    }
#else
    file.open(path, std::ios::binary);
#endif
    if (!file.is_open()) return false;
    
    file.write(reinterpret_cast<char*>(data.data()), data.size());
    return true;
}

std::vector<uint8_t> ZipWriter::finalize() {
    std::vector<uint8_t> output;
    
    uint32_t offset = 0;
    for (auto& entry : entries_) {
        // For uncompressed (stored) files, add padding for 4-byte alignment (zipalign)
        uint16_t extra_len = 0;
        if (entry.compression_method == 0) {
            // Calculate where data will start: offset + 30 + name_len + extra_len
            uint32_t data_start = offset + 30 + static_cast<uint32_t>(entry.name.size());
            uint32_t padding = (4 - (data_start % 4)) % 4;
            extra_len = static_cast<uint16_t>(padding);
        }
        
        entry.local_header_offset = offset;
        
        std::vector<uint8_t> header(30 + entry.name.size() + extra_len);
        write_le<uint32_t>(&header[0], ZIP_LOCAL_FILE_HEADER_SIG);
        write_le<uint16_t>(&header[4], 20);
        write_le<uint16_t>(&header[6], 0);
        write_le<uint16_t>(&header[8], entry.compression_method);
        write_le<uint16_t>(&header[10], 0);
        write_le<uint16_t>(&header[12], 0);
        write_le<uint32_t>(&header[14], entry.crc32);
        write_le<uint32_t>(&header[18], static_cast<uint32_t>(entry.compressed_data.size()));
        write_le<uint32_t>(&header[22], entry.uncompressed_size);
        write_le<uint16_t>(&header[26], static_cast<uint16_t>(entry.name.size()));
        write_le<uint16_t>(&header[28], extra_len);  // Extra field length for alignment
        std::memcpy(&header[30], entry.name.data(), entry.name.size());
        // Extra field is zero-filled for padding
        
        output.insert(output.end(), header.begin(), header.end());
        output.insert(output.end(), entry.compressed_data.begin(), entry.compressed_data.end());
        
        offset = static_cast<uint32_t>(output.size());
    }
    
    uint32_t central_dir_offset = static_cast<uint32_t>(output.size());
    
    for (const auto& entry : entries_) {
        std::vector<uint8_t> cd_entry(46 + entry.name.size());
        write_le<uint32_t>(&cd_entry[0], ZIP_CENTRAL_DIR_SIG);
        write_le<uint16_t>(&cd_entry[4], 20);
        write_le<uint16_t>(&cd_entry[6], 20);
        write_le<uint16_t>(&cd_entry[8], 0);
        write_le<uint16_t>(&cd_entry[10], entry.compression_method);
        write_le<uint16_t>(&cd_entry[12], 0);
        write_le<uint16_t>(&cd_entry[14], 0);
        write_le<uint32_t>(&cd_entry[16], entry.crc32);
        write_le<uint32_t>(&cd_entry[20], static_cast<uint32_t>(entry.compressed_data.size()));
        write_le<uint32_t>(&cd_entry[24], entry.uncompressed_size);
        write_le<uint16_t>(&cd_entry[28], static_cast<uint16_t>(entry.name.size()));
        write_le<uint16_t>(&cd_entry[30], 0);
        write_le<uint16_t>(&cd_entry[32], 0);
        write_le<uint16_t>(&cd_entry[34], 0);
        write_le<uint16_t>(&cd_entry[36], 0);
        write_le<uint32_t>(&cd_entry[38], 0);
        write_le<uint32_t>(&cd_entry[42], entry.local_header_offset);
        std::memcpy(&cd_entry[46], entry.name.data(), entry.name.size());
        
        output.insert(output.end(), cd_entry.begin(), cd_entry.end());
    }
    
    uint32_t central_dir_size = static_cast<uint32_t>(output.size()) - central_dir_offset;
    
    std::vector<uint8_t> eocd(22);
    write_le<uint32_t>(&eocd[0], ZIP_END_CENTRAL_DIR_SIG);
    write_le<uint16_t>(&eocd[4], 0);
    write_le<uint16_t>(&eocd[6], 0);
    write_le<uint16_t>(&eocd[8], static_cast<uint16_t>(entries_.size()));
    write_le<uint16_t>(&eocd[10], static_cast<uint16_t>(entries_.size()));
    write_le<uint32_t>(&eocd[12], central_dir_size);
    write_le<uint32_t>(&eocd[16], central_dir_offset);
    write_le<uint16_t>(&eocd[20], 0);
    
    output.insert(output.end(), eocd.begin(), eocd.end());
    
    return output;
}

} // namespace apk
