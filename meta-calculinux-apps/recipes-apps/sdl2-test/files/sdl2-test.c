/*
 * SDL2 Display Test Application for PicoCalc
 * 
 * This application tests various SDL2 capabilities:
 * - Display initialization
 * - Color rendering
 * - Pixel drawing
 * - Rectangle drawing
 * - Line drawing
 * - Double buffering
 * - Event handling
 * - Screen clearing
 */

#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 480

typedef struct {
    SDL_Window *window;
    SDL_Renderer *renderer;
    bool running;
    int test_phase;
} App;

void init_app(App *app) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "SDL initialization failed: %s\n", SDL_GetError());
        exit(1);
    }
    
    printf("SDL initialized successfully\n");
    printf("SDL Video Driver: %s\n", SDL_GetCurrentVideoDriver());
    
    app->window = SDL_CreateWindow(
        "PicoCalc SDL2 Test",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        SDL_WINDOW_SHOWN
    );
    
    if (!app->window) {
        fprintf(stderr, "Window creation failed: %s\n", SDL_GetError());
        SDL_Quit();
        exit(1);
    }
    
    printf("Window created successfully\n");
    
    app->renderer = SDL_CreateRenderer(app->window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!app->renderer) {
        fprintf(stderr, "Renderer creation failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(app->window);
        SDL_Quit();
        exit(1);
    }
    
    SDL_RendererInfo info;
    SDL_GetRendererInfo(app->renderer, &info);
    printf("Renderer created successfully\n");
    printf("Renderer name: %s\n", info.name);
    printf("Renderer flags: 0x%x\n", info.flags);
    printf("Max texture size: %dx%d\n", info.max_texture_width, info.max_texture_height);
    
    app->running = true;
    app->test_phase = 0;
}

void cleanup_app(App *app) {
    SDL_DestroyRenderer(app->renderer);
    SDL_DestroyWindow(app->window);
    SDL_Quit();
}

void handle_events(App *app) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_QUIT:
                app->running = false;
                break;
            case SDL_KEYDOWN:
                if (event.key.keysym.sym == SDLK_ESCAPE) {
                    app->running = false;
                } else if (event.key.keysym.sym == SDLK_SPACE) {
                    app->test_phase = (app->test_phase + 1) % 8;
                    printf("Test phase: %d\n", app->test_phase);
                }
                break;
        }
    }
}

void test_solid_colors(SDL_Renderer *renderer, int phase) {
    // Test different solid colors
    switch (phase % 8) {
        case 0: // Red
            SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
            break;
        case 1: // Green
            SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
            break;
        case 2: // Blue
            SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
            break;
        case 3: // White
            SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
            break;
        case 4: // Yellow
            SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
            break;
        case 5: // Cyan
            SDL_SetRenderDrawColor(renderer, 0, 255, 255, 255);
            break;
        case 6: // Magenta
            SDL_SetRenderDrawColor(renderer, 255, 0, 255, 255);
            break;
        case 7: // Black
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            break;
    }
    SDL_RenderClear(renderer);
}

void test_gradients(SDL_Renderer *renderer, int frame) {
    // Draw a color gradient
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        int r = (y * 255) / SCREEN_HEIGHT;
        int g = 255 - r;
        int b = (frame + y) % 255;
        SDL_SetRenderDrawColor(renderer, r, g, b, 255);
        SDL_RenderDrawLine(renderer, 0, y, SCREEN_WIDTH, y);
    }
}

void test_shapes(SDL_Renderer *renderer, int frame) {
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    
    // Draw rectangles
    SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    SDL_Rect rect1 = {50, 50, 100, 80};
    SDL_RenderFillRect(renderer, &rect1);
    
    SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
    SDL_Rect rect2 = {170, 100, 100, 80};
    SDL_RenderFillRect(renderer, &rect2);
    
    SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
    SDL_Rect rect3 = {110, 200, 100, 80};
    SDL_RenderDrawRect(renderer, &rect3);
    
    // Draw lines
    SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
    for (int i = 0; i < 10; i++) {
        SDL_RenderDrawLine(renderer, i * 32, 300, SCREEN_WIDTH - i * 32, 400);
    }
    
    // Draw animated circle using points
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    int cx = SCREEN_WIDTH / 2;
    int cy = SCREEN_HEIGHT - 50;
    int radius = 30 + (frame % 20);
    
    for (int angle = 0; angle < 360; angle += 2) {
        float rad = angle * M_PI / 180.0f;
        int x = cx + (int)(radius * cos(rad));
        int y = cy + (int)(radius * sin(rad));
        SDL_RenderDrawPoint(renderer, x, y);
    }
}

