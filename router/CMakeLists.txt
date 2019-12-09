cmake_minimum_required(VERSION 2.8)
project(ROUTER LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 11)

set(BACKEND LINUX CACHE STRING "Router platform")
set(BACKEND_VALUES "Linux" "Xilinx" "macOS" "stdio")
set_property(CACHE BACKEND PROPERTY STRINGS ${BACKEND_VALUES})
list(FIND BACKEND_VALUES ${BACKEND} BACKEND_INDEX)

if(${BACKEND_INDEX} EQUAL -1)
    message(WARNING "Backend ${BACKEND} not supported, valid items are: ${BACKEND_VALUES}. macOS will be used.")
    set(BACKEND "macOS")
endif()

string(TOUPPER "${BACKEND}" BACKEND)
add_definitions("-DROUTER_BACKEND_${BACKEND}")

add_subdirectory(hal)
add_subdirectory(components)

add_executable(router main.cpp)
target_link_libraries(router router_hal checksum forwarding lookup protocol)
