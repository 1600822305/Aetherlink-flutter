#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include <sstream>

namespace dex {

class SmaliToJava {
public:
    SmaliToJava() = default;
    
    // Convert Smali code to Java-like pseudocode
    std::string convert(const std::string& smali_code);
    
    // Convert a single method
    std::string convert_method(const std::string& method_smali);

private:
    struct Register {
        std::string type;
        std::string value;
        bool is_param = false;
    };
    
    std::unordered_map<std::string, Register> registers_;
    std::unordered_map<std::string, int> labels_;  // label -> line number
    int indent_ = 0;
    
    std::string convert_instruction(const std::string& line);
    std::string convert_invoke(const std::string& line);
    std::string convert_field_access(const std::string& line);
    std::string convert_const(const std::string& line);
    std::string convert_move(const std::string& line);
    std::string convert_return(const std::string& line);
    std::string convert_if(const std::string& line);
    std::string convert_new(const std::string& line);
    std::string convert_array(const std::string& line);
    std::string convert_cast(const std::string& line);
    std::string convert_arithmetic(const std::string& line);
    
    std::string type_to_java(const std::string& smali_type);
    std::string method_to_java(const std::string& method_ref);
    std::string get_indent();
    std::vector<std::string> split(const std::string& s, char delim);
    std::string trim(const std::string& s);
};

} // namespace dex
