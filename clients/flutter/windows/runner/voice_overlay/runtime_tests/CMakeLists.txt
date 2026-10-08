cmake_minimum_required(VERSION 3.14)
project(voice_overlay_native_checks LANGUAGES CXX)
add_executable(voice_overlay_native_checks
  "main.cpp" "window_checks.cpp" "shortcut_checks.cpp" "decoder_checks.cpp"
  "../window_lifecycle/lifecycle.cpp" "../presentation/paint.cpp"
  "../configuration/apply.cpp" "../placement/position.cpp" "../window_events/handler.cpp"
  "../snapshot_decode/decoder.cpp" "../configuration_decode/decoder.cpp")
target_include_directories(voice_overlay_native_checks PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../flutter/ephemeral/cpp_client_wrapper/include")
target_compile_features(voice_overlay_native_checks PRIVATE cxx_std_17)
target_compile_definitions(voice_overlay_native_checks PRIVATE NOMINMAX UNICODE _UNICODE)
target_compile_options(voice_overlay_native_checks PRIVATE /W4 /WX /utf-8)
target_link_libraries(voice_overlay_native_checks PRIVATE user32 gdi32)
