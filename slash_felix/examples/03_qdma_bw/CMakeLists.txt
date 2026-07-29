# ##################################################################################################
#  The MIT License (MIT)
#  Copyright (c) 2026 Advanced Micro Devices, Inc. All rights reserved.
# ##################################################################################################

cmake_minimum_required(VERSION 3.20)
project(03_qdma_bw LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(SLASH_USE_REPO "Build against the local repo tree instead of installed packages" OFF)

if(SLASH_USE_REPO)
  get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." REALPATH)
  list(APPEND CMAKE_MODULE_PATH "${REPO_ROOT}/cmake")
  include(SlashTools)
  add_subdirectory(${REPO_ROOT}/vrt ${CMAKE_CURRENT_BINARY_DIR}/vrt)
  set(_VRT_INCLUDES "")
  set(_VRT_LIBS vrt)
else()
  find_package(vrt REQUIRED CONFIG)
  find_package(SlashTools REQUIRED)
  set(_VRT_INCLUDES "")
  set(_VRT_LIBS vrt::vrt)
endif()

# --- HLS kernels ---
set(DEVICE "xcvp1552-vsva3340-2MHP-e-S" CACHE STRING "Target device")

build_hls_dir(
  TARGET      hls
  ROOT        "${CMAKE_CURRENT_SOURCE_DIR}/hls"
  DEVICE      "${DEVICE}"
  KERNELS     mem_bw
  OUT_KERNELS _KERNELS
)

# --- VBIN target ---
set(CFG_FILE "${CMAKE_CURRENT_SOURCE_DIR}/config.cfg")
add_vbin(TARGET "qdma_bw_hw" PLATFORM "hw" CFG "${CFG_FILE}" KERNELS ${_KERNELS})

# --- Executable ---
add_executable(${PROJECT_NAME} 03_qdma_bw.cpp)
target_include_directories(${PROJECT_NAME} PRIVATE ${_VRT_INCLUDES})
target_link_libraries(${PROJECT_NAME} PRIVATE ${_VRT_LIBS})
