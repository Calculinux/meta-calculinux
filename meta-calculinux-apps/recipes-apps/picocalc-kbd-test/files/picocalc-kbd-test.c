/*
 * PicoCalc Keyboard Test Utility
 * 
 * Visual keyboard tester with graphical representation of the PicoCalc keyboard.
 * Shows pressed keys in real-time and displays key information at the bottom.
 */

#include <SDL.h>
#include <SDL_ttf.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 480
#define KEY_SIZE 18
#define KEY_SPACING 2
#define SMALL_KEY_SIZE 16
#define MAX_KEY_INFO_LEN 256

// Colors
#define COLOR_BG {20, 20, 20, 255}
#define COLOR_KEY_NORMAL {60, 60, 60, 255}
#define COLOR_KEY_PRESSED {0, 200, 0, 255}
#define COLOR_KEY_SPECIAL {40, 80, 120, 255}
#define COLOR_KEY_SPECIAL_PRESSED {40, 150, 255, 255}
#define COLOR_TEXT {255, 255, 255, 255}
#define COLOR_INFO_BG {40, 40, 60, 255}

typedef struct {
    int x, y, w, h;
    SDL_Keycode keycode;
    const char *label;
    bool is_special;
} Key;

typedef struct {
    SDL_Window *window;
    SDL_Renderer *renderer;
    TTF_Font *font;
    TTF_Font *small_font;
    bool running;
    bool keys_pressed[SDL_NUM_SCANCODES];
    char key_info[MAX_KEY_INFO_LEN];
    SDL_Keymod mod_state;
} App;

