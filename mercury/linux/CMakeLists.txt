cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "mercuryjs")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "mercuryjs_plugin")

add_library(${PLUGIN_NAME} SHARED
    "mercuryjs_plugin.cc"
    )

add_library(mercuryjs SHARED IMPORTED)
set_target_properties(mercuryjs PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/libmercuryjs.so")
add_library(quickjs SHARED IMPORTED)
set_target_properties(quickjs PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/libquickjs.so")

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

execute_process(
    COMMAND bash "-c" "readlink -f ${CMAKE_CURRENT_SOURCE_DIR}/libmercuryjs.so"
    OUTPUT_VARIABLE MERCURY_LIB_PATH
)
string(REGEX REPLACE "\n$" "" MERCURY_LIB_PATH "${MERCURY_LIB_PATH}")

execute_process(
    COMMAND bash "-c" "readlink -f ${CMAKE_CURRENT_SOURCE_DIR}/libquickjs.so"
    OUTPUT_VARIABLE QUICKJS_LIB_PATH
)
string(REGEX REPLACE "\n$" "" QUICKJS_LIB_PATH "${QUICKJS_LIB_PATH}")

# List of absolute paths to libraries that should be bundled with the plugin
set(mercuryjs_bundled_libraries
    ${QUICKJS_LIB_PATH}
    ${MERCURY_LIB_PATH}
    PARENT_SCOPE
  )