void test_pixel_drawing(SDL_Renderer *renderer, int frame) {
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    
    // Draw random pixels
    for (int i = 0; i < 5000; i++) {
        int x = rand() % SCREEN_WIDTH;
        int y = rand() % SCREEN_HEIGHT;
        int r = (x + frame) % 255;
        int g = (y + frame) % 255;
        int b = (x + y) % 255;
        SDL_SetRenderDrawColor(renderer, r, g, b, 255);
        SDL_RenderDrawPoint(renderer, x, y);
    }
}

void render(App *app, int frame) {
    switch (app->test_phase) {
        case 0:
            test_solid_colors(app->renderer, frame / 60);
            break;
        case 1:
            test_gradients(app->renderer, frame);
            break;
        case 2:
            test_shapes(app->renderer, frame);
            break;
        case 3:
            test_pixel_drawing(app->renderer, frame);
            break;
        case 4:
            // Checkerboard pattern
            SDL_SetRenderDrawColor(app->renderer, 0, 0, 0, 255);
            SDL_RenderClear(app->renderer);
            SDL_SetRenderDrawColor(app->renderer, 255, 255, 255, 255);
            for (int y = 0; y < SCREEN_HEIGHT; y += 20) {
                for (int x = 0; x < SCREEN_WIDTH; x += 20) {
                    if ((x / 20 + y / 20) % 2 == 0) {
                        SDL_Rect rect = {x, y, 20, 20};
                        SDL_RenderFillRect(app->renderer, &rect);
                    }
                }
            }
            break;
        case 5:
            // Moving rectangle
            SDL_SetRenderDrawColor(app->renderer, 0, 0, 50, 255);
            SDL_RenderClear(app->renderer);
            SDL_SetRenderDrawColor(app->renderer, 255, 128, 0, 255);
            int x = (frame * 2) % (SCREEN_WIDTH + 100) - 50;
            SDL_Rect rect = {x, SCREEN_HEIGHT / 2 - 25, 50, 50};
            SDL_RenderFillRect(app->renderer, &rect);
            break;
        case 6:
            // Vertical stripes
            for (int x = 0; x < SCREEN_WIDTH; x += 10) {
                int color = ((x / 10) + (frame / 10)) % 2 ? 255 : 0;
                SDL_SetRenderDrawColor(app->renderer, color, color, color, 255);
                SDL_Rect rect = {x, 0, 10, SCREEN_HEIGHT};
                SDL_RenderFillRect(app->renderer, &rect);
            }
            break;
        case 7:
            // All tests info screen
            SDL_SetRenderDrawColor(app->renderer, 0, 0, 128, 255);
            SDL_RenderClear(app->renderer);
            SDL_SetRenderDrawColor(app->renderer, 255, 255, 255, 255);
            
            // Draw title bar
            SDL_Rect title = {0, 0, SCREEN_WIDTH, 40};
            SDL_RenderFillRect(app->renderer, &title);
            
            // Draw test indicators
            for (int i = 0; i < 7; i++) {
                SDL_SetRenderDrawColor(app->renderer, 
                    i * 36, 255 - i * 36, 128, 255);
                SDL_Rect indicator = {20 + i * 40, 60 + i * 50, 30, 30};
                SDL_RenderFillRect(app->renderer, &indicator);
            }
            break;
    }
    
    SDL_RenderPresent(app->renderer);
}

int main(int argc, char *argv[]) {
    App app;
    int frame = 0;
    
    printf("=== PicoCalc SDL2 Test Application ===\n");
    printf("Press SPACE to cycle through tests\n");
    printf("Press ESC to exit\n\n");
    
    init_app(&app);
    
    printf("\nStarting test loop...\n");
    printf("Tests:\n");
    printf("  0: Solid colors (cycles every second)\n");
    printf("  1: Color gradients\n");
    printf("  2: Shapes and lines\n");
    printf("  3: Pixel drawing\n");
    printf("  4: Checkerboard\n");
    printf("  5: Moving rectangle\n");
    printf("  6: Vertical stripes\n");
    printf("  7: Test summary\n\n");
    
    while (app.running) {
        handle_events(&app);
        render(&app, frame);
        frame++;
        SDL_Delay(16); // ~60 FPS
    }
    
    cleanup_app(&app);
    printf("Test completed successfully\n");
    
    return 0;
}
