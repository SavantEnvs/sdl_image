#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <stdint.h>
#include "alloc_cap.h"

/* TGA has no magic number, so IMG_Load_IO never reaches it; it is only loaded when the caller names the type. */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    SDL_IOStream *io = SDL_IOFromConstMem(data, size);
    if (!io) {
        return 0;
    }
    SDL_Surface *surface = IMG_LoadTyped_IO(io, true, "TGA");
    SDL_DestroySurface(surface);
    return 0;
}
