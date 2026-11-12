cmake_minimum_required(VERSION 3.31)

# =============================================================================
# DSP micro-benchmarks (google/benchmark).
#
# The sound engine (source/dsp) is header-only and depends only on the C++
# standard library, so the benchmark executable needs no YUP modules - just
# google/benchmark. Enable with -DBUILD_BENCHMARKS=ON (off by default) and run
# the resulting `${PROJECT_NAME}_benchmarks` target, or use `just bench`.
# =============================================================================

set (BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set (BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set (BENCHMARK_ENABLE_GTEST_TESTS OFF CACHE BOOL "" FORCE)
set (BENCHMARK_ENABLE_WERROR OFF CACHE BOOL "" FORCE)

_yup_fetchcontent_declare (benchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG v1.10.0)

FetchContent_MakeAvailable (benchmark)

set_target_properties (benchmark PROPERTIES FOLDER "Benchmarks")
set_target_properties (benchmark_main PROPERTIES FOLDER "Benchmarks")

set (target_name ${PROJECT_NAME}_benchmarks)

file (GLOB benchmark_sources "${CMAKE_CURRENT_LIST_DIR}/bench_*.cpp")
list (APPEND benchmark_sources "${CMAKE_CURRENT_LIST_DIR}/main.cpp")

add_executable (${target_name} ${benchmark_sources})

target_include_directories (${target_name} PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../source")
target_link_libraries (${target_name} PRIVATE benchmark::benchmark)

source_group (TREE ${CMAKE_CURRENT_LIST_DIR}/ FILES ${benchmark_sources})

set_target_properties (${target_name} PROPERTIES
    FOLDER "Benchmarks"
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    XCODE_GENERATE_SCHEME ON
    XCODE_SCHEME_ARGUMENTS "--benchmark_counters_tabular=true"
    VS_DEBUGGER_COMMAND_ARGUMENTS "--benchmark_counters_tabular=true")
