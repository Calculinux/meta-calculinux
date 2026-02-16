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
#include <fcntl.h>
#include <unistd.h>

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 320
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
    bool left_shift_pressed;
    bool right_shift_pressed;
    bool mouse_mode;
    char shifted_key_info[MAX_KEY_INFO_LEN];
    char led_path[256];
} App;

// Define the keyboard layout based on the PicoCalc image
Key keyboard_layout[] = {
    // D-Pad (top left)
    {10, 40, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_UP, "↑", true},
    {10, 58, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_LEFT, "←", true},
    {28, 58, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_RIGHT, "→", true},
    {10, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_DOWN, "↓", true},
    
    // Function keys row
    {80, 40, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F1, "F1", true},
    {100, 40, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F2, "F2", true},
    {120, 40, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F3, "F3", true},
    {140, 40, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F4, "F4", true},
    {160, 40, KEY_SIZE, SMALL_KEY_SIZE, SDLK_F5, "F5", true},
    
    // Second function row
    {80, 58, KEY_SIZE, SMALL_KEY_SIZE, SDLK_ESCAPE, "Esc", true},
    {100, 58, KEY_SIZE, SMALL_KEY_SIZE, SDLK_TAB, "Tab", true},
    {120, 58, KEY_SIZE, SMALL_KEY_SIZE, SDLK_CAPSLOCK, "Cap", true},
    {140, 58, KEY_SIZE, SMALL_KEY_SIZE, SDLK_DELETE, "Del", true},
    {160, 58, KEY_SIZE, SMALL_KEY_SIZE, SDLK_BACKSPACE, "Bk", true},
    
    // Symbol row
    {80, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_BACKSLASH, "\\", false},
    {98, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_SLASH, "/", false},
    {116, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_BACKQUOTE, "`", false},
    {134, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_MINUS, "-", false},
    {152, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_EQUALS, "=", false},
    {170, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_LEFTBRACKET, "[", false},
    {188, 76, SMALL_KEY_SIZE, SMALL_KEY_SIZE, SDLK_RIGHTBRACKET, "]", false},
    
    // Number row
    {10, 98, KEY_SIZE, KEY_SIZE, SDLK_1, "1", false},
    {30, 98, KEY_SIZE, KEY_SIZE, SDLK_2, "2", false},
    {50, 98, KEY_SIZE, KEY_SIZE, SDLK_3, "3", false},
    {70, 98, KEY_SIZE, KEY_SIZE, SDLK_4, "4", false},
    {90, 98, KEY_SIZE, KEY_SIZE, SDLK_5, "5", false},
    {110, 98, KEY_SIZE, KEY_SIZE, SDLK_6, "6", false},
    {130, 98, KEY_SIZE, KEY_SIZE, SDLK_7, "7", false},
    {150, 98, KEY_SIZE, KEY_SIZE, SDLK_8, "8", false},
    {170, 98, KEY_SIZE, KEY_SIZE, SDLK_9, "9", false},
    {190, 98, KEY_SIZE, KEY_SIZE, SDLK_0, "0", false},
    
    // QWERTY row
    {10, 120, KEY_SIZE, KEY_SIZE, SDLK_q, "Q", false},
    {30, 120, KEY_SIZE, KEY_SIZE, SDLK_w, "W", false},
    {50, 120, KEY_SIZE, KEY_SIZE, SDLK_e, "E", false},
    {70, 120, KEY_SIZE, KEY_SIZE, SDLK_r, "R", false},
    {90, 120, KEY_SIZE, KEY_SIZE, SDLK_t, "T", false},
    {110, 120, KEY_SIZE, KEY_SIZE, SDLK_y, "Y", false},
    {130, 120, KEY_SIZE, KEY_SIZE, SDLK_u, "U", false},
    {150, 120, KEY_SIZE, KEY_SIZE, SDLK_i, "I", false},
    {170, 120, KEY_SIZE, KEY_SIZE, SDLK_o, "O", false},
    {190, 120, KEY_SIZE, KEY_SIZE, SDLK_p, "P", false},
    
    // ASDF row
    {10, 142, KEY_SIZE, KEY_SIZE, SDLK_a, "A", false},
    {30, 142, KEY_SIZE, KEY_SIZE, SDLK_s, "S", false},
    {50, 142, KEY_SIZE, KEY_SIZE, SDLK_d, "D", false},
    {70, 142, KEY_SIZE, KEY_SIZE, SDLK_f, "F", false},
    {90, 142, KEY_SIZE, KEY_SIZE, SDLK_g, "G", false},
    {110, 142, KEY_SIZE, KEY_SIZE, SDLK_h, "H", false},
    {130, 142, KEY_SIZE, KEY_SIZE, SDLK_j, "J", false},
    {150, 142, KEY_SIZE, KEY_SIZE, SDLK_k, "K", false},
    {170, 142, KEY_SIZE, KEY_SIZE, SDLK_l, "L", false},
    {190, 142, KEY_SIZE, KEY_SIZE, SDLK_SEMICOLON, ";", false},
    
    // ZXCV row
    {10, 164, KEY_SIZE, KEY_SIZE, SDLK_z, "Z", false},
    {30, 164, KEY_SIZE, KEY_SIZE, SDLK_x, "X", false},
    {50, 164, KEY_SIZE, KEY_SIZE, SDLK_c, "C", false},
    {70, 164, KEY_SIZE, KEY_SIZE, SDLK_v, "V", false},
    {90, 164, KEY_SIZE, KEY_SIZE, SDLK_b, "B", false},
    {110, 164, KEY_SIZE, KEY_SIZE, SDLK_n, "N", false},
    {130, 164, KEY_SIZE, KEY_SIZE, SDLK_m, "M", false},
    {150, 164, KEY_SIZE, KEY_SIZE, SDLK_COMMA, ",", false},
    {170, 164, KEY_SIZE, KEY_SIZE, SDLK_PERIOD, ".", false},
    {190, 164, KEY_SIZE + 10, KEY_SIZE, SDLK_RETURN, "Ent", true},
    
    // Bottom row (modifiers and space)
    {10, 186, KEY_SIZE + 5, KEY_SIZE, SDLK_LSHIFT, "Shift", true},
    {38, 186, KEY_SIZE, KEY_SIZE, SDLK_LCTRL, "Ctrl", true},
    {60, 186, KEY_SIZE, KEY_SIZE, SDLK_LALT, "Alt", true},
    {82, 186, KEY_SIZE * 4, KEY_SIZE, SDLK_SPACE, "", true},
    {162, 186, SMALL_KEY_SIZE, KEY_SIZE, SDLK_QUOTE, "'", false},
    {180, 186, SMALL_KEY_SIZE, KEY_SIZE, SDLK_LEFTPAREN, "(", false},
    {198, 186, SMALL_KEY_SIZE, KEY_SIZE, SDLK_RIGHTPAREN, ")", false},
    {216, 186, KEY_SIZE + 10, KEY_SIZE, SDLK_RSHIFT, "Shift", true},
};

