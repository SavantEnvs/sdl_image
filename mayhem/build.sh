#!/usr/bin/env bash
#
# mayhem/build.sh — build SDL3_image with sanitizers + SanCov and link the fuzz harnesses, then build the
# project's own test suite with normal flags. Runs in the commit image as `mayhem` in /mayhem; re-runnable
# and offline (SDL3 comes from /opt/toolchains/deps, the codecs from apt -dev packages).
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${SDL3_PREFIX:=/opt/toolchains/deps/sdl3-3.4.20}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

COMMON_CMAKE=(
  -G Ninja
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_PREFIX_PATH="$SDL3_PREFIX"
  -DBUILD_SHARED_LIBS=OFF
  -DSDLIMAGE_VENDORED=OFF
  -DSDLIMAGE_DEPS_SHARED=OFF
  -DSDLIMAGE_SAMPLES=OFF
  -DSDLIMAGE_INSTALL=OFF
  -DSDLIMAGE_STRICT=ON
  -DSDLIMAGE_AVIF=ON
  -DSDLIMAGE_JXL=OFF
)

# 1) Sanitized + SanCov-instrumented library. The library, not just the harness, carries the coverage.
rm -rf build/fuzz
cmake -S . -B build/fuzz "${COMMON_CMAKE[@]}" -DSDLIMAGE_TESTS=OFF \
  -DCMAKE_C_FLAGS="$SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS" \
  -DCMAKE_C_FLAGS_RELEASE="-O2"
cmake --build build/fuzz -j"$MAYHEM_JOBS"
LIB=build/fuzz/libSDL3_image.a

# 2) Harnesses: libFuzzer binary + run-once standalone reproducer, both with leak detection switched off.
CODEC_LIBS=$(pkg-config --libs --static libpng libtiff-4 libwebp libwebpdemux libwebpmux libsharpyuv libavif libjpeg 2>/dev/null || echo "-lpng -ltiff -lwebpdemux -lwebpmux -lwebp -lsharpyuv -lavif -ljpeg")
SDL_LIBS=$(PKG_CONFIG_PATH="$SDL3_PREFIX/lib/pkgconfig" pkg-config --static --libs sdl3)
SDL_CFLAGS=$(PKG_CONFIG_PATH="$SDL3_PREFIX/lib/pkgconfig" pkg-config --cflags sdl3)
INC="-Iinclude $SDL_CFLAGS"
LINK_LIBS="$LIB $SDL_LIBS $CODEC_LIBS -lm"

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o build/lsan_off.o
$CC $DEBUG_FLAGS -c mayhem/sancov_stubs.c -o build/sancov_stubs.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -x c -c "$STANDALONE_FUZZ_MAIN" -o build/standalone_main.o

for h in fuzz_img_load fuzz_img_load_tga fuzz_img_anim fuzz_img_anim_decoder; do
  $CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE $INC "mayhem/$h.c" build/lsan_off.o $LINK_LIBS -o "/mayhem/$h"
  $CC $SANITIZER_FLAGS $DEBUG_FLAGS $INC "mayhem/$h.c" build/standalone_main.o build/sancov_stubs.o build/lsan_off.o $LINK_LIBS -o "/mayhem/$h-standalone"
done

# 3) The project's own tests (testimage, testanimation), normal flags, a separate build tree.
rm -rf build/tests
cmake -S . -B build/tests "${COMMON_CMAKE[@]}" -DSDLIMAGE_TESTS=ON \
  -DCMAKE_C_FLAGS="$COVERAGE_FLAGS"
cmake --build build/tests -j"$MAYHEM_JOBS"
