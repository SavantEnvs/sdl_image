#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <stdint.h>
#include "alloc_cap.h"

/* Animation loader: GIF, WebP, APNG, AVIFS and ANI are detected by magic; anything else becomes a one-frame animation. */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    SDL_IOStream *io = SDL_IOFromConstMem(data, size);
    if (!io) {
        return 0;
    }
    IMG_Animation *anim = IMG_LoadAnimation_IO(io, true);
    if (anim) {
        IMG_FreeAnimation(anim);
    }
    return 0;
}
