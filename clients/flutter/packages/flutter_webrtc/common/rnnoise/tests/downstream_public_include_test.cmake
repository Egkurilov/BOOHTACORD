# Exercise the Windows plugin's exported include contract on any CMake host.
# This compiles a consumer linked only to the plugin interface, without giving
# that consumer the private RNNoise target's include directories.
cmake_minimum_required(VERSION 3.15)
if(NOT DEFINED TEST_BINARY_DIR)
  message(FATAL_ERROR "TEST_BINARY_DIR must point to a generated test directory")
endif()
get_filename_component(_plugin_windows "${CMAKE_CURRENT_LIST_DIR}/../../../windows" ABSOLUTE)
file(READ "${_plugin_windows}/CMakeLists.txt" _plugin_cmake)
string(REGEX MATCH "target_include_directories\\(\\$\\{PLUGIN_NAME\\} INTERFACE[^)]*\\)"
  _public_includes "${_plugin_cmake}")
if(_public_includes STREQUAL "")
  message(FATAL_ERROR "Windows plugin's public include declaration was not found")
endif()
# Keep the exact include expression, evaluated relative to the real plugin.
string(REPLACE "\${CMAKE_CURRENT_SOURCE_DIR}" "${_plugin_windows}"
  _public_includes "${_public_includes}")
file(MAKE_DIRECTORY "${TEST_BINARY_DIR}/source")
file(WRITE "${TEST_BINARY_DIR}/source/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.15)\nproject(downstream_public_include LANGUAGES CXX)\nset(PLUGIN_NAME flutter_webrtc_plugin)\nadd_library(flutter_webrtc_plugin INTERFACE)\n${_public_includes}\nadd_library(livekit_public_header_consumer OBJECT consumer.cc)\ntarget_compile_features(livekit_public_header_consumer PRIVATE cxx_std_17)\ntarget_link_libraries(livekit_public_header_consumer PRIVATE flutter_webrtc_plugin)\n")
file(WRITE "${TEST_BINARY_DIR}/source/consumer.cc"
  "#if !__has_include(\"webrtc_capture_adapter.h\")\n#error Public Windows adapter header is unavailable to downstream plugins\n#endif\n#include \"rnnoise_capture_processor.h\"\nstatic_assert(sizeof(boohta::RnnoiseCaptureProcessor) > 0);\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${TEST_BINARY_DIR}/source"
  -B "${TEST_BINARY_DIR}/build" RESULT_VARIABLE _configure_result)
if(NOT _configure_result EQUAL 0)
  message(FATAL_ERROR "Downstream public include configuration failed")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${TEST_BINARY_DIR}/build"
  RESULT_VARIABLE _build_result)
if(NOT _build_result EQUAL 0)
  message(FATAL_ERROR "Downstream public include compilation failed")
endif()