// Define the keyboard layout based on the PicoCalc image
Key keyboard_layout[] = {
    // D-Pad (top left)
    {10, 130, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_UP, "↑", true},
    {10, 148, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_LEFT, "←", true},
    {28, 148, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_RIGHT, "→", true},
    {10, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_DOWN, "↓", true},
    
    // Function keys row
    {80, 130, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F1, "F1", true},
    {100, 130, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F2, "F2", true},
    {120, 130, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F3, "F3", true},
    {140, 130, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F4, "F4", true},
    {160, 130, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F5, "F5", true},
    
    // Second function row
    {80, 148, KEY_SIZE, SMALL_KEY_SIZE, SDLK_ESCAPE, "Esc", true},
    {100, 148, KEY_SIZE, SMALL_KEY_SIZE, SDLK_TAB, "Tab", true},
    {120, 148, KEY_SIZE, SMALL_KEY_SIZE, SDLK_CAPSLOCK, "Cap", true},
    {140, 148, KEY_SIZE, SMALL_KEY_SIZE, SDLK_DELETE, "Del", true},
    {160, 148, KEY_SIZE, SMALL_KEY_SIZE, SDLK_BACKSPACE, "Bk", true},
    
    // Symbol row
    {80, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_BACKSLASH, "\\", false},
    {98, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_SLASH, "/", false},
    {116, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_BACKQUOTE, "`", false},
    {134, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_MINUS, "-", false},
    {152, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_EQUALS, "=", false},
    {170, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_LEFTBRACKET, "[", false},
    {188, 166, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_RIGHTBRACKET, "]", false},
    
    // Number row
    {10, 188, KEY_SIZE, KEY_SIZE, SDLK_1, "1", false},
    {30, 188, KEY_SIZE, KEY_SIZE, SDLK_2, "2", false},
    {50, 188, KEY_SIZE, KEY_SIZE, SDLK_3, "3", false},
    {70, 188, KEY_SIZE, KEY_SIZE, SDLK_4, "4", false},
    {90, 188, KEY_SIZE, KEY_SIZE, SDLK_5, "5", false},
    {110, 188, KEY_SIZE, KEY_SIZE, SDLK_6, "6", false},
    {130, 188, KEY_SIZE, KEY_SIZE, SDLK_7, "7", false},
    {150, 188, KEY_SIZE, KEY_SIZE, SDLK_8, "8", false},
    {170, 188, KEY_SIZE, KEY_SIZE, SDLK_9, "9", false},
    {190, 188, KEY_SIZE, KEY_SIZE, SDLK_0, "0", false},
    
    // QWERTY row
    {10, 210, KEY_SIZE, KEY_SIZE, SDLK_q, "Q", false},
    {30, 210, KEY_SIZE, KEY_SIZE, SDLK_w, "W", false},
    {50, 210, KEY_SIZE, KEY_SIZE, SDLK_e, "E", false},
    {70, 210, KEY_SIZE, KEY_SIZE, SDLK_r, "R", false},
    {90, 210, KEY_SIZE, KEY_SIZE, SDLK_t, "T", false},
    {110, 210, KEY_SIZE, KEY_SIZE, SDLK_y, "Y", false},
    {130, 210, KEY_SIZE, KEY_SIZE, SDLK_u, "U", false},
    {150, 210, KEY_SIZE, KEY_SIZE, SDLK_i, "I", false},
    {170, 210, KEY_SIZE, KEY_SIZE, SDLK_o, "O", false},
    {190, 210, KEY_SIZE, KEY_SIZE, SDLK_p, "P", false},
    
    // ASDF row
    {10, 232, KEY_SIZE, KEY_SIZE, SDLK_a, "A", false},
    {30, 232, KEY_SIZE, KEY_SIZE, SDLK_s, "S", false},
    {50, 232, KEY_SIZE, KEY_SIZE, SDLK_d, "D", false},
    {70, 232, KEY_SIZE, KEY_SIZE, SDLK_f, "F", false},
    {90, 232, KEY_SIZE, KEY_SIZE, SDLK_g, "G", false},
    {110, 232, KEY_SIZE, KEY_SIZE, SDLK_h, "H", false},
    {130, 232, KEY_SIZE, KEY_SIZE, SDLK_j, "J", false},
    {150, 232, KEY_SIZE, KEY_SIZE, SDLK_k, "K", false},
    {170, 232, KEY_SIZE, KEY_SIZE, SDLK_l, "L", false},
    {190, 232, KEY_SIZE, KEY_SIZE, SDLK_SEMICOLON, ";", false},
    
    // ZXCV row
    {10, 254, KEY_SIZE, KEY_SIZE, SDLK_z, "Z", false},
    {30, 254, KEY_SIZE, KEY_SIZE, SDLK_x, "X", false},
    {50, 254, KEY_SIZE, KEY_SIZE, SDLK_c, "C", false},
    {70, 254, KEY_SIZE, KEY_SIZE, SDLK_v, "V", false},
    {90, 254, KEY_SIZE, KEY_SIZE, SDLK_b, "B", false},
    {110, 254, KEY_SIZE, KEY_SIZE, SDLK_n, "N", false},
    {130, 254, KEY_SIZE, KEY_SIZE, SDLK_m, "M", false},
    {150, 254, KEY_SIZE, KEY_SIZE, SDLK_COMMA, ",", false},
    {170, 254, KEY_SIZE, KEY_SIZE, SDLK_PERIOD, ".", false},
    {190, 254, KEY_SIZE + 10, KEY_SIZE, SDLK_RETURN, "Ent", true},
    
    // Bottom row (modifiers and space)
    {10, 276, KEY_SIZE + 5, KEY_SIZE, SDLK_LSHIFT, "Shift", true},
    {38, 276, KEY_SIZE, KEY_SIZE, SDLK_LCTRL, "Ctrl", true},
    {60, 276, KEY_SIZE, KEY_SIZE, SDLK_LALT, "Alt", true},
    {82, 276, KEY_SIZE * 4, KEY_SIZE, SDLK_SPACE, "", true},
    {162, 276, SMALL_KEY_SIZE, KEY_SIZE, SDLK_QUOTE, "'", false},
    {180, 276, SMALL_KEY_SIZE, KEY_SIZE, SDLK_LEFTPAREN, "(", false},
    {198, 276, SMALL_KEY_SIZE, KEY_SIZE, SDLK_RIGHTPAREN, ")", false},
    {216, 276, KEY_SIZE + 10, KEY_SIZE, SDLK_RSHIFT, "Shift", true},
};

#define NUM_KEYS (sizeof(keyboard_layout) / sizeof(Key))

void init_app(App *app) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) < 0) {
        fprintf(stderr, "SDL initialization failed: %s\n", SDL_GetError());
        exit(1);
    }
    
    if (TTF_Init() < 0) {
        fprintf(stderr, "SDL_ttf initialization failed: %s\n", TTF_GetError());
        SDL_Quit();
        exit(1);
    }
    
    SDL_SetHint(SDL_HINT_GRAB_KEYBOARD, "1");

    app->window = SDL_CreateWindow(
        "PicoCalc Keyboard Test",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        SDL_WINDOW_SHOWN | SDL_WINDOW_FULLSCREEN
    );
    
    if (!app->window) {
        fprintf(stderr, "Window creation failed: %s\n", SDL_GetError());
        TTF_Quit();
        SDL_Quit();
        exit(1);
    }
    
    SDL_SetWindowGrab(app->window, SDL_TRUE);
    
    app->renderer = SDL_CreateRenderer(app->window, -1, 
                                       SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!app->renderer) {
        app->renderer = SDL_CreateRenderer(app->window, -1, SDL_RENDERER_SOFTWARE);
    }

    if (!app->renderer) {
        fprintf(stderr, "Renderer creation failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(app->window);
        TTF_Quit();
        SDL_Quit();
        exit(1);
    }
    
    // Try to load fonts - use built-in if not available
    app->font = TTF_OpenFont("/usr/share/fonts/ttf/DejaVuSans.ttf", 12);
    if (!app->font) {
        app->font = TTF_OpenFont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12);
    }
    
    app->small_font = TTF_OpenFont("/usr/share/fonts/ttf/DejaVuSans.ttf", 8);
    if (!app->small_font) {
        app->small_font = TTF_OpenFont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 8);
    }
    
    app->running = true;
    memset(app->keys_pressed, 0, sizeof(app->keys_pressed));
    snprintf(app->key_info, MAX_KEY_INFO_LEN, "Press any key...");
    app->mod_state = KMOD_NONE;
}

