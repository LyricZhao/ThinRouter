cmake_minimum_required(VERSION 2.8)

add_library(checksum checksum.c)
add_library(lookup lookup.cpp)
add_library(protocol protocol.c)
add_library(forwarding forwarding.c)