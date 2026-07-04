cmake_minimum_required(VERSION 3.22.1)
project(aether_pty C)

add_library(aether_pty SHARED aether_pty.c)
target_link_libraries(aether_pty log)
