cmake_minimum_required(VERSION 3.15)
project(boohta_rnnoise LANGUAGES C CXX)
add_library(boohta_rnnoise STATIC
  upstream/src/denoise.c upstream/src/kiss_fft.c upstream/src/pitch.c
  upstream/src/celt_lpc.c upstream/src/rnn.c upstream/src/rnn_data.c
  rnnoise_capture_processor.cc)
target_include_directories(boohta_rnnoise PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/upstream/include PRIVATE upstream/src)
target_compile_features(boohta_rnnoise PUBLIC cxx_std_17)
set_target_properties(boohta_rnnoise PROPERTIES POSITION_INDEPENDENT_CODE ON)
if(MSVC)
  target_compile_definitions(boohta_rnnoise PRIVATE _USE_MATH_DEFINES)
  # Flutter Windows uses VS 2022; stock RNNoise uses C99 inline declarations.
  target_compile_options(boohta_rnnoise PRIVATE $<$<COMPILE_LANGUAGE:C>:/std:c11>)
else()
  target_link_libraries(boohta_rnnoise PUBLIC m)
endif()
option(BOOHTA_RNNOISE_TESTS "Build native capture processor tests" OFF)
if(BOOHTA_RNNOISE_TESTS)
  enable_testing()
  add_executable(rnnoise_capture_processor_test tests/rnnoise_capture_processor_test.cc)
  target_link_libraries(rnnoise_capture_processor_test PRIVATE boohta_rnnoise)
  if(MSVC)
    target_compile_options(rnnoise_capture_processor_test PRIVATE /UNDEBUG)
  else()
    target_compile_options(rnnoise_capture_processor_test PRIVATE -UNDEBUG)
  endif()
  add_test(NAME rnnoise_capture_processor_test COMMAND rnnoise_capture_processor_test)
endif()
