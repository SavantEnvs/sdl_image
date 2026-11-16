#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <stdint.h>
#include "alloc_cap.h"

/* The incremental animation decoder takes the format from its caller, so the first input byte selects it
   (seeds carry the selector); the rest is the file. Frames are pulled until the decoder completes or fails. */
static const char *const kTypes[] = { "ani", "apng", "avifs", "gif", "webp", "tga", "jpg" };

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size < 1) {
        return -1;
    }
    const char *type = kTypes[data[0] % (sizeof(kTypes) / sizeof(kTypes[0]))];
    SDL_IOStream *io = SDL_IOFromConstMem(data + 1, size - 1);
    if (!io) {
        return 0;
    }
    IMG_AnimationDecoder *dec = IMG_CreateAnimationDecoder_IO(io, true, type);
    if (!dec) {
        return 0;
    }
    for (int i = 0; i < 64; ++i) {
        SDL_Surface *frame = NULL;
        Uint64 duration = 0;
        if (!IMG_GetAnimationDecoderFrame(dec, &frame, &duration)) {
            break;
        }
        SDL_DestroySurface(frame);
        if (IMG_GetAnimationDecoderStatus(dec) != IMG_DECODER_STATUS_OK) {
            break;
        }
    }
    IMG_CloseAnimationDecoder(dec);
    return 0;
}
