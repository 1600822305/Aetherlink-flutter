#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <map>

namespace dex {

// Dalvik opcode formats
enum class OpcodeFormat {
    k10x,  // op
    k12x,  // op vA, vB
    k11n,  // op vA, #+B
    k11x,  // op vAA
    k10t,  // op +AA
    k20t,  // op +AAAA
    k22x,  // op vAA, vBBBB
    k21t,  // op vAA, +BBBB
    k21s,  // op vAA, #+BBBB
    k21h,  // op vAA, #+BBBB0000(00000000)
    k21c,  // op vAA, type@BBBB / field@BBBB / string@BBBB
    k23x,  // op vAA, vBB, vCC
    k22b,  // op vAA, vBB, #+CC
    k22t,  // op vA, vB, +CCCC
    k22s,  // op vA, vB, #+CCCC
    k22c,  // op vA, vB, type@CCCC / field@CCCC
    k32x,  // op vAAAA, vBBBB
    k30t,  // op +AAAAAAAA
    k31t,  // op vAA, +BBBBBBBB
    k31i,  // op vAA, #+BBBBBBBB
    k31c,  // op vAA, string@BBBBBBBB
    k35c,  // op {vC, vD, vE, vF, vG}, meth@BBBB / type@BBBB
    k3rc,  // op {vCCCC .. vNNNN}, meth@BBBB / type@BBBB
    k51l,  // op vAA, #+BBBBBBBBBBBBBBBB
    kPackedSwitch,
    kSparseSwitch,
    kFillArrayData,
    kUnknown
};

struct OpcodeInfo {
    const char* name;
    OpcodeFormat format;
    uint8_t size;  // in 16-bit code units
};

struct DisassembledInsn {
    uint32_t offset;
    std::string opcode;
    std::string operands;
    std::string comment;
    std::vector<uint16_t> raw_bytes;
};

class SmaliDisassembler {
public:
    SmaliDisassembler() = default;
    ~SmaliDisassembler() = default;

    // Set context for resolving references
    void set_strings(const std::vector<std::string>& strings) { strings_ = strings; }
    void set_types(const std::vector<std::string>& types) { types_ = types; }
    void set_methods(const std::vector<std::string>& methods) { methods_ = methods; }
    void set_fields(const std::vector<std::string>& fields) { fields_ = fields; }

    // Disassemble a single instruction
    DisassembledInsn disassemble_insn(const uint8_t* code, size_t code_size, uint32_t offset);

    // Disassemble entire method code
    std::vector<DisassembledInsn> disassemble_method(const uint8_t* code, size_t code_size);

    // Convert disassembled instructions to Smali text
    std::string to_smali(const std::vector<DisassembledInsn>& insns);

    // Get opcode info
    static const OpcodeInfo& get_opcode_info(uint8_t opcode);
    static int get_opcode_by_name(const std::string& name);

private:
    std::vector<std::string> strings_;
    std::vector<std::string> types_;
    std::vector<std::string> methods_;
    std::vector<std::string> fields_;

    std::string resolve_string(uint32_t idx) const;
    std::string resolve_type(uint32_t idx) const;
    std::string resolve_method(uint32_t idx) const;
    std::string resolve_field(uint32_t idx) const;

    static const OpcodeInfo opcodes_[256];
};

// Smali Assembler - converts Smali text to bytecode
class SmaliAssembler {
public:
    SmaliAssembler() = default;
    ~SmaliAssembler() = default;

    // Set context for reference lookup
    void set_strings(const std::vector<std::string>& strings) { strings_ = strings; }
    void set_types(const std::vector<std::string>& types) { types_ = types; }
    void set_methods(const std::vector<std::string>& methods) { methods_ = methods; }
    void set_fields(const std::vector<std::string>& fields) { fields_ = fields; }

    // Assemble Smali text to bytecode
    bool assemble(const std::string& smali_code, std::vector<uint8_t>& bytecode, std::string& error);

    // Assemble a single instruction
    bool assemble_insn(const std::string& line, std::vector<uint8_t>& bytecode, std::string& error);

private:
    std::vector<std::string> strings_;
    std::vector<std::string> types_;
    std::vector<std::string> methods_;
    std::vector<std::string> fields_;

    int find_string(const std::string& str) const;
    int find_type(const std::string& type) const;
    int find_method(const std::string& method) const;
    int find_field(const std::string& field) const;

    bool parse_register(const std::string& reg, int& num);
    bool parse_int(const std::string& str, int64_t& val);
};

} // namespace dex
