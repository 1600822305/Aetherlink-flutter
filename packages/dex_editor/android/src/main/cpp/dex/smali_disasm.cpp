#include "dex/smali_disasm.h"
#include <sstream>
#include <iomanip>
#include <cstring>
#include <algorithm>

namespace dex {

// Dalvik opcode table (256 opcodes)
const OpcodeInfo SmaliDisassembler::opcodes_[256] = {
    {"nop", OpcodeFormat::k10x, 1},                    // 0x00
    {"move", OpcodeFormat::k12x, 1},                   // 0x01
    {"move/from16", OpcodeFormat::k22x, 2},            // 0x02
    {"move/16", OpcodeFormat::k32x, 3},                // 0x03
    {"move-wide", OpcodeFormat::k12x, 1},              // 0x04
    {"move-wide/from16", OpcodeFormat::k22x, 2},       // 0x05
    {"move-wide/16", OpcodeFormat::k32x, 3},           // 0x06
    {"move-object", OpcodeFormat::k12x, 1},            // 0x07
    {"move-object/from16", OpcodeFormat::k22x, 2},     // 0x08
    {"move-object/16", OpcodeFormat::k32x, 3},         // 0x09
    {"move-result", OpcodeFormat::k11x, 1},            // 0x0a
    {"move-result-wide", OpcodeFormat::k11x, 1},       // 0x0b
    {"move-result-object", OpcodeFormat::k11x, 1},     // 0x0c
    {"move-exception", OpcodeFormat::k11x, 1},         // 0x0d
    {"return-void", OpcodeFormat::k10x, 1},            // 0x0e
    {"return", OpcodeFormat::k11x, 1},                 // 0x0f
    {"return-wide", OpcodeFormat::k11x, 1},            // 0x10
    {"return-object", OpcodeFormat::k11x, 1},          // 0x11
    {"const/4", OpcodeFormat::k11n, 1},                // 0x12
    {"const/16", OpcodeFormat::k21s, 2},               // 0x13
    {"const", OpcodeFormat::k31i, 3},                  // 0x14
    {"const/high16", OpcodeFormat::k21h, 2},           // 0x15
    {"const-wide/16", OpcodeFormat::k21s, 2},          // 0x16
    {"const-wide/32", OpcodeFormat::k31i, 3},          // 0x17
    {"const-wide", OpcodeFormat::k51l, 5},             // 0x18
    {"const-wide/high16", OpcodeFormat::k21h, 2},      // 0x19
    {"const-string", OpcodeFormat::k21c, 2},           // 0x1a
    {"const-string/jumbo", OpcodeFormat::k31c, 3},     // 0x1b
    {"const-class", OpcodeFormat::k21c, 2},            // 0x1c
    {"monitor-enter", OpcodeFormat::k11x, 1},          // 0x1d
    {"monitor-exit", OpcodeFormat::k11x, 1},           // 0x1e
    {"check-cast", OpcodeFormat::k21c, 2},             // 0x1f
    {"instance-of", OpcodeFormat::k22c, 2},            // 0x20
    {"array-length", OpcodeFormat::k12x, 1},           // 0x21
    {"new-instance", OpcodeFormat::k21c, 2},           // 0x22
    {"new-array", OpcodeFormat::k22c, 2},              // 0x23
    {"filled-new-array", OpcodeFormat::k35c, 3},       // 0x24
    {"filled-new-array/range", OpcodeFormat::k3rc, 3}, // 0x25
    {"fill-array-data", OpcodeFormat::k31t, 3},        // 0x26
    {"throw", OpcodeFormat::k11x, 1},                  // 0x27
    {"goto", OpcodeFormat::k10t, 1},                   // 0x28
    {"goto/16", OpcodeFormat::k20t, 2},                // 0x29
    {"goto/32", OpcodeFormat::k30t, 3},                // 0x2a
    {"packed-switch", OpcodeFormat::k31t, 3},          // 0x2b
    {"sparse-switch", OpcodeFormat::k31t, 3},          // 0x2c
    {"cmpl-float", OpcodeFormat::k23x, 2},             // 0x2d
    {"cmpg-float", OpcodeFormat::k23x, 2},             // 0x2e
    {"cmpl-double", OpcodeFormat::k23x, 2},            // 0x2f
    {"cmpg-double", OpcodeFormat::k23x, 2},            // 0x30
    {"cmp-long", OpcodeFormat::k23x, 2},               // 0x31
    {"if-eq", OpcodeFormat::k22t, 2},                  // 0x32
    {"if-ne", OpcodeFormat::k22t, 2},                  // 0x33
    {"if-lt", OpcodeFormat::k22t, 2},                  // 0x34
    {"if-ge", OpcodeFormat::k22t, 2},                  // 0x35
    {"if-gt", OpcodeFormat::k22t, 2},                  // 0x36
    {"if-le", OpcodeFormat::k22t, 2},                  // 0x37
    {"if-eqz", OpcodeFormat::k21t, 2},                 // 0x38
    {"if-nez", OpcodeFormat::k21t, 2},                 // 0x39
    {"if-ltz", OpcodeFormat::k21t, 2},                 // 0x3a
    {"if-gez", OpcodeFormat::k21t, 2},                 // 0x3b
    {"if-gtz", OpcodeFormat::k21t, 2},                 // 0x3c
    {"if-lez", OpcodeFormat::k21t, 2},                 // 0x3d
    {"unused-3e", OpcodeFormat::k10x, 1},              // 0x3e
    {"unused-3f", OpcodeFormat::k10x, 1},              // 0x3f
    {"unused-40", OpcodeFormat::k10x, 1},              // 0x40
    {"unused-41", OpcodeFormat::k10x, 1},              // 0x41
    {"unused-42", OpcodeFormat::k10x, 1},              // 0x42
    {"unused-43", OpcodeFormat::k10x, 1},              // 0x43
    {"aget", OpcodeFormat::k23x, 2},                   // 0x44
    {"aget-wide", OpcodeFormat::k23x, 2},              // 0x45
    {"aget-object", OpcodeFormat::k23x, 2},            // 0x46
    {"aget-boolean", OpcodeFormat::k23x, 2},           // 0x47
    {"aget-byte", OpcodeFormat::k23x, 2},              // 0x48
    {"aget-char", OpcodeFormat::k23x, 2},              // 0x49
    {"aget-short", OpcodeFormat::k23x, 2},             // 0x4a
    {"aput", OpcodeFormat::k23x, 2},                   // 0x4b
    {"aput-wide", OpcodeFormat::k23x, 2},              // 0x4c
    {"aput-object", OpcodeFormat::k23x, 2},            // 0x4d
    {"aput-boolean", OpcodeFormat::k23x, 2},           // 0x4e
    {"aput-byte", OpcodeFormat::k23x, 2},              // 0x4f
    {"aput-char", OpcodeFormat::k23x, 2},              // 0x50
    {"aput-short", OpcodeFormat::k23x, 2},             // 0x51
    {"iget", OpcodeFormat::k22c, 2},                   // 0x52
    {"iget-wide", OpcodeFormat::k22c, 2},              // 0x53
    {"iget-object", OpcodeFormat::k22c, 2},            // 0x54
    {"iget-boolean", OpcodeFormat::k22c, 2},           // 0x55
    {"iget-byte", OpcodeFormat::k22c, 2},              // 0x56
    {"iget-char", OpcodeFormat::k22c, 2},              // 0x57
    {"iget-short", OpcodeFormat::k22c, 2},             // 0x58
    {"iput", OpcodeFormat::k22c, 2},                   // 0x59
    {"iput-wide", OpcodeFormat::k22c, 2},              // 0x5a
    {"iput-object", OpcodeFormat::k22c, 2},            // 0x5b
    {"iput-boolean", OpcodeFormat::k22c, 2},           // 0x5c
    {"iput-byte", OpcodeFormat::k22c, 2},              // 0x5d
    {"iput-char", OpcodeFormat::k22c, 2},              // 0x5e
    {"iput-short", OpcodeFormat::k22c, 2},             // 0x5f
    {"sget", OpcodeFormat::k21c, 2},                   // 0x60
    {"sget-wide", OpcodeFormat::k21c, 2},              // 0x61
    {"sget-object", OpcodeFormat::k21c, 2},            // 0x62
    {"sget-boolean", OpcodeFormat::k21c, 2},           // 0x63
    {"sget-byte", OpcodeFormat::k21c, 2},              // 0x64
    {"sget-char", OpcodeFormat::k21c, 2},              // 0x65
    {"sget-short", OpcodeFormat::k21c, 2},             // 0x66
    {"sput", OpcodeFormat::k21c, 2},                   // 0x67
    {"sput-wide", OpcodeFormat::k21c, 2},              // 0x68
    {"sput-object", OpcodeFormat::k21c, 2},            // 0x69
    {"sput-boolean", OpcodeFormat::k21c, 2},           // 0x6a
    {"sput-byte", OpcodeFormat::k21c, 2},              // 0x6b
    {"sput-char", OpcodeFormat::k21c, 2},              // 0x6c
    {"sput-short", OpcodeFormat::k21c, 2},             // 0x6d
    {"invoke-virtual", OpcodeFormat::k35c, 3},         // 0x6e
    {"invoke-super", OpcodeFormat::k35c, 3},           // 0x6f
    {"invoke-direct", OpcodeFormat::k35c, 3},          // 0x70
    {"invoke-static", OpcodeFormat::k35c, 3},          // 0x71
    {"invoke-interface", OpcodeFormat::k35c, 3},       // 0x72
    {"unused-73", OpcodeFormat::k10x, 1},              // 0x73
    {"invoke-virtual/range", OpcodeFormat::k3rc, 3},   // 0x74
    {"invoke-super/range", OpcodeFormat::k3rc, 3},     // 0x75
    {"invoke-direct/range", OpcodeFormat::k3rc, 3},    // 0x76
    {"invoke-static/range", OpcodeFormat::k3rc, 3},    // 0x77
    {"invoke-interface/range", OpcodeFormat::k3rc, 3}, // 0x78
    {"unused-79", OpcodeFormat::k10x, 1},              // 0x79
    {"unused-7a", OpcodeFormat::k10x, 1},              // 0x7a
    {"neg-int", OpcodeFormat::k12x, 1},                // 0x7b
    {"not-int", OpcodeFormat::k12x, 1},                // 0x7c
    {"neg-long", OpcodeFormat::k12x, 1},               // 0x7d
    {"not-long", OpcodeFormat::k12x, 1},               // 0x7e
    {"neg-float", OpcodeFormat::k12x, 1},              // 0x7f
    {"neg-double", OpcodeFormat::k12x, 1},             // 0x80
    {"int-to-long", OpcodeFormat::k12x, 1},            // 0x81
    {"int-to-float", OpcodeFormat::k12x, 1},           // 0x82
    {"int-to-double", OpcodeFormat::k12x, 1},          // 0x83
    {"long-to-int", OpcodeFormat::k12x, 1},            // 0x84
    {"long-to-float", OpcodeFormat::k12x, 1},          // 0x85
    {"long-to-double", OpcodeFormat::k12x, 1},         // 0x86
    {"float-to-int", OpcodeFormat::k12x, 1},           // 0x87
    {"float-to-long", OpcodeFormat::k12x, 1},          // 0x88
    {"float-to-double", OpcodeFormat::k12x, 1},        // 0x89
    {"double-to-int", OpcodeFormat::k12x, 1},          // 0x8a
    {"double-to-long", OpcodeFormat::k12x, 1},         // 0x8b
    {"double-to-float", OpcodeFormat::k12x, 1},        // 0x8c
    {"int-to-byte", OpcodeFormat::k12x, 1},            // 0x8d
    {"int-to-char", OpcodeFormat::k12x, 1},            // 0x8e
    {"int-to-short", OpcodeFormat::k12x, 1},           // 0x8f
    {"add-int", OpcodeFormat::k23x, 2},                // 0x90
    {"sub-int", OpcodeFormat::k23x, 2},                // 0x91
    {"mul-int", OpcodeFormat::k23x, 2},                // 0x92
    {"div-int", OpcodeFormat::k23x, 2},                // 0x93
    {"rem-int", OpcodeFormat::k23x, 2},                // 0x94
    {"and-int", OpcodeFormat::k23x, 2},                // 0x95
    {"or-int", OpcodeFormat::k23x, 2},                 // 0x96
    {"xor-int", OpcodeFormat::k23x, 2},                // 0x97
    {"shl-int", OpcodeFormat::k23x, 2},                // 0x98
    {"shr-int", OpcodeFormat::k23x, 2},                // 0x99
    {"ushr-int", OpcodeFormat::k23x, 2},               // 0x9a
    {"add-long", OpcodeFormat::k23x, 2},               // 0x9b
    {"sub-long", OpcodeFormat::k23x, 2},               // 0x9c
    {"mul-long", OpcodeFormat::k23x, 2},               // 0x9d
    {"div-long", OpcodeFormat::k23x, 2},               // 0x9e
    {"rem-long", OpcodeFormat::k23x, 2},               // 0x9f
    {"and-long", OpcodeFormat::k23x, 2},               // 0xa0
    {"or-long", OpcodeFormat::k23x, 2},                // 0xa1
    {"xor-long", OpcodeFormat::k23x, 2},               // 0xa2
    {"shl-long", OpcodeFormat::k23x, 2},               // 0xa3
    {"shr-long", OpcodeFormat::k23x, 2},               // 0xa4
    {"ushr-long", OpcodeFormat::k23x, 2},              // 0xa5
    {"add-float", OpcodeFormat::k23x, 2},              // 0xa6
    {"sub-float", OpcodeFormat::k23x, 2},              // 0xa7
    {"mul-float", OpcodeFormat::k23x, 2},              // 0xa8
    {"div-float", OpcodeFormat::k23x, 2},              // 0xa9
    {"rem-float", OpcodeFormat::k23x, 2},              // 0xaa
    {"add-double", OpcodeFormat::k23x, 2},             // 0xab
    {"sub-double", OpcodeFormat::k23x, 2},             // 0xac
    {"mul-double", OpcodeFormat::k23x, 2},             // 0xad
    {"div-double", OpcodeFormat::k23x, 2},             // 0xae
    {"rem-double", OpcodeFormat::k23x, 2},             // 0xaf
    {"add-int/2addr", OpcodeFormat::k12x, 1},          // 0xb0
    {"sub-int/2addr", OpcodeFormat::k12x, 1},          // 0xb1
    {"mul-int/2addr", OpcodeFormat::k12x, 1},          // 0xb2
    {"div-int/2addr", OpcodeFormat::k12x, 1},          // 0xb3
    {"rem-int/2addr", OpcodeFormat::k12x, 1},          // 0xb4
    {"and-int/2addr", OpcodeFormat::k12x, 1},          // 0xb5
    {"or-int/2addr", OpcodeFormat::k12x, 1},           // 0xb6
    {"xor-int/2addr", OpcodeFormat::k12x, 1},          // 0xb7
    {"shl-int/2addr", OpcodeFormat::k12x, 1},          // 0xb8
    {"shr-int/2addr", OpcodeFormat::k12x, 1},          // 0xb9
    {"ushr-int/2addr", OpcodeFormat::k12x, 1},         // 0xba
    {"add-long/2addr", OpcodeFormat::k12x, 1},         // 0xbb
    {"sub-long/2addr", OpcodeFormat::k12x, 1},         // 0xbc
    {"mul-long/2addr", OpcodeFormat::k12x, 1},         // 0xbd
    {"div-long/2addr", OpcodeFormat::k12x, 1},         // 0xbe
    {"rem-long/2addr", OpcodeFormat::k12x, 1},         // 0xbf
    {"and-long/2addr", OpcodeFormat::k12x, 1},         // 0xc0
    {"or-long/2addr", OpcodeFormat::k12x, 1},          // 0xc1
    {"xor-long/2addr", OpcodeFormat::k12x, 1},         // 0xc2
    {"shl-long/2addr", OpcodeFormat::k12x, 1},         // 0xc3
    {"shr-long/2addr", OpcodeFormat::k12x, 1},         // 0xc4
    {"ushr-long/2addr", OpcodeFormat::k12x, 1},        // 0xc5
    {"add-float/2addr", OpcodeFormat::k12x, 1},        // 0xc6
    {"sub-float/2addr", OpcodeFormat::k12x, 1},        // 0xc7
    {"mul-float/2addr", OpcodeFormat::k12x, 1},        // 0xc8
    {"div-float/2addr", OpcodeFormat::k12x, 1},        // 0xc9
    {"rem-float/2addr", OpcodeFormat::k12x, 1},        // 0xca
    {"add-double/2addr", OpcodeFormat::k12x, 1},       // 0xcb
    {"sub-double/2addr", OpcodeFormat::k12x, 1},       // 0xcc
    {"mul-double/2addr", OpcodeFormat::k12x, 1},       // 0xcd
    {"div-double/2addr", OpcodeFormat::k12x, 1},       // 0xce
    {"rem-double/2addr", OpcodeFormat::k12x, 1},       // 0xcf
    {"add-int/lit16", OpcodeFormat::k22s, 2},          // 0xd0
    {"rsub-int", OpcodeFormat::k22s, 2},               // 0xd1
    {"mul-int/lit16", OpcodeFormat::k22s, 2},          // 0xd2
    {"div-int/lit16", OpcodeFormat::k22s, 2},          // 0xd3
    {"rem-int/lit16", OpcodeFormat::k22s, 2},          // 0xd4
    {"and-int/lit16", OpcodeFormat::k22s, 2},          // 0xd5
    {"or-int/lit16", OpcodeFormat::k22s, 2},           // 0xd6
    {"xor-int/lit16", OpcodeFormat::k22s, 2},          // 0xd7
    {"add-int/lit8", OpcodeFormat::k22b, 2},           // 0xd8
    {"rsub-int/lit8", OpcodeFormat::k22b, 2},          // 0xd9
    {"mul-int/lit8", OpcodeFormat::k22b, 2},           // 0xda
    {"div-int/lit8", OpcodeFormat::k22b, 2},           // 0xdb
    {"rem-int/lit8", OpcodeFormat::k22b, 2},           // 0xdc
    {"and-int/lit8", OpcodeFormat::k22b, 2},           // 0xdd
    {"or-int/lit8", OpcodeFormat::k22b, 2},            // 0xde
    {"xor-int/lit8", OpcodeFormat::k22b, 2},           // 0xdf
    {"shl-int/lit8", OpcodeFormat::k22b, 2},           // 0xe0
    {"shr-int/lit8", OpcodeFormat::k22b, 2},           // 0xe1
    {"ushr-int/lit8", OpcodeFormat::k22b, 2},          // 0xe2
    {"unused-e3", OpcodeFormat::k10x, 1},              // 0xe3
    {"unused-e4", OpcodeFormat::k10x, 1},              // 0xe4
    {"unused-e5", OpcodeFormat::k10x, 1},              // 0xe5
    {"unused-e6", OpcodeFormat::k10x, 1},              // 0xe6
    {"unused-e7", OpcodeFormat::k10x, 1},              // 0xe7
    {"unused-e8", OpcodeFormat::k10x, 1},              // 0xe8
    {"unused-e9", OpcodeFormat::k10x, 1},              // 0xe9
    {"unused-ea", OpcodeFormat::k10x, 1},              // 0xea
    {"unused-eb", OpcodeFormat::k10x, 1},              // 0xeb
    {"unused-ec", OpcodeFormat::k10x, 1},              // 0xec
    {"unused-ed", OpcodeFormat::k10x, 1},              // 0xed
    {"unused-ee", OpcodeFormat::k10x, 1},              // 0xee
    {"unused-ef", OpcodeFormat::k10x, 1},              // 0xef
    {"unused-f0", OpcodeFormat::k10x, 1},              // 0xf0
    {"unused-f1", OpcodeFormat::k10x, 1},              // 0xf1
    {"unused-f2", OpcodeFormat::k10x, 1},              // 0xf2
    {"unused-f3", OpcodeFormat::k10x, 1},              // 0xf3
    {"unused-f4", OpcodeFormat::k10x, 1},              // 0xf4
    {"unused-f5", OpcodeFormat::k10x, 1},              // 0xf5
    {"unused-f6", OpcodeFormat::k10x, 1},              // 0xf6
    {"unused-f7", OpcodeFormat::k10x, 1},              // 0xf7
    {"unused-f8", OpcodeFormat::k10x, 1},              // 0xf8
    {"unused-f9", OpcodeFormat::k10x, 1},              // 0xf9
    {"unused-fa", OpcodeFormat::k10x, 1},              // 0xfa
    {"unused-fb", OpcodeFormat::k10x, 1},              // 0xfb
    {"unused-fc", OpcodeFormat::k10x, 1},              // 0xfc
    {"unused-fd", OpcodeFormat::k10x, 1},              // 0xfd
    {"unused-fe", OpcodeFormat::k10x, 1},              // 0xfe
    {"unused-ff", OpcodeFormat::k10x, 1},              // 0xff
};

template<typename T>
static T read_le(const uint8_t* p) {
    T val = 0;
    for (size_t i = 0; i < sizeof(T); i++) {
        val |= static_cast<T>(p[i]) << (i * 8);
    }
    return val;
}

const OpcodeInfo& SmaliDisassembler::get_opcode_info(uint8_t opcode) {
    return opcodes_[opcode];
}

std::string SmaliDisassembler::resolve_string(uint32_t idx) const {
    if (idx < strings_.size()) {
        return "\"" + strings_[idx] + "\"";
    }
    return "string@" + std::to_string(idx);
}

std::string SmaliDisassembler::resolve_type(uint32_t idx) const {
    if (idx < types_.size()) {
        return types_[idx];
    }
    return "type@" + std::to_string(idx);
}

std::string SmaliDisassembler::resolve_method(uint32_t idx) const {
    if (idx < methods_.size()) {
        return methods_[idx];
    }
    return "method@" + std::to_string(idx);
}

std::string SmaliDisassembler::resolve_field(uint32_t idx) const {
    if (idx < fields_.size()) {
        return fields_[idx];
    }
    return "field@" + std::to_string(idx);
}

DisassembledInsn SmaliDisassembler::disassemble_insn(const uint8_t* code, size_t code_size, uint32_t offset) {
    DisassembledInsn insn;
    insn.offset = offset;
    
    if (code_size < 2) {
        insn.opcode = "invalid";
        return insn;
    }
    
    uint8_t op = code[0];
    const OpcodeInfo& info = opcodes_[op];
    insn.opcode = info.name;
    
    // Store raw bytes
    size_t byte_size = info.size * 2;
    for (size_t i = 0; i < byte_size && i < code_size; i += 2) {
        insn.raw_bytes.push_back(read_le<uint16_t>(&code[i]));
    }
    
    std::ostringstream oss;
    
    switch (info.format) {
        case OpcodeFormat::k10x:
            // No operands
            break;
            
        case OpcodeFormat::k12x: {
            // k12x format: B|A|op, A is low 4 bits, B is high 4 bits
            uint8_t vA = code[1] & 0xF;
            uint8_t vB = (code[1] >> 4) & 0xF;
            oss << "v" << (int)vA << ", v" << (int)vB;
            break;
        }
        
        case OpcodeFormat::k11n: {
            uint8_t vA = code[1] & 0xF;
            int8_t B = (code[1] >> 4);
            if (B & 0x8) B |= 0xF0; // Sign extend
            oss << "v" << (int)vA << ", #int " << (int)B;
            break;
        }
        
        case OpcodeFormat::k11x: {
            uint8_t vAA = code[1];
            oss << "v" << (int)vAA;
            break;
        }
        
        case OpcodeFormat::k10t: {
            int8_t AA = static_cast<int8_t>(code[1]);
            oss << std::showpos << (int)AA << std::noshowpos;
            insn.comment = "goto " + std::to_string(offset / 2 + AA);
            break;
        }
        
        case OpcodeFormat::k20t: {
            int16_t AAAA = read_le<int16_t>(&code[2]);
            oss << std::showpos << (int)AAAA << std::noshowpos;
            insn.comment = "goto " + std::to_string(offset / 2 + AAAA);
            break;
        }
        
        case OpcodeFormat::k22x: {
            uint8_t vAA = code[1];
            uint16_t vBBBB = read_le<uint16_t>(&code[2]);
            oss << "v" << (int)vAA << ", v" << (int)vBBBB;
            break;
        }
        
        case OpcodeFormat::k21t: {
            uint8_t vAA = code[1];
            int16_t BBBB = read_le<int16_t>(&code[2]);
            oss << "v" << (int)vAA << ", " << std::showpos << (int)BBBB << std::noshowpos;
            insn.comment = "target " + std::to_string(offset / 2 + BBBB);
            break;
        }
        
        case OpcodeFormat::k21s: {
            uint8_t vAA = code[1];
            int16_t BBBB = read_le<int16_t>(&code[2]);
            oss << "v" << (int)vAA << ", #int " << (int)BBBB;
            break;
        }
        
        case OpcodeFormat::k21h: {
            uint8_t vAA = code[1];
            int16_t BBBB = read_le<int16_t>(&code[2]);
            if (op == 0x15) { // const/high16
                oss << "v" << (int)vAA << ", #int " << ((int)BBBB << 16);
            } else { // const-wide/high16
                oss << "v" << (int)vAA << ", #long " << ((int64_t)BBBB << 48);
            }
            break;
        }
        
        case OpcodeFormat::k21c: {
            uint8_t vAA = code[1];
            uint16_t BBBB = read_le<uint16_t>(&code[2]);
            oss << "v" << (int)vAA << ", ";
            if (op == 0x1a) { // const-string
                oss << resolve_string(BBBB);
            } else if (op == 0x1c || op == 0x1f || op == 0x22) { // const-class, check-cast, new-instance
                oss << resolve_type(BBBB);
            } else if (op >= 0x60 && op <= 0x6d) { // sget/sput
                oss << resolve_field(BBBB);
            } else {
                oss << "ref@" << BBBB;
            }
            break;
        }
        
        case OpcodeFormat::k23x: {
            uint8_t vAA = code[1];
            uint8_t vBB = code[2];
            uint8_t vCC = code[3];
            oss << "v" << (int)vAA << ", v" << (int)vBB << ", v" << (int)vCC;
            break;
        }
        
        case OpcodeFormat::k22b: {
            uint8_t vAA = code[1];
            uint8_t vBB = code[2];
            int8_t CC = static_cast<int8_t>(code[3]);
            oss << "v" << (int)vAA << ", v" << (int)vBB << ", #int " << (int)CC;
            break;
        }
        
        case OpcodeFormat::k22t: {
            uint8_t vA = code[1] & 0xF;
            uint8_t vB = (code[1] >> 4) & 0xF;
            int16_t CCCC = read_le<int16_t>(&code[2]);
            oss << "v" << (int)vA << ", v" << (int)vB << ", " << std::showpos << (int)CCCC << std::noshowpos;
            insn.comment = "target " + std::to_string(offset / 2 + CCCC);
            break;
        }
        
        case OpcodeFormat::k22s: {
            uint8_t vA = code[1] & 0xF;
            uint8_t vB = (code[1] >> 4) & 0xF;
            int16_t CCCC = read_le<int16_t>(&code[2]);
            oss << "v" << (int)vA << ", v" << (int)vB << ", #int " << (int)CCCC;
            break;
        }
        
        case OpcodeFormat::k22c: {
            uint8_t vA = code[1] & 0xF;
            uint8_t vB = (code[1] >> 4) & 0xF;
            uint16_t CCCC = read_le<uint16_t>(&code[2]);
            oss << "v" << (int)vA << ", v" << (int)vB << ", ";
            if (op == 0x20 || op == 0x23) { // instance-of, new-array
                oss << resolve_type(CCCC);
            } else { // iget/iput
                oss << resolve_field(CCCC);
            }
            break;
        }
        
        case OpcodeFormat::k32x: {
            uint16_t vAAAA = read_le<uint16_t>(&code[2]);
            uint16_t vBBBB = read_le<uint16_t>(&code[4]);
            oss << "v" << (int)vAAAA << ", v" << (int)vBBBB;
            break;
        }
        
        case OpcodeFormat::k30t: {
            int32_t AAAAAAAA = read_le<int32_t>(&code[2]);
            oss << std::showpos << AAAAAAAA << std::noshowpos;
            insn.comment = "goto " + std::to_string(offset / 2 + AAAAAAAA);
            break;
        }
        
        case OpcodeFormat::k31t: {
            uint8_t vAA = code[1];
            int32_t BBBBBBBB = read_le<int32_t>(&code[2]);
            oss << "v" << (int)vAA << ", " << std::showpos << BBBBBBBB << std::noshowpos;
            break;
        }
        
        case OpcodeFormat::k31i: {
            uint8_t vAA = code[1];
            int32_t BBBBBBBB = read_le<int32_t>(&code[2]);
            oss << "v" << (int)vAA << ", #int " << BBBBBBBB;
            break;
        }
        
        case OpcodeFormat::k31c: {
            uint8_t vAA = code[1];
            uint32_t BBBBBBBB = read_le<uint32_t>(&code[2]);
            oss << "v" << (int)vAA << ", " << resolve_string(BBBBBBBB);
            break;
        }
        
        case OpcodeFormat::k35c: {
            // k35c format: A|G|op BBBB F|E|D|C
            // A = register count (high 4 bits of code[1])
            // G = 5th register if A=5 (low 4 bits of code[1])
            // C = low 4 bits of code[4]
            // D = high 4 bits of code[4]
            // E = low 4 bits of code[5]
            // F = high 4 bits of code[5]
            uint8_t A = (code[1] >> 4) & 0xF;
            uint8_t G = code[1] & 0xF;
            uint16_t BBBB = read_le<uint16_t>(&code[2]);
            uint8_t C = code[4] & 0xF;
            uint8_t D = (code[4] >> 4) & 0xF;
            uint8_t E = code[5] & 0xF;
            uint8_t F = (code[5] >> 4) & 0xF;
            
            oss << "{";
            uint8_t regs[] = {C, D, E, F, G};
            for (int i = 0; i < A && i < 5; i++) {
                if (i > 0) oss << ", ";
                oss << "v" << (int)regs[i];
            }
            oss << "}, ";
            
            if (op >= 0x6e && op <= 0x72) { // invoke-*
                oss << resolve_method(BBBB);
            } else {
                oss << resolve_type(BBBB);
            }
            break;
        }
        
        case OpcodeFormat::k3rc: {
            uint8_t AA = code[1];
            uint16_t BBBB = read_le<uint16_t>(&code[2]);
            uint16_t CCCC = read_le<uint16_t>(&code[4]);
            
            oss << "{v" << CCCC << " .. v" << (CCCC + AA - 1) << "}, ";
            if (op >= 0x74 && op <= 0x78) { // invoke-*/range
                oss << resolve_method(BBBB);
            } else {
                oss << resolve_type(BBBB);
            }
            break;
        }
        
        case OpcodeFormat::k51l: {
            uint8_t vAA = code[1];
            int64_t BBBBBBBBBBBBBBBB = read_le<int64_t>(&code[2]);
            oss << "v" << (int)vAA << ", #long " << BBBBBBBBBBBBBBBB;
            break;
        }
        
        default:
            oss << "?";
            break;
    }
    
    insn.operands = oss.str();
    return insn;
}

std::vector<DisassembledInsn> SmaliDisassembler::disassemble_method(const uint8_t* code, size_t code_size) {
    std::vector<DisassembledInsn> result;
    
    size_t offset = 0;
    while (offset < code_size) {
        DisassembledInsn insn = disassemble_insn(code + offset, code_size - offset, offset);
        
        uint8_t op = code[offset];
        size_t insn_size = opcodes_[op].size * 2;
        
        result.push_back(insn);
        offset += insn_size;
        
        if (insn_size == 0) break; // Safety
    }
    
    return result;
}

std::string SmaliDisassembler::to_smali(const std::vector<DisassembledInsn>& insns) {
    std::ostringstream oss;
    
    for (const auto& insn : insns) {
        oss << "    " << insn.opcode;
        if (!insn.operands.empty()) {
            oss << " " << insn.operands;
        }
        if (!insn.comment.empty()) {
            oss << " # " << insn.comment;
        }
        oss << "\n";
    }
    
    return oss.str();
}

int SmaliDisassembler::get_opcode_by_name(const std::string& name) {
    for (int i = 0; i < 256; i++) {
        if (opcodes_[i].name == name) {
            return i;
        }
    }
    return -1;
}

// SmaliAssembler implementation

template<typename T>
static void write_le(uint8_t* p, T val) {
    for (size_t i = 0; i < sizeof(T); i++) {
        p[i] = static_cast<uint8_t>(val >> (i * 8));
    }
}

int SmaliAssembler::find_string(const std::string& str) const {
    for (size_t i = 0; i < strings_.size(); i++) {
        if (strings_[i] == str) return static_cast<int>(i);
    }
    return -1;
}

int SmaliAssembler::find_type(const std::string& type) const {
    for (size_t i = 0; i < types_.size(); i++) {
        if (types_[i] == type) return static_cast<int>(i);
    }
    return -1;
}

int SmaliAssembler::find_method(const std::string& method) const {
    // First try exact match
    for (size_t i = 0; i < methods_.size(); i++) {
        if (methods_[i] == method) return static_cast<int>(i);
    }
    // Then try substring match (for cases like partial method signatures)
    for (size_t i = 0; i < methods_.size(); i++) {
        if (methods_[i].find(method) != std::string::npos) return static_cast<int>(i);
    }
    return -1;
}

int SmaliAssembler::find_field(const std::string& field) const {
    // First try exact match
    for (size_t i = 0; i < fields_.size(); i++) {
        if (fields_[i] == field) return static_cast<int>(i);
    }
    // Then try substring match (for cases like partial field references)
    for (size_t i = 0; i < fields_.size(); i++) {
        if (fields_[i].find(field) != std::string::npos) return static_cast<int>(i);
    }
    return -1;
}

bool SmaliAssembler::parse_register(const std::string& reg, int& num) {
    if (reg.empty() || reg[0] != 'v') return false;
    try {
        num = std::stoi(reg.substr(1));
        return true;
    } catch (...) {
        return false;
    }
}

bool SmaliAssembler::parse_int(const std::string& str, int64_t& val) {
    try {
        if (str.find("0x") == 0 || str.find("0X") == 0) {
            val = std::stoll(str, nullptr, 16);
        } else {
            val = std::stoll(str);
        }
        return true;
    } catch (...) {
        return false;
    }
}

bool SmaliAssembler::assemble_insn(const std::string& line, std::vector<uint8_t>& bytecode, std::string& error) {
    // Parse line: ".XXXX: opcode operands // comment"
    std::string trimmed = line;
    
    // Remove leading whitespace
    size_t start = trimmed.find_first_not_of(" \t");
    if (start == std::string::npos) return true; // Empty line
    trimmed = trimmed.substr(start);
    
    // Skip directives and offset labels
    if (trimmed[0] == '.') {
        size_t colon = trimmed.find(':');
        if (colon != std::string::npos && colon < 8) {
            // Offset label like .0000: - extract instruction after it
            trimmed = trimmed.substr(colon + 1);
            start = trimmed.find_first_not_of(" \t");
            if (start == std::string::npos) return true;
            trimmed = trimmed.substr(start);
        } else {
            // Skip other directives like .method, .registers, .end, .line, etc
            return true;
        }
    }
    
    // Remove comment (only outside quotes)
    bool in_str = false;
    size_t comment_pos = std::string::npos;
    for (size_t i = 0; i < trimmed.size(); i++) {
        if (trimmed[i] == '"') in_str = !in_str;
        if (!in_str && i + 1 < trimmed.size() && trimmed[i] == '/' && trimmed[i+1] == '/') {
            comment_pos = i;
            break;
        }
    }
    if (comment_pos != std::string::npos) {
        trimmed = trimmed.substr(0, comment_pos);
    }
    
    // Remove \r characters (Windows line endings)
    trimmed.erase(std::remove(trimmed.begin(), trimmed.end(), '\r'), trimmed.end());
    
    // Trim trailing whitespace
    size_t end = trimmed.find_last_not_of(" \t\n");
    if (end != std::string::npos) {
        trimmed = trimmed.substr(0, end + 1);
    }
    
    if (trimmed.empty()) return true;
    
    // Split opcode and operands
    size_t space = trimmed.find(' ');
    std::string opcode_name = (space != std::string::npos) ? trimmed.substr(0, space) : trimmed;
    std::string operands = (space != std::string::npos) ? trimmed.substr(space + 1) : "";
    
    // Trim operands
    start = operands.find_first_not_of(" \t");
    if (start != std::string::npos) {
        operands = operands.substr(start);
    }
    
    // Find opcode
    int op = SmaliDisassembler::get_opcode_by_name(opcode_name);
    if (op < 0) {
        error = "Unknown opcode: " + opcode_name;
        return false;
    }
    
    const OpcodeInfo& info = SmaliDisassembler::get_opcode_info(static_cast<uint8_t>(op));
    size_t insn_size = info.size * 2;
    
    std::vector<uint8_t> insn(insn_size, 0);
    insn[0] = static_cast<uint8_t>(op);
    
    // Parse operands based on format
    std::vector<std::string> parts;
    std::string current;
    bool in_brace = false;
    bool in_quote = false;
    for (char c : operands) {
        if (c == '"' && !in_brace) in_quote = !in_quote;
        if (c == '{' && !in_quote) in_brace = true;
        if (c == '}' && !in_quote) in_brace = false;
        if (c == ',' && !in_brace && !in_quote) {
            size_t s = current.find_first_not_of(" \t");
            size_t e = current.find_last_not_of(" \t");
            if (s != std::string::npos && e != std::string::npos) {
                parts.push_back(current.substr(s, e - s + 1));
            }
            current.clear();
        } else {
            current += c;
        }
    }
    if (!current.empty()) {
        size_t s = current.find_first_not_of(" \t");
        size_t e = current.find_last_not_of(" \t");
        if (s != std::string::npos && e != std::string::npos) {
            parts.push_back(current.substr(s, e - s + 1));
        }
    }
    
    switch (info.format) {
        case OpcodeFormat::k10x:
            // No operands
            break;
            
        case OpcodeFormat::k12x: {
            // k12x format: B|A|op, A is low 4 bits, B is high 4 bits
            if (parts.size() < 2) { error = "Expected 2 registers"; return false; }
            int vA, vB;
            if (!parse_register(parts[0], vA) || !parse_register(parts[1], vB)) {
                error = "Invalid registers"; return false;
            }
            insn[1] = static_cast<uint8_t>((vB << 4) | (vA & 0xF));
            break;
        }
        
        case OpcodeFormat::k11n: {
            if (parts.size() < 2) { error = "Expected register and literal"; return false; }
            int vA;
            int64_t lit;
            if (!parse_register(parts[0], vA)) { error = "Invalid register"; return false; }
            std::string lit_str = parts[1];
            if (lit_str.find("#int") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#int") + 5);
            }
            if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
            insn[1] = static_cast<uint8_t>(((lit & 0xF) << 4) | (vA & 0xF));
            break;
        }
        
        case OpcodeFormat::k11x: {
            if (parts.size() < 1) { error = "Expected register"; return false; }
            int vAA;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            break;
        }
        
        case OpcodeFormat::k21s: {
            if (parts.size() < 2) { error = "Expected register and literal"; return false; }
            int vAA;
            int64_t lit;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            std::string lit_str = parts[1];
            if (lit_str.find("#int") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#int") + 5);
            }
            if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<int16_t>(&insn[2], static_cast<int16_t>(lit));
            break;
        }
        
        case OpcodeFormat::k21c: {
            if (parts.size() < 2) { error = "Expected register and reference"; return false; }
            int vAA;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            
            std::string ref = parts[1];
            int idx = -1;
            
            if (ref[0] == '"') {
                // String literal
                std::string str = ref.substr(1, ref.length() - 2);
                idx = find_string(str);
                if (idx < 0) { error = "String not found: " + str; return false; }
            } else if (ref.find("->") != std::string::npos) {
                // Field reference (Lclass;->name:type)
                idx = find_field(ref);
                if (idx < 0) { error = "Field not found: " + ref; return false; }
            } else if (ref.find("field@") == 0) {
                idx = std::stoi(ref.substr(6));
            } else if (ref[0] == 'L' || ref.find("type@") == 0) {
                idx = find_type(ref);
                if (idx < 0) { error = "Type not found: " + ref; return false; }
            } else {
                idx = find_field(ref);
                if (idx < 0) { error = "Reference not found: " + ref; return false; }
            }
            write_le<uint16_t>(&insn[2], static_cast<uint16_t>(idx));
            break;
        }
        
        case OpcodeFormat::k22c: {
            // vA, vB, type@CCCC or field@CCCC
            if (parts.size() < 3) { error = "Expected 2 registers and reference"; return false; }
            int vA, vB;
            if (!parse_register(parts[0], vA) || !parse_register(parts[1], vB)) {
                error = "Invalid registers"; return false;
            }
            insn[1] = static_cast<uint8_t>((vB << 4) | (vA & 0xF));
            
            std::string ref = parts[2];
            int idx = find_field(ref);
            if (idx < 0) {
                idx = find_type(ref);
            }
            if (idx < 0) { error = "Reference not found: " + ref; return false; }
            write_le<uint16_t>(&insn[2], static_cast<uint16_t>(idx));
            break;
        }
        
        case OpcodeFormat::k23x: {
            // vAA, vBB, vCC
            if (parts.size() < 3) { error = "Expected 3 registers"; return false; }
            int vAA, vBB, vCC;
            if (!parse_register(parts[0], vAA) || !parse_register(parts[1], vBB) || !parse_register(parts[2], vCC)) {
                error = "Invalid registers"; return false;
            }
            insn[1] = static_cast<uint8_t>(vAA);
            insn[2] = static_cast<uint8_t>(vBB);
            insn[3] = static_cast<uint8_t>(vCC);
            break;
        }
        
        case OpcodeFormat::k10t: {
            // +AA (goto)
            int64_t offset_val;
            std::string offset_str = parts.size() > 0 ? parts[0] : "0";
            if (!parse_int(offset_str, offset_val)) { error = "Invalid offset"; return false; }
            insn[1] = static_cast<uint8_t>(static_cast<int8_t>(offset_val));
            break;
        }
        
        case OpcodeFormat::k20t: {
            // +AAAA (goto/16)
            int64_t offset_val;
            std::string offset_str = parts.size() > 0 ? parts[0] : "0";
            if (!parse_int(offset_str, offset_val)) { error = "Invalid offset"; return false; }
            write_le<int16_t>(&insn[2], static_cast<int16_t>(offset_val));
            break;
        }
        
        case OpcodeFormat::k21t: {
            // vAA, +BBBB (if-*z)
            if (parts.size() < 2) { error = "Expected register and offset"; return false; }
            int vAA;
            int64_t offset_val;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            if (!parse_int(parts[1], offset_val)) { error = "Invalid offset"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<int16_t>(&insn[2], static_cast<int16_t>(offset_val));
            break;
        }
        
        case OpcodeFormat::k21h: {
            // vAA, #+BBBB0000 (const/high16, const-wide/high16)
            if (parts.size() < 2) { error = "Expected register and literal"; return false; }
            int vAA;
            int64_t lit;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            std::string lit_str = parts[1];
            if (lit_str.find("#int") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#int") + 5);
                if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
                lit = lit >> 16; // Extract high 16 bits
            } else if (lit_str.find("#long") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#long") + 6);
                if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
                lit = lit >> 48; // Extract high 16 bits
            } else {
                if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
            }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<int16_t>(&insn[2], static_cast<int16_t>(lit));
            break;
        }
        
        case OpcodeFormat::k22b: {
            // vAA, vBB, #+CC
            if (parts.size() < 3) { error = "Expected 2 registers and literal"; return false; }
            int vAA, vBB;
            int64_t lit;
            if (!parse_register(parts[0], vAA) || !parse_register(parts[1], vBB)) {
                error = "Invalid registers"; return false;
            }
            std::string lit_str = parts[2];
            if (lit_str.find("#int") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#int") + 5);
            }
            if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            insn[2] = static_cast<uint8_t>(vBB);
            insn[3] = static_cast<uint8_t>(static_cast<int8_t>(lit));
            break;
        }
        
        case OpcodeFormat::k22t: {
            // vA, vB, +CCCC (if-*)
            if (parts.size() < 3) { error = "Expected 2 registers and offset"; return false; }
            int vA, vB;
            int64_t offset_val;
            if (!parse_register(parts[0], vA) || !parse_register(parts[1], vB)) {
                error = "Invalid registers"; return false;
            }
            if (!parse_int(parts[2], offset_val)) { error = "Invalid offset"; return false; }
            insn[1] = static_cast<uint8_t>((vB << 4) | (vA & 0xF));
            write_le<int16_t>(&insn[2], static_cast<int16_t>(offset_val));
            break;
        }
        
        case OpcodeFormat::k22s: {
            // vA, vB, #+CCCC
            if (parts.size() < 3) { error = "Expected 2 registers and literal"; return false; }
            int vA, vB;
            int64_t lit;
            if (!parse_register(parts[0], vA) || !parse_register(parts[1], vB)) {
                error = "Invalid registers"; return false;
            }
            std::string lit_str = parts[2];
            if (lit_str.find("#int") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#int") + 5);
            }
            if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
            insn[1] = static_cast<uint8_t>((vB << 4) | (vA & 0xF));
            write_le<int16_t>(&insn[2], static_cast<int16_t>(lit));
            break;
        }
        
        case OpcodeFormat::k22x: {
            // vAA, vBBBB
            if (parts.size() < 2) { error = "Expected 2 registers"; return false; }
            int vAA, vBBBB;
            if (!parse_register(parts[0], vAA) || !parse_register(parts[1], vBBBB)) {
                error = "Invalid registers"; return false;
            }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<uint16_t>(&insn[2], static_cast<uint16_t>(vBBBB));
            break;
        }
        
        case OpcodeFormat::k32x: {
            // vAAAA, vBBBB
            if (parts.size() < 2) { error = "Expected 2 registers"; return false; }
            int vAAAA, vBBBB;
            if (!parse_register(parts[0], vAAAA) || !parse_register(parts[1], vBBBB)) {
                error = "Invalid registers"; return false;
            }
            write_le<uint16_t>(&insn[2], static_cast<uint16_t>(vAAAA));
            write_le<uint16_t>(&insn[4], static_cast<uint16_t>(vBBBB));
            break;
        }
        
        case OpcodeFormat::k30t: {
            // +AAAAAAAA (goto/32)
            int64_t offset_val;
            std::string offset_str = parts.size() > 0 ? parts[0] : "0";
            if (!parse_int(offset_str, offset_val)) { error = "Invalid offset"; return false; }
            write_le<int32_t>(&insn[2], static_cast<int32_t>(offset_val));
            break;
        }
        
        case OpcodeFormat::k31t: {
            // vAA, +BBBBBBBB (fill-array-data, packed-switch, sparse-switch)
            if (parts.size() < 2) { error = "Expected register and offset"; return false; }
            int vAA;
            int64_t offset_val;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            if (!parse_int(parts[1], offset_val)) { error = "Invalid offset"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<int32_t>(&insn[2], static_cast<int32_t>(offset_val));
            break;
        }
        
        case OpcodeFormat::k31i: {
            // vAA, #+BBBBBBBB (const)
            if (parts.size() < 2) { error = "Expected register and literal"; return false; }
            int vAA;
            int64_t lit;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            std::string lit_str = parts[1];
            if (lit_str.find("#int") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#int") + 5);
            }
            if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<int32_t>(&insn[2], static_cast<int32_t>(lit));
            break;
        }
        
        case OpcodeFormat::k31c: {
            // vAA, string@BBBBBBBB (const-string/jumbo)
            if (parts.size() < 2) { error = "Expected register and string"; return false; }
            int vAA;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            
            std::string ref = parts[1];
            int idx = -1;
            if (ref[0] == '"') {
                std::string str = ref.substr(1, ref.length() - 2);
                idx = find_string(str);
                if (idx < 0) { error = "String not found: " + str; return false; }
            } else if (ref.find("string@") == 0) {
                idx = std::stoi(ref.substr(7));
            } else {
                idx = find_string(ref);
                if (idx < 0) { error = "String not found: " + ref; return false; }
            }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<uint32_t>(&insn[2], static_cast<uint32_t>(idx));
            break;
        }
        
        case OpcodeFormat::k3rc: {
            // {vCCCC .. vNNNN}, method@BBBB (invoke-*/range)
            if (parts.size() < 2) { error = "Expected register range and method"; return false; }
            
            std::string range_str = parts[0];
            if (range_str[0] == '{') range_str = range_str.substr(1);
            if (range_str.back() == '}') range_str = range_str.substr(0, range_str.length() - 1);
            
            // Parse "vCCCC .. vNNNN" or just "vCCCC"
            int vStart = 0, vEnd = 0;
            size_t dotdot = range_str.find("..");
            if (dotdot != std::string::npos) {
                std::string start_str = range_str.substr(0, dotdot);
                std::string end_str = range_str.substr(dotdot + 2);
                size_t s = start_str.find_first_not_of(" \t");
                size_t e = start_str.find_last_not_of(" \t");
                if (s != std::string::npos) start_str = start_str.substr(s, e - s + 1);
                s = end_str.find_first_not_of(" \t");
                e = end_str.find_last_not_of(" \t");
                if (s != std::string::npos) end_str = end_str.substr(s, e - s + 1);
                
                if (!parse_register(start_str, vStart) || !parse_register(end_str, vEnd)) {
                    error = "Invalid register range"; return false;
                }
            } else {
                size_t s = range_str.find_first_not_of(" \t");
                size_t e = range_str.find_last_not_of(" \t");
                if (s != std::string::npos) range_str = range_str.substr(s, e - s + 1);
                if (!parse_register(range_str, vStart)) {
                    error = "Invalid register"; return false;
                }
                vEnd = vStart;
            }
            
            int count = vEnd - vStart + 1;
            
            std::string method_ref = parts[1];
            int method_idx = find_method(method_ref);
            if (method_idx < 0) { error = "Method not found: " + method_ref; return false; }
            
            insn[1] = static_cast<uint8_t>(count);
            write_le<uint16_t>(&insn[2], static_cast<uint16_t>(method_idx));
            write_le<uint16_t>(&insn[4], static_cast<uint16_t>(vStart));
            break;
        }
        
        case OpcodeFormat::k51l: {
            // vAA, #+BBBBBBBBBBBBBBBB (const-wide)
            if (parts.size() < 2) { error = "Expected register and literal"; return false; }
            int vAA;
            int64_t lit;
            if (!parse_register(parts[0], vAA)) { error = "Invalid register"; return false; }
            std::string lit_str = parts[1];
            if (lit_str.find("#long") != std::string::npos) {
                lit_str = lit_str.substr(lit_str.find("#long") + 6);
            }
            if (!parse_int(lit_str, lit)) { error = "Invalid literal"; return false; }
            insn[1] = static_cast<uint8_t>(vAA);
            write_le<int64_t>(&insn[2], lit);
            break;
        }
        
        case OpcodeFormat::k35c: {
            // {vC, vD, vE, vF, vG}, method@BBBB or type@BBBB
            // Format: A|G|op BBBB F|E|D|C
            if (parts.size() < 2) { error = "Expected registers and method/type"; return false; }
            
            std::string regs_str = parts[0];
            if (regs_str[0] == '{') regs_str = regs_str.substr(1);
            if (regs_str.back() == '}') regs_str = regs_str.substr(0, regs_str.length() - 1);
            
            std::vector<int> regs;
            std::stringstream ss(regs_str);
            std::string reg;
            while (std::getline(ss, reg, ',')) {
                size_t s = reg.find_first_not_of(" \t");
                size_t e = reg.find_last_not_of(" \t");
                if (s != std::string::npos) {
                    int r;
                    if (parse_register(reg.substr(s, e - s + 1), r)) {
                        regs.push_back(r);
                    }
                }
            }
            
            std::string ref = parts[1];
            int idx = -1;
            if (op >= 0x6e && op <= 0x72) { // invoke-*
                idx = find_method(ref);
                if (idx < 0) { error = "Method not found: " + ref; return false; }
            } else { // filled-new-array
                idx = find_type(ref);
                if (idx < 0) { error = "Type not found: " + ref; return false; }
            }
            
            // Encode: A|G in code[1], where A = count, G = 5th register (if any)
            uint8_t A = static_cast<uint8_t>(regs.size());
            uint8_t G = (regs.size() > 4) ? static_cast<uint8_t>(regs[4] & 0xF) : 0;
            insn[1] = static_cast<uint8_t>((A << 4) | G);
            
            write_le<uint16_t>(&insn[2], static_cast<uint16_t>(idx));
            
            // Encode D|C in code[4], F|E in code[5]
            uint8_t C = (regs.size() > 0) ? static_cast<uint8_t>(regs[0] & 0xF) : 0;
            uint8_t D = (regs.size() > 1) ? static_cast<uint8_t>(regs[1] & 0xF) : 0;
            uint8_t E = (regs.size() > 2) ? static_cast<uint8_t>(regs[2] & 0xF) : 0;
            uint8_t F = (regs.size() > 3) ? static_cast<uint8_t>(regs[3] & 0xF) : 0;
            insn[4] = static_cast<uint8_t>(C | (D << 4));
            insn[5] = static_cast<uint8_t>(E | (F << 4));
            break;
        }
        
        default:
            error = "Unsupported instruction format for assembly: " + opcode_name;
            return false;
    }
    
    bytecode.insert(bytecode.end(), insn.begin(), insn.end());
    return true;
}

bool SmaliAssembler::assemble(const std::string& smali_code, std::vector<uint8_t>& bytecode, std::string& error) {
    bytecode.clear();
    
    std::istringstream iss(smali_code);
    std::string line;
    int line_num = 0;
    
    while (std::getline(iss, line)) {
        line_num++;
        if (!assemble_insn(line, bytecode, error)) {
            error = "Line " + std::to_string(line_num) + ": " + error;
            return false;
        }
    }
    
    return true;
}

} // namespace dex
