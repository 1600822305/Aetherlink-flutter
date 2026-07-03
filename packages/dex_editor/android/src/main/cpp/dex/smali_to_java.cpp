#include "dex/smali_to_java.h"
#include <regex>
#include <algorithm>

namespace dex {

std::vector<std::string> SmaliToJava::split(const std::string& s, char delim) {
    std::vector<std::string> result;
    std::stringstream ss(s);
    std::string item;
    while (std::getline(ss, item, delim)) {
        if (!item.empty()) result.push_back(item);
    }
    return result;
}

std::string SmaliToJava::trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    size_t end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

std::string SmaliToJava::get_indent() {
    return std::string(indent_ * 4, ' ');
}

std::string SmaliToJava::type_to_java(const std::string& smali_type) {
    if (smali_type.empty()) return "void";
    
    std::string t = smali_type;
    int array_dim = 0;
    while (!t.empty() && t[0] == '[') {
        array_dim++;
        t = t.substr(1);
    }
    
    std::string base;
    if (t == "V") base = "void";
    else if (t == "Z") base = "boolean";
    else if (t == "B") base = "byte";
    else if (t == "S") base = "short";
    else if (t == "C") base = "char";
    else if (t == "I") base = "int";
    else if (t == "J") base = "long";
    else if (t == "F") base = "float";
    else if (t == "D") base = "double";
    else if (t[0] == 'L' && t.back() == ';') {
        base = t.substr(1, t.length() - 2);
        std::replace(base.begin(), base.end(), '/', '.');
    } else {
        base = t;
    }
    
    for (int i = 0; i < array_dim; i++) base += "[]";
    return base;
}

std::string SmaliToJava::method_to_java(const std::string& method_ref) {
    // Lcom/example/Class;->methodName(params)ReturnType
    size_t arrow = method_ref.find("->");
    if (arrow == std::string::npos) return method_ref;
    
    std::string class_part = method_ref.substr(0, arrow);
    std::string method_part = method_ref.substr(arrow + 2);
    
    size_t paren = method_part.find('(');
    std::string method_name = (paren != std::string::npos) ? method_part.substr(0, paren) : method_part;
    
    std::string class_name = type_to_java(class_part);
    size_t last_dot = class_name.rfind('.');
    if (last_dot != std::string::npos) {
        class_name = class_name.substr(last_dot + 1);
    }
    
    return class_name + "." + method_name;
}

std::string SmaliToJava::convert_const(const std::string& line) {
    // const-string v0, "hello"
    // const/4 v0, 0x1
    // const/16 v0, 0x100
    std::regex const_string_re(R"(const-string\s+(\w+),\s*\"(.*)\")");
    std::regex const_num_re(R"(const(?:/\d+|/high\d+)?\s+(\w+),\s*(-?0x[0-9a-fA-F]+|-?\d+))");
    std::regex const_class_re(R"(const-class\s+(\w+),\s*(\S+))");
    std::smatch match;
    
    if (std::regex_search(line, match, const_string_re)) {
        std::string reg = match[1].str();
        std::string value = match[2].str();
        registers_[reg] = {"String", "\"" + value + "\""};
        return get_indent() + "String " + reg + " = \"" + value + "\";";
    }
    
    if (std::regex_search(line, match, const_class_re)) {
        std::string reg = match[1].str();
        std::string cls = type_to_java(match[2].str());
        registers_[reg] = {"Class", cls + ".class"};
        return get_indent() + "Class " + reg + " = " + cls + ".class;";
    }
    
    if (std::regex_search(line, match, const_num_re)) {
        std::string reg = match[1].str();
        std::string value = match[2].str();
        registers_[reg] = {"int", value};
        return get_indent() + "int " + reg + " = " + value + ";";
    }
    
    return "";
}

std::string SmaliToJava::convert_move(const std::string& line) {
    // move v0, v1
    // move-result v0
    // move-object v0, v1
    std::regex move_re(R"(move(?:-object|-wide|-result(?:-object|-wide)?)?\s+(\w+)(?:,\s*(\w+))?)");
    std::smatch match;
    
    if (std::regex_search(line, match, move_re)) {
        std::string dst = match[1].str();
        if (match[2].matched) {
            std::string src = match[2].str();
            std::string type = registers_.count(src) ? registers_[src].type : "Object";
            registers_[dst] = {type, src};
            return get_indent() + dst + " = " + src + ";";
        } else {
            // move-result
            registers_[dst] = {"Object", "result"};
            return get_indent() + "// " + dst + " = <result>";
        }
    }
    return "";
}

std::string SmaliToJava::convert_invoke(const std::string& line) {
    // invoke-virtual {v0, v1}, Lcom/example/Class;->method(I)V
    std::regex invoke_re(R"(invoke-(\w+)(?:/range)?\s*\{([^}]*)\},\s*(\S+))");
    std::smatch match;
    
    if (std::regex_search(line, match, invoke_re)) {
        std::string invoke_type = match[1].str();
        std::string regs_str = match[2].str();
        std::string method_ref = match[3].str();
        
        // Parse registers
        std::vector<std::string> regs;
        std::regex reg_re(R"(\w+)");
        std::sregex_iterator it(regs_str.begin(), regs_str.end(), reg_re);
        std::sregex_iterator end;
        while (it != end) {
            regs.push_back(it->str());
            ++it;
        }
        
        // Parse method reference
        size_t arrow = method_ref.find("->");
        std::string class_name = (arrow != std::string::npos) ? 
            type_to_java(method_ref.substr(0, arrow)) : "";
        
        std::string method_part = (arrow != std::string::npos) ? 
            method_ref.substr(arrow + 2) : method_ref;
        size_t paren = method_part.find('(');
        std::string method_name = (paren != std::string::npos) ? 
            method_part.substr(0, paren) : method_part;
        
        // Build call
        std::string result;
        if (invoke_type == "static") {
            result = class_name + "." + method_name + "(";
            for (size_t i = 0; i < regs.size(); i++) {
                if (i > 0) result += ", ";
                result += regs[i];
            }
            result += ")";
        } else {
            // instance method: first reg is 'this'
            std::string obj = regs.empty() ? "this" : regs[0];
            if (method_name == "<init>") {
                // Constructor
                result = "new " + class_name + "(";
            } else {
                result = obj + "." + method_name + "(";
            }
            for (size_t i = 1; i < regs.size(); i++) {
                if (i > 1) result += ", ";
                result += regs[i];
            }
            result += ")";
        }
        
        return get_indent() + result + ";";
    }
    return "";
}

std::string SmaliToJava::convert_field_access(const std::string& line) {
    // iget v0, p0, Lcom/example/Class;->field:I
    // sget v0, Lcom/example/Class;->field:I
    // iput v0, p0, Lcom/example/Class;->field:I
    std::regex field_re(R"((i|s)(get|put)(?:-\w+)?\s+(\w+),\s*(?:(\w+),\s*)?(\S+))");
    std::smatch match;
    
    if (std::regex_search(line, match, field_re)) {
        std::string is_static = match[1].str();
        std::string is_get = match[2].str();
        std::string val_reg = match[3].str();
        std::string obj_reg = match[4].matched ? match[4].str() : "";
        std::string field_ref = match[5].str();
        
        // Parse field: Lcom/example/Class;->fieldName:Type
        size_t arrow = field_ref.find("->");
        size_t colon = field_ref.rfind(':');
        std::string class_name = (arrow != std::string::npos) ? 
            type_to_java(field_ref.substr(0, arrow)) : "";
        std::string field_name = (arrow != std::string::npos && colon != std::string::npos) ?
            field_ref.substr(arrow + 2, colon - arrow - 2) : field_ref;
        std::string field_type = (colon != std::string::npos) ?
            type_to_java(field_ref.substr(colon + 1)) : "Object";
        
        if (is_get == "get") {
            std::string src = (is_static == "s") ? 
                class_name + "." + field_name :
                obj_reg + "." + field_name;
            registers_[val_reg] = {field_type, src};
            return get_indent() + field_type + " " + val_reg + " = " + src + ";";
        } else {
            std::string dst = (is_static == "s") ? 
                class_name + "." + field_name :
                obj_reg + "." + field_name;
            return get_indent() + dst + " = " + val_reg + ";";
        }
    }
    return "";
}

std::string SmaliToJava::convert_return(const std::string& line) {
    std::regex return_re(R"(return(?:-void|-object|-wide)?\s*(\w+)?)");
    std::smatch match;
    
    if (std::regex_search(line, match, return_re)) {
        if (match[1].matched && !match[1].str().empty()) {
            return get_indent() + "return " + match[1].str() + ";";
        } else {
            return get_indent() + "return;";
        }
    }
    return "";
}

std::string SmaliToJava::convert_if(const std::string& line) {
    // if-eqz v0, :label
    // if-eq v0, v1, :label
    std::regex if_z_re(R"(if-(eq|ne|lt|ge|gt|le)z\s+(\w+),\s*:(\w+))");
    std::regex if_re(R"(if-(eq|ne|lt|ge|gt|le)\s+(\w+),\s*(\w+),\s*:(\w+))");
    std::smatch match;
    
    std::string op_map_z, op_map;
    
    if (std::regex_search(line, match, if_z_re)) {
        std::string op = match[1].str();
        std::string reg = match[2].str();
        std::string label = match[3].str();
        
        std::string java_op;
        if (op == "eq") java_op = "==";
        else if (op == "ne") java_op = "!=";
        else if (op == "lt") java_op = "<";
        else if (op == "ge") java_op = ">=";
        else if (op == "gt") java_op = ">";
        else if (op == "le") java_op = "<=";
        
        return get_indent() + "if (" + reg + " " + java_op + " 0) goto " + label + ";";
    }
    
    if (std::regex_search(line, match, if_re)) {
        std::string op = match[1].str();
        std::string reg1 = match[2].str();
        std::string reg2 = match[3].str();
        std::string label = match[4].str();
        
        std::string java_op;
        if (op == "eq") java_op = "==";
        else if (op == "ne") java_op = "!=";
        else if (op == "lt") java_op = "<";
        else if (op == "ge") java_op = ">=";
        else if (op == "gt") java_op = ">";
        else if (op == "le") java_op = "<=";
        
        return get_indent() + "if (" + reg1 + " " + java_op + " " + reg2 + ") goto " + label + ";";
    }
    
    return "";
}

std::string SmaliToJava::convert_new(const std::string& line) {
    // new-instance v0, Lcom/example/Class;
    // new-array v0, v1, [I
    std::regex new_instance_re(R"(new-instance\s+(\w+),\s*(\S+))");
    std::regex new_array_re(R"(new-array\s+(\w+),\s*(\w+),\s*(\S+))");
    std::smatch match;
    
    if (std::regex_search(line, match, new_instance_re)) {
        std::string reg = match[1].str();
        std::string type = type_to_java(match[2].str());
        registers_[reg] = {type, "new " + type + "()"};
        return get_indent() + type + " " + reg + " = new " + type + "();";
    }
    
    if (std::regex_search(line, match, new_array_re)) {
        std::string reg = match[1].str();
        std::string size_reg = match[2].str();
        std::string type = type_to_java(match[3].str());
        registers_[reg] = {type, "new " + type + "[" + size_reg + "]"};
        return get_indent() + type + " " + reg + " = new " + type.substr(0, type.length()-2) + "[" + size_reg + "];";
    }
    
    return "";
}

std::string SmaliToJava::convert_arithmetic(const std::string& line) {
    // add-int v0, v1, v2
    // mul-int/lit8 v0, v1, 0x10
    std::regex arith_re(R"((add|sub|mul|div|rem|and|or|xor|shl|shr|ushr)-(\w+)(?:/\w+)?\s+(\w+),\s*(\w+),\s*(\S+))");
    std::regex arith2_re(R"((add|sub|mul|div|rem|and|or|xor|shl|shr|ushr)-(\w+)(?:/2addr)?\s+(\w+),\s*(\w+))");
    std::regex neg_re(R"((neg|not)-(\w+)\s+(\w+),\s*(\w+))");
    std::smatch match;
    
    if (std::regex_search(line, match, arith_re)) {
        std::string op = match[1].str();
        std::string dst = match[3].str();
        std::string src1 = match[4].str();
        std::string src2 = match[5].str();
        
        std::string java_op;
        if (op == "add") java_op = "+";
        else if (op == "sub") java_op = "-";
        else if (op == "mul") java_op = "*";
        else if (op == "div") java_op = "/";
        else if (op == "rem") java_op = "%";
        else if (op == "and") java_op = "&";
        else if (op == "or") java_op = "|";
        else if (op == "xor") java_op = "^";
        else if (op == "shl") java_op = "<<";
        else if (op == "shr") java_op = ">>";
        else if (op == "ushr") java_op = ">>>";
        
        return get_indent() + dst + " = " + src1 + " " + java_op + " " + src2 + ";";
    }
    
    if (std::regex_search(line, match, arith2_re)) {
        std::string op = match[1].str();
        std::string dst = match[3].str();
        std::string src = match[4].str();
        
        std::string java_op;
        if (op == "add") java_op = "+=";
        else if (op == "sub") java_op = "-=";
        else if (op == "mul") java_op = "*=";
        else if (op == "div") java_op = "/=";
        else java_op = op + "=";
        
        return get_indent() + dst + " " + java_op + " " + src + ";";
    }
    
    if (std::regex_search(line, match, neg_re)) {
        std::string op = match[1].str();
        std::string dst = match[3].str();
        std::string src = match[4].str();
        
        if (op == "neg") return get_indent() + dst + " = -" + src + ";";
        if (op == "not") return get_indent() + dst + " = ~" + src + ";";
    }
    
    return "";
}

std::string SmaliToJava::convert_cast(const std::string& line) {
    // check-cast v0, Lcom/example/Class;
    // int-to-long v0, v1
    std::regex check_cast_re(R"(check-cast\s+(\w+),\s*(\S+))");
    std::regex conv_re(R"((\w+)-to-(\w+)\s+(\w+),\s*(\w+))");
    std::smatch match;
    
    if (std::regex_search(line, match, check_cast_re)) {
        std::string reg = match[1].str();
        std::string type = type_to_java(match[2].str());
        return get_indent() + reg + " = (" + type + ") " + reg + ";";
    }
    
    if (std::regex_search(line, match, conv_re)) {
        std::string to_type = match[2].str();
        std::string dst = match[3].str();
        std::string src = match[4].str();
        return get_indent() + dst + " = (" + to_type + ") " + src + ";";
    }
    
    return "";
}

std::string SmaliToJava::convert_array(const std::string& line) {
    // aget v0, v1, v2
    // aput v0, v1, v2
    std::regex aget_re(R"(aget(?:-\w+)?\s+(\w+),\s*(\w+),\s*(\w+))");
    std::regex aput_re(R"(aput(?:-\w+)?\s+(\w+),\s*(\w+),\s*(\w+))");
    std::regex array_len_re(R"(array-length\s+(\w+),\s*(\w+))");
    std::smatch match;
    
    if (std::regex_search(line, match, aget_re)) {
        return get_indent() + match[1].str() + " = " + match[2].str() + "[" + match[3].str() + "];";
    }
    
    if (std::regex_search(line, match, aput_re)) {
        return get_indent() + match[2].str() + "[" + match[3].str() + "] = " + match[1].str() + ";";
    }
    
    if (std::regex_search(line, match, array_len_re)) {
        return get_indent() + match[1].str() + " = " + match[2].str() + ".length;";
    }
    
    return "";
}

std::string SmaliToJava::convert_instruction(const std::string& line) {
    std::string trimmed = trim(line);
    if (trimmed.empty() || trimmed[0] == '#') return "";
    
    // Handle offset prefix like ".0000: sget-object ..."
    if (trimmed[0] == '.' && trimmed.size() > 5 && trimmed[5] == ':') {
        trimmed = trim(trimmed.substr(6));
    }
    
    // Skip directives except method/class headers
    if (trimmed[0] == '.') {
        if (trimmed.find(".method") == 0) {
            // Extract method signature
            size_t name_start = trimmed.rfind(' ');
            if (name_start != std::string::npos) {
                std::string sig = trimmed.substr(name_start + 1);
                size_t paren = sig.find('(');
                std::string name = (paren != std::string::npos) ? sig.substr(0, paren) : sig;
                return "\n" + get_indent() + "// Method: " + name;
            }
        }
        if (trimmed.find(".end method") == 0) {
            return get_indent() + "}\n";
        }
        if (trimmed.find(".registers") == 0 || trimmed.find(".locals") == 0) {
            return get_indent() + "{";
        }
        return "";
    }
    
    // Labels
    if (trimmed[0] == ':') {
        return get_indent() + trimmed.substr(1) + ":";
    }
    
    // Convert instructions
    std::string result;
    
    if (trimmed.find("const") == 0) result = convert_const(trimmed);
    else if (trimmed.find("move") == 0) result = convert_move(trimmed);
    else if (trimmed.find("invoke") == 0) result = convert_invoke(trimmed);
    else if (trimmed.find("iget") == 0 || trimmed.find("sget") == 0 ||
             trimmed.find("iput") == 0 || trimmed.find("sput") == 0) 
        result = convert_field_access(trimmed);
    else if (trimmed.find("return") == 0) result = convert_return(trimmed);
    else if (trimmed.find("if-") == 0) result = convert_if(trimmed);
    else if (trimmed.find("new-") == 0) result = convert_new(trimmed);
    else if (trimmed.find("aget") == 0 || trimmed.find("aput") == 0 || 
             trimmed.find("array-length") == 0) result = convert_array(trimmed);
    else if (trimmed.find("check-cast") == 0 || trimmed.find("-to-") != std::string::npos) 
        result = convert_cast(trimmed);
    else if (trimmed.find("add-") == 0 || trimmed.find("sub-") == 0 ||
             trimmed.find("mul-") == 0 || trimmed.find("div-") == 0 ||
             trimmed.find("rem-") == 0 || trimmed.find("and-") == 0 ||
             trimmed.find("or-") == 0 || trimmed.find("xor-") == 0 ||
             trimmed.find("shl-") == 0 || trimmed.find("shr-") == 0 ||
             trimmed.find("neg-") == 0 || trimmed.find("not-") == 0)
        result = convert_arithmetic(trimmed);
    else if (trimmed == "nop") return "";
    else if (trimmed.find("goto") == 0) {
        size_t colon = trimmed.find(':');
        if (colon != std::string::npos) {
            return get_indent() + "goto " + trimmed.substr(colon + 1) + ";";
        }
    }
    else if (trimmed.find("throw") == 0) {
        std::regex throw_re(R"(throw\s+(\w+))");
        std::smatch match;
        if (std::regex_search(trimmed, match, throw_re)) {
            return get_indent() + "throw " + match[1].str() + ";";
        }
    }
    
    if (result.empty() && !trimmed.empty()) {
        return get_indent() + "// " + trimmed;
    }
    
    return result;
}

std::string SmaliToJava::convert_method(const std::string& method_smali) {
    registers_.clear();
    indent_ = 1;
    
    std::stringstream ss(method_smali);
    std::string line;
    std::stringstream result;
    
    while (std::getline(ss, line)) {
        std::string converted = convert_instruction(line);
        if (!converted.empty()) {
            result << converted << "\n";
        }
    }
    
    return result.str();
}

std::string SmaliToJava::convert(const std::string& smali_code) {
    registers_.clear();
    indent_ = 0;
    
    std::stringstream ss(smali_code);
    std::string line;
    std::stringstream result;
    
    bool in_method = false;
    
    while (std::getline(ss, line)) {
        std::string trimmed = trim(line);
        
        if (trimmed.find(".class") == 0) {
            // Extract class name
            size_t last_space = trimmed.rfind(' ');
            if (last_space != std::string::npos) {
                std::string cls = type_to_java(trimmed.substr(last_space + 1));
                result << "// Decompiled from Smali\n";
                result << "class " << cls << " {\n";
                indent_ = 1;
            }
            continue;
        }
        
        if (trimmed.find(".super") == 0) {
            size_t last_space = trimmed.rfind(' ');
            if (last_space != std::string::npos) {
                std::string super_cls = type_to_java(trimmed.substr(last_space + 1));
                result << "    // extends " << super_cls << "\n\n";
            }
            continue;
        }
        
        if (trimmed.find(".method") == 0) {
            in_method = true;
        }
        
        if (in_method) {
            std::string converted = convert_instruction(line);
            if (!converted.empty()) {
                result << converted << "\n";
            }
        }
        
        if (trimmed.find(".end method") == 0) {
            in_method = false;
            result << "\n";
        }
    }
    
    result << "}\n";
    return result.str();
}

} // namespace dex