void cleanup_app(App *app) {
    if (app->font) TTF_CloseFont(app->font);
    if (app->small_font) TTF_CloseFont(app->small_font);
    if (app->renderer) SDL_DestroyRenderer(app->renderer);
    if (app->window) SDL_DestroyWindow(app->window);
    TTF_Quit();
    SDL_Quit();
}

void draw_text(App *app, const char *text, int x, int y, SDL_Color color, TTF_Font *font) {
    if (!font) return;
    
    SDL_Surface *surface = TTF_RenderText_Blended(font, text, color);
    if (!surface) return;
    
    SDL_Texture *texture = SDL_CreateTextureFromSurface(app->renderer, surface);
    if (texture) {
        SDL_Rect dest = {x, y, surface->w, surface->h};
        SDL_RenderCopy(app->renderer, texture, NULL, &dest);
        SDL_DestroyTexture(texture);
    }
    SDL_FreeSurface(surface);
}

void draw_key(App *app, Key *key) {
    SDL_Rect rect = {key->x, key->y, key->w, key->h};
    SDL_Scancode scancode = SDL_GetScancodeFromKey(key->keycode);
    bool is_pressed = app->keys_pressed[scancode];
    
    SDL_Color color;
    if (is_pressed) {
        if (key->is_special) {
            color = (SDL_Color)COLOR_KEY_SPECIAL_PRESSED;
        } else {
            color = (SDL_Color)COLOR_KEY_PRESSED;
        }
    } else {
        if (key->is_special) {
            color = (SDL_Color)COLOR_KEY_SPECIAL;
        } else {
            color = (SDL_Color)COLOR_KEY_NORMAL;
        }
    }
    
    SDL_SetRenderDrawColor(app->renderer, color.r, color.g, color.b, color.a);
    SDL_RenderFillRect(app->renderer, &rect);
    
    // Draw border
    SDL_SetRenderDrawColor(app->renderer, 100, 100, 100, 255);
    SDL_RenderDrawRect(app->renderer, &rect);
    
    // Draw label
    if (key->label && strlen(key->label) > 0) {
        SDL_Color text_color = COLOR_TEXT;
        TTF_Font *label_font = (key->w <= SMALL_KEY_SIZE) ? app->small_font : app->font;
        if (label_font) {
            int text_w, text_h;
            TTF_SizeText(label_font, key->label, &text_w, &text_h);
            int text_x = key->x + (key->w - text_w) / 2;
            int text_y = key->y + (key->h - text_h) / 2;
            draw_text(app, key->label, text_x, text_y, text_color, label_font);
        }
    }
}

void draw_header(App *app) {
    SDL_Color text_color = COLOR_TEXT;
    const char *title = "PicoCalc Keyboard Test";
    
    if (app->font) {
        int text_w, text_h;
        TTF_SizeText(app->font, title, &text_w, &text_h);
        draw_text(app, title, (SCREEN_WIDTH - text_w) / 2, 10, text_color, app->font);
        
        const char *instruction = "Press ESC+Q to quit";
        TTF_SizeText(app->small_font, instruction, &text_w, &text_h);
        draw_text(app, instruction, (SCREEN_WIDTH - text_w) / 2, 30, text_color, app->small_font);
    }
    
    // Draw device outline
    SDL_SetRenderDrawColor(app->renderer, 80, 80, 80, 255);
    SDL_Rect device_outline = {5, 50, SCREEN_WIDTH - 10, 260};
    SDL_RenderDrawRect(app->renderer, &device_outline);
    
    // Screen area representation
    SDL_SetRenderDrawColor(app->renderer, 30, 30, 50, 255);
    SDL_Rect screen_area = {15, 60, SCREEN_WIDTH - 30, 60};
    SDL_RenderFillRect(app->renderer, &screen_area);
    SDL_SetRenderDrawColor(app->renderer, 0, 100, 0, 255);
    SDL_RenderDrawRect(app->renderer, &screen_area);
}

