/*
 * SDL2 Backend Listing Utility
 * 
 * Lists all available SDL2 video and audio drivers
 */

#include <SDL.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        fprintf(stderr, "SDL initialization failed: %s\n", SDL_GetError());
        return 1;
    }
    
    printf("=== SDL2 Backend Information ===\n\n");
    
    // Video drivers
    printf("Video Drivers:\n");
    int num_video_drivers = SDL_GetNumVideoDrivers();
    printf("  Total available: %d\n", num_video_drivers);
    for (int i = 0; i < num_video_drivers; i++) {
        const char *driver = SDL_GetVideoDriver(i);
        printf("    [%d] %s\n", i, driver);
    }
    
    // Current video driver
    const char *current_video = SDL_GetCurrentVideoDriver();
    if (current_video) {
        printf("  Currently using: %s\n", current_video);
    } else {
        printf("  No video driver initialized\n");
    }
    
    printf("\n");
    
    // Audio drivers
    printf("Audio Drivers:\n");
    int num_audio_drivers = SDL_GetNumAudioDrivers();
    printf("  Total available: %d\n", num_audio_drivers);
    for (int i = 0; i < num_audio_drivers; i++) {
        const char *driver = SDL_GetAudioDriver(i);
        printf("    [%d] %s\n", i, driver);
    }
    
    // Current audio driver
    const char *current_audio = SDL_GetCurrentAudioDriver();
    if (current_audio) {
        printf("  Currently using: %s\n", current_audio);
    } else {
        printf("  No audio driver initialized\n");
    }
    
    printf("\n");
    
    // Render drivers (need to create a window first for this)
    printf("Render Drivers:\n");
    int num_render_drivers = SDL_GetNumRenderDrivers();
    printf("  Total available: %d\n", num_render_drivers);
    for (int i = 0; i < num_render_drivers; i++) {
        SDL_RendererInfo info;
        if (SDL_GetRenderDriverInfo(i, &info) == 0) {
            printf("    [%d] %s\n", i, info.name);
            printf("        Flags: 0x%08x", info.flags);
            if (info.flags & SDL_RENDERER_SOFTWARE) printf(" SOFTWARE");
            if (info.flags & SDL_RENDERER_ACCELERATED) printf(" ACCELERATED");
            if (info.flags & SDL_RENDERER_PRESENTVSYNC) printf(" VSYNC");
            if (info.flags & SDL_RENDERER_TARGETTEXTURE) printf(" TARGETTEXTURE");
            printf("\n");
            printf("        Max texture: %dx%d\n", info.max_texture_width, info.max_texture_height);
        }
    }
    
    printf("\n");
    
    // Platform info
    printf("Platform Information:\n");
    printf("  Platform: %s\n", SDL_GetPlatform());
    printf("  SDL Version: %d.%d.%d\n", 
           SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL);
    
    SDL_version compiled;
    SDL_version linked;
    SDL_VERSION(&compiled);
    SDL_GetVersion(&linked);
    printf("  Compiled against: %d.%d.%d\n", 
           compiled.major, compiled.minor, compiled.patch);
    printf("  Linked against: %d.%d.%d\n", 
           linked.major, linked.minor, linked.patch);
    
    SDL_Quit();
    return 0;
}
