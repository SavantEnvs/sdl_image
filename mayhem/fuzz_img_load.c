#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <stdint.h>
#include "alloc_cap.h"

/* Format sniffing loader: IMG_Load_IO tries each IMG_isXXX detector and dispatches to that decoder. */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    SDL_IOStream *io = SDL_IOFromConstMem(data, size);
    if (!io) {
        return 0;
    }
    SDL_Surface *surface = IMG_Load_IO(io, true);
    SDL_DestroySurface(surface);
    return 0;
}