#define NUM_KEYS (sizeof(keyboard_layout) / sizeof(Key))

// Find the keyboard mouse_mode sysfs attribute
bool find_mouse_mode_path(char *path, size_t path_size) {
    // Look for picocalc-mfd-kbd device in sysfs
    const char *base_paths[] = {
        "/sys/bus/platform/devices/picocalc-mfd-kbd/mouse_mode",
        "/sys/devices/platform/picocalc-mfd-kbd/mouse_mode",
        NULL
    };
    
    for (int i = 0; base_paths[i] != NULL; i++) {
        FILE *fp = fopen(base_paths[i], "r");
        if (fp) {
            fclose(fp);
            snprintf(path, path_size, "%s", base_paths[i]);
            return true;
        }
    }
    
    return false;
}

// Read mouse mode state from sysfs attribute
bool read_mouse_mode_state(const char *path) {
    if (!path || path[0] == '\0') {
        return false;
    }
    
    FILE *fp = fopen(path, "r");
    if (!fp) {
        return false;
    }
    
    int value = 0;
    fscanf(fp, "%d", &value);
    fclose(fp);
    
    return (value != 0);
}

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
    app->left_shift_pressed = false;
    app->right_shift_pressed = false;
    
    // Find and read mouse mode sysfs attribute
    if (find_mouse_mode_path(app->led_path, sizeof(app->led_path))) {
        app->mouse_mode = read_mouse_mode_state(app->led_path);
        printf("Found mouse mode attribute at: %s\n", app->led_path);
        printf("Initial mouse mode state: %s\n", app->mouse_mode ? "ON" : "OFF");
    } else {
        app->led_path[0] = '\0';
        app->mouse_mode = false;
        printf("Warning: Could not find mouse_mode sysfs attribute\n");
    }
    
    snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "");
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
    const char *title = "Keyboard Test";
    
    if (app->font) {
        int text_w, text_h;
        TTF_SizeText(app->font, title, &text_w, &text_h);
        draw_text(app, title, (SCREEN_WIDTH - text_w) / 2, 5, text_color, app->font);
        
        const char *instruction = "ESC+Q=quit";
        TTF_SizeText(app->small_font, instruction, &text_w, &text_h);
        draw_text(app, instruction, (SCREEN_WIDTH - text_w) / 2, 22, text_color, app->small_font);
    }
}

