#!/usr/bin/env bash
#
# mayhem/test.sh — RUN SDL3_image's own test programs (testimage, testanimation; built by mayhem/build.sh with
# normal flags). Each asserts decoded sizes and pixels against reference images across every enabled format,
# and prints SDL_test's "Assert Summary: Total=T Passed=P Failed=F", which is what is counted here.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}


T=build/tests/test
export SDL_TEST_SRCDIR="$SRC/test" SDL_TEST_BUILDDIR="$SRC/$T" SDL_VIDEO_DRIVER=dummy
export SDL_IMAGE_SAVE_ANI=1 SDL_IMAGE_SAVE_AVIF=1 SDL_IMAGE_SAVE_CUR=1 SDL_IMAGE_SAVE_ICO=1 SDL_IMAGE_SAVE_JPG=1 SDL_IMAGE_SAVE_PNG=1
export SDL_IMAGE_ANIM_ANI=1 SDL_IMAGE_ANIM_AVIFS=1 SDL_IMAGE_ANIM_GIF=1 SDL_IMAGE_ANIM_WEBP=1 SDL_IMAGE_ANIM_APNG=0
export SDL_IMAGE_TEST_REQUIRE_LOAD_AVIF=1 SDL_IMAGE_TEST_REQUIRE_LOAD_PNG=1 SDL_IMAGE_TEST_REQUIRE_LOAD_JPG=1
export SDL_IMAGE_TEST_REQUIRE_LOAD_TIF=1 SDL_IMAGE_TEST_REQUIRE_LOAD_WEBP=1 SDL_IMAGE_TEST_REQUIRE_LOAD_GIF=1

passed=0 ; failed=0
for run in "testimage" "testanimation" "testanimation --no-dummy-metadata"; do
  prog=${run%% *}
  if [ ! -x "$T/$prog" ]; then echo "missing $T/$prog — mayhem/build.sh did not build the tests" >&2; exit 2; fi
  out=$(cd "$T" && ./$run 2>&1); rc=$?
  line=$(printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'Assert Summary: Total=[0-9]+ Passed=[0-9]+ Failed=[0-9]+' | tail -1)
  if [ -z "$line" ]; then
    echo "FAIL $run: no 'Assert Summary' line (rc=$rc)" >&2 ; failed=$((failed + 1)) ; continue
  fi
  p=$(sed -E 's/.*Passed=([0-9]+).*/\1/' <<<"$line") ; f=$(sed -E 's/.*Failed=([0-9]+).*/\1/' <<<"$line")
  [ "$rc" -eq 0 ] || f=$((f + 1))
  echo "$run: $line (rc=$rc)"
  passed=$((passed + p)) ; failed=$((failed + f))
done

emit_ctrf "sdl-test-asserts" "$passed" "$failed" 0