void draw_info_panel(App *app) {
    // Info panel background
    SDL_Color bg_color = COLOR_INFO_BG;
    SDL_SetRenderDrawColor(app->renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a);
    SDL_Rect info_rect = {0, SCREEN_HEIGHT - 160, SCREEN_WIDTH, 160};
    SDL_RenderFillRect(app->renderer, &info_rect);
    
    // Border
    SDL_SetRenderDrawColor(app->renderer, 100, 100, 150, 255);
    SDL_RenderDrawRect(app->renderer, &info_rect);
    
    if (app->font) {
        SDL_Color text_color = COLOR_TEXT;
        
        // Title
        draw_text(app, "Key Information:", 10, SCREEN_HEIGHT - 150, text_color, app->font);
        
        // Key info
        draw_text(app, app->key_info, 10, SCREEN_HEIGHT - 130, text_color, app->small_font);
        
        // Modifier state
        char mod_info[128];
        snprintf(mod_info, sizeof(mod_info), "Modifiers: %s%s%s%s%s",
                (app->mod_state & KMOD_SHIFT) ? "SHIFT " : "",
                (app->mod_state & KMOD_CTRL) ? "CTRL " : "",
                (app->mod_state & KMOD_ALT) ? "ALT " : "",
                (app->mod_state & KMOD_GUI) ? "GUI " : "",
                (app->mod_state == KMOD_NONE) ? "None" : "");
        draw_text(app, mod_info, 10, SCREEN_HEIGHT - 110, text_color, app->small_font);
        
        // Active keys count
        int active_count = 0;
        for (int i = 0; i < SDL_NUM_SCANCODES; i++) {
            if (app->keys_pressed[i]) active_count++;
        }
        char count_info[64];
        snprintf(count_info, sizeof(count_info), "Active keys: %d", active_count);
        draw_text(app, count_info, 10, SCREEN_HEIGHT - 90, text_color, app->small_font);
        
        // Instructions
        draw_text(app, "Press keys to test", 10, SCREEN_HEIGHT - 60, text_color, app->small_font);
        draw_text(app, "ESC + Q to quit", 10, SCREEN_HEIGHT - 40, text_color, app->small_font);
        draw_text(app, "All keys with modifiers shown above", 10, SCREEN_HEIGHT - 20, text_color, app->small_font);
    }
}

void render(App *app) {
    SDL_Color bg = COLOR_BG;
    SDL_SetRenderDrawColor(app->renderer, bg.r, bg.g, bg.b, bg.a);
    SDL_RenderClear(app->renderer);
    
    // Draw header with title and device outline
    draw_header(app);
    
    // Draw all keys
    for (int i = 0; i < NUM_KEYS; i++) {
        draw_key(app, &keyboard_layout[i]);
    }
    
    // Draw info panel
    draw_info_panel(app);
    
    SDL_RenderPresent(app->renderer);
}

void handle_key_event(App *app, SDL_Event *event) {
    SDL_Scancode scancode = event->key.keysym.scancode;
    SDL_Keycode keycode = event->key.keysym.sym;
    
    if (event->type == SDL_KEYDOWN) {
        app->keys_pressed[scancode] = true;
        app->mod_state = SDL_GetModState();
        
        // Update key info
        const char *key_name = SDL_GetKeyName(keycode);
        const char *scancode_name = SDL_GetScancodeName(scancode);
        
        snprintf(app->key_info, MAX_KEY_INFO_LEN,
                "Key: %s (0x%X)\nScancode: %s (%d)\nMod: 0x%X",
                key_name, keycode, scancode_name, scancode, app->mod_state);
        
        // Check for quit combination (ESC + Q)
        if (keycode == SDLK_q && (app->mod_state & KMOD_CTRL)) {
            app->running = false;
        }
        if ((keycode == SDLK_ESCAPE || keycode == SDLK_q) && 
            app->keys_pressed[SDL_GetScancodeFromKey(SDLK_ESCAPE)]) {
            app->running = false;
        }
        
    } else if (event->type == SDL_KEYUP) {
        app->keys_pressed[scancode] = false;
        app->mod_state = SDL_GetModState();
    }
}

void handle_events(App *app) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_QUIT:
                app->running = false;
                break;
                
            case SDL_KEYDOWN:
            case SDL_KEYUP:
                handle_key_event(app, &event);
                break;
        }
    }
}

int main(int argc, char *argv[]) {
    App app = {0};
    
    printf("PicoCalc Keyboard Test Utility\n");
    printf("==============================\n\n");
    
    init_app(&app);
    
    printf("Application initialized successfully\n");
    printf("Press keys to test the keyboard\n");
    printf("Press ESC+Q or Ctrl+Q to quit\n\n");
    
    while (app.running) {
        handle_events(&app);
        render(&app);
        SDL_Delay(16); // ~60 FPS
    }
    
    printf("\nShutting down...\n");
    cleanup_app(&app);
    
    return 0;
}