void draw_info_panel(App *app) {
    // Info panel background
    SDL_Color bg_color = COLOR_INFO_BG;
    SDL_SetRenderDrawColor(app->renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a);
    SDL_Rect info_rect = {0, SCREEN_HEIGHT - 110, SCREEN_WIDTH, 110};
    SDL_RenderFillRect(app->renderer, &info_rect);
    
    // Border
    SDL_SetRenderDrawColor(app->renderer, 100, 100, 150, 255);
    SDL_RenderDrawRect(app->renderer, &info_rect);
    
    if (app->font) {
        SDL_Color text_color = COLOR_TEXT;
        
        // Key info (compact)
        draw_text(app, app->key_info, 5, SCREEN_HEIGHT - 105, text_color, app->small_font);
        
        // Shifted key info if applicable
        if (strlen(app->shifted_key_info) > 0) {
            draw_text(app, app->shifted_key_info, 5, SCREEN_HEIGHT - 90, text_color, app->small_font);
        }
        
        // Modifier state with individual shift tracking
        char mod_info[128];
        snprintf(mod_info, sizeof(mod_info), "Mods: %s%s%s%s%s%s%s",
                app->left_shift_pressed ? "LShift " : "",
                app->right_shift_pressed ? "RShift " : "",
                (app->mod_state & KMOD_CTRL) ? "Ctrl " : "",
                (app->mod_state & KMOD_ALT) ? "Alt " : "",
                (app->mod_state & KMOD_GUI) ? "GUI " : "",
                app->mouse_mode ? "[MOUSE] " : "",
                (app->mod_state == KMOD_NONE && !app->left_shift_pressed && !app->right_shift_pressed) ? "None" : "");
        draw_text(app, mod_info, 5, SCREEN_HEIGHT - 65, text_color, app->small_font);
        
        // Active keys count
        int active_count = 0;
        for (int i = 0; i < SDL_NUM_SCANCODES; i++) {
            if (app->keys_pressed[i]) active_count++;
        }
        char count_info[64];
        snprintf(count_info, sizeof(count_info), "Active: %d key%s", active_count, active_count == 1 ? "" : "s");
        draw_text(app, count_info, 5, SCREEN_HEIGHT - 45, text_color, app->small_font);
        
        // Instructions
        draw_text(app, "Press any key to test", 5, SCREEN_HEIGHT - 25, text_color, app->small_font);
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
        
        // Track individual shift keys
        if (scancode == SDL_SCANCODE_LSHIFT) {
            app->left_shift_pressed = true;
        }
        if (scancode == SDL_SCANCODE_RSHIFT) {
            app->right_shift_pressed = true;
        }
        
        // Note: Mouse mode is a toggle in the driver - we can't detect it reliably
        // from key events alone. The driver maintains this state and changes what
        // events it outputs. Check for REL_X/REL_Y events to detect if in mouse mode.
        
        // Update key info
        const char *key_name = SDL_GetKeyName(keycode);
        const char *scancode_name = SDL_GetScancodeName(scancode);
        
        snprintf(app->key_info, MAX_KEY_INFO_LEN,
                "%s (0x%X) | SC:%d",
                key_name, keycode, scancode);
        
        // Detect and display shifted key interpretations
        app->shifted_key_info[0] = '\0';  // Clear shifted info
        
        // Shifted function keys F1-F5 → F6-F10
        if ((app->mod_state & KMOD_SHIFT)) {
            if (keycode == SDLK_F1) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: F6");
            } else if (keycode == SDLK_F2) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: F7");
            } else if (keycode == SDLK_F3) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: F8");
            } else if (keycode == SDLK_F4) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: F9");
            } else if (keycode == SDLK_F5) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: F10");
            }
            // Shifted number/symbol row
            else if (keycode >= SDLK_1 && keycode <= SDLK_0) {
                const char *shifted_symbols[] = {"!", "@", "#", "$", "%", "^", "&", "*", "(", ")"};
                int idx = (keycode == SDLK_0) ? 9 : (keycode - SDLK_1);
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: %s", shifted_symbols[idx]);
            }
            // Other shifted keys
            else if (keycode == SDLK_MINUS) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: _");
            } else if (keycode == SDLK_EQUALS) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: +");
            } else if (keycode == SDLK_LEFTBRACKET) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: {");
            } else if (keycode == SDLK_RIGHTBRACKET) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: }");
            } else if (keycode == SDLK_BACKSLASH) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: |");
            } else if (keycode == SDLK_SEMICOLON) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: :");
            } else if (keycode == SDLK_QUOTE) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: \"");
            } else if (keycode == SDLK_COMMA) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: <");
            } else if (keycode == SDLK_PERIOD) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: >");
            } else if (keycode == SDLK_SLASH) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: ?");
            } else if (keycode == SDLK_BACKQUOTE) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: ~");
            }
            // Shift + arrow keys
            else if (keycode == SDLK_UP) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: PageUp");
            } else if (keycode == SDLK_DOWN) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: PageDown");
            } else if (keycode == SDLK_RETURN) {
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Shifted: Insert");
            }
        }
        
        // Alt+I → Insert detection
        if ((app->mod_state & KMOD_ALT) && keycode == SDLK_i) {
            snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, "Alt+I: Insert");
        }
        
        // Detect potential mouse mode toggle (both shifts pressed)
        if (app->left_shift_pressed && app->right_shift_pressed) {
            // Read actual state from LED after a brief moment
            SDL_Delay(50);  // Small delay for driver to update
            bool new_mode = read_mouse_mode_state(app->led_path);
            if (new_mode != app->mouse_mode) {
                app->mouse_mode = new_mode;
                snprintf(app->shifted_key_info, MAX_KEY_INFO_LEN, 
                        "Mouse mode toggled %s", app->mouse_mode ? "ON" : "OFF");
            }
        }
        
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
        
        // Track individual shift keys
        if (scancode == SDL_SCANCODE_LSHIFT) {
            app->left_shift_pressed = false;
        }
        if (scancode == SDL_SCANCODE_RSHIFT) {
            app->right_shift_pressed = false;
        }
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
    
    // Track last mouse mode check time
    Uint32 last_mouse_check = SDL_GetTicks();
    
    while (app.running) {
        handle_events(&app);
        
        // Periodically check mouse mode state from LED (every 100ms)
        Uint32 now = SDL_GetTicks();
        if (now - last_mouse_check > 100) {
            if (app.led_path[0] != '\0') {
                bool current_mode = read_mouse_mode_state(app.led_path);
                if (current_mode != app.mouse_mode) {
                    app.mouse_mode = current_mode;
                    // Don't overwrite shifted_key_info if it has recent content
                }
            }
            last_mouse_check = now;
        }
        
        render(&app);
        SDL_Delay(16); // ~60 FPS
    }
    
    printf("\nShutting down...\n");
    cleanup_app(&app);
    
    return 0;
}
