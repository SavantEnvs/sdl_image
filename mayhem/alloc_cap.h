#ifndef MAYHEM_ALLOC_CAP_H
#define MAYHEM_ALLOC_CAP_H
#include <SDL3/SDL.h>
#include <stdint.h>
#include <stdlib.h>

/* Allocation cap, installed once from LLVMFuzzerInitialize (no per-input state). A memory-limited application
   gets NULL for a request this large rather than aborting, and SDL_image's loaders already handle NULL, so
   oversized sizes from untrusted headers are reported as ordinary load failures instead of OOM defects. */
#define MAYHEM_ALLOC_CAP ((size_t)256 << 20)

static void *mayhem_malloc(size_t n) { return n > MAYHEM_ALLOC_CAP ? NULL : malloc(n); }
static void *mayhem_calloc(size_t n, size_t m)
{
    if (m != 0 && n > MAYHEM_ALLOC_CAP / m) {
        return NULL;
    }
    return calloc(n, m);
}
static void *mayhem_realloc(void *p, size_t n) { return n > MAYHEM_ALLOC_CAP ? NULL : realloc(p, n); }

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
    (void)argc;
    (void)argv;
    SDL_SetMemoryFunctions(mayhem_malloc, mayhem_calloc, mayhem_realloc, free);
    return 0;
}
#endif
