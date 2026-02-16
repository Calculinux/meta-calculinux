# PicoCalc Keyboard Test Utility

Visual keyboard testing utility for the PicoCalc device with real-time feedback.

## Features

- **Visual Keyboard Display**: Shows a graphical representation of the PicoCalc keyboard layout
- **Real-time Key Feedback**: Keys light up when pressed
- **Key Information Panel**: Displays detailed information about pressed keys including:
  - Key name and keycode (hex)
  - Scancode name and number
  - Active modifier keys (Shift, Ctrl, Alt, GUI)
  - Individual left/right shift key tracking
  - Number of simultaneously pressed keys
  - Shifted key interpretations (e.g., F1+Shift → F6)
- **Mouse Mode Detection**: Real-time monitoring of mouse mode state via sysfs
  - **Reads from** `/sys/bus/platform/devices/picocalc-mfd-kbd/mouse_mode`
  - **Reads actual state** from driver (not just tracking key presses)
  - **Updates every 100ms** to stay synchronized with driver state
  - **Mouse mode is a toggle** - locks on/off, not just active while shifts are held
  - When active, the driver outputs different events (REL_X/REL_Y instead of arrow keys)
  - **Uses SW_TABLET_MODE** switch event for semantic correctness (not LED)
  - **Userspace can control mouse mode** via sysfs:
    ```bash
    # Enable mouse mode
    echo 1 > /sys/bus/platform/devices/picocalc-mfd-kbd/mouse_mode
    # Disable mouse mode
    echo 0 > /sys/bus/platform/devices/picocalc-mfd-kbd/mouse_mode
    ```
  - Test utility will automatically detect and display external state changes
- **Special Key Combinations**:
  - **Shifted Function Keys**: F1-F5 + Shift → F6-F10
  - **Shifted Numbers**: 1-0 + Shift → ! @ # $ % ^ & * ( )
  - **Shifted Symbols**: All symbol keys show their shifted equivalents
  - **Alt+I**: Insert key functionality
  - **Shift + Arrow Keys**: PageUp/PageDown/Insert
- **Accurate Layout**: Based on the actual PicoCalc hardware layout including:
  - D-pad navigation
  - Function keys (F1-F5)
  - Full QWERTY keyboard
  - Number row with letter labels
  - Special keys and modifiers

## Usage

Run the utility on your PicoCalc:

```bash
picocalc-kbd-test
```

The application will launch in fullscreen mode and display:
- A visual representation of the keyboard at the top
- An information panel at the bottom showing key details

### Controls

- Press any key to see it highlighted and display its information
- Press multiple keys simultaneously to test key combinations
- **Shift + Key**: See the shifted interpretation (e.g., F1 becomes F6, 1 becomes !)
- **Alt + I**: Test Insert key functionality
- **Both Shift Keys**: Enter mouse mode (shows [MOUSE] indicator)
  - Arrow keys: Mouse movement
  - Enter: Left click
  - Space: Right click
- **ESC + Q** or **Ctrl + Q**: Quit the application

### Special Key Testing

The utility helps test these special keyboard behaviors:

1. **Shifted Function Keys**
   - F1 + Shift → F6
   - F2 + Shift → F7
   - F3 + Shift → F8
   - F4 + Shift → F9
   - F5 + Shift → F10

2. **Shifted Navigation**
   - Up + Shift → PageUp
   - Down + Shift → PageDown
   - Enter + Shift → Insert

3. **Mouse Mode** (Both shifts pressed)
   - **Toggle behavior**: Press both shifts simultaneously to turn mouse mode ON/OFF
   - When ON, driver outputs mouse events instead of key events:
     - Arrow keys → Mouse movement (REL_X/REL_Y events)
     - Enter → Left click (BTN_LEFT)
     - Space → Right click (BTN_RIGHT)
   - Press both shifts again to exit mouse mode
   - Driver maintains state via LED_MISC indicator

4. **Alt Combinations**
   - Alt + I → Insert

## Technical Details

### Implementation

- Built with SDL2 and SDL2_ttf
- Uses SDL2 keyboard events for accurate key detection
- **Reads mouse mode state from driver** via `/sys/class/leds/input*::misc/brightness`
- **Automatic LED detection** on startup
- **Real-time synchronization** with driver state (polls every 100ms)
- Displays both keycode and scancode information
- Shows modifier state (Shift, Ctrl, Alt combinations)
- Fullscreen rendering at 320x480 resolution

### Mouse Mode Integration

The test utility integrates with the keyboard driver's mouse mode:

1. **Startup**: Looks for `/sys/bus/platform/devices/picocalc-mfd-kbd/mouse_mode`
2. **Initial State**: Reads current mouse mode state from driver
3. **Runtime Monitoring**: Polls sysfs every 100ms to detect external changes
4. **Toggle Detection**: When both shifts are pressed, verifies state change via sysfs
5. **Visual Feedback**: Shows `[MOUSE]` indicator in modifier display when active

This ensures the display is always accurate, even if:
- Mouse mode was enabled before the test utility started
- Another program toggles mouse mode via sysfs
- The driver state changes for any reason

The driver uses **SW_TABLET_MODE** (switch event) which is semantically appropriate for an input mode change, rather than LED which is meant for physical indicators.

### Key Layout

The keyboard layout matches the actual PicoCalc hardware:

1. **D-Pad Section** (top left)
   - Arrow keys for navigation

2. **Function Row**
   - F1-F5 function keys
   - Special keys: Esc, Tab, CapsLock, Del, Backspace

3. **Symbol Row**
   - Backslash, forward slash, backtick, minus, equals, brackets

4. **Number Row**
   - 0-9 keys with corresponding letter labels

5. **QWERTY Rows**
   - Standard QWERTY layout (Q-P, A-L, Z-M rows)

6. **Bottom Row**
   - Shift, Ctrl, Alt modifiers
   - Spacebar
   - Special punctuation keys

### Color Coding

- **Dark Gray**: Normal alphanumeric keys
- **Blue**: Special keys (modifiers, function keys)
- **Green**: Pressed keys (both types)
- **Light Blue**: Information panel background

## Building

The recipe is located at:
```
meta-calculinux-apps/recipes-apps/picocalc-kbd-test/
```

Build with:
```bash
bitbake picocalc-kbd-test
```

Or rebuild the full apps packagegroup:
```bash
bitbake packagegroup-meta-calculinux-apps
```

## Troubleshooting

### No Visual Output

If you don't see the keyboard display:
1. Ensure SDL2 is properly configured for the DRM display
2. Check that the display driver is loaded
3. Verify font packages are installed

### Keys Not Detected

If key presses aren't registering:
1. Check that the keyboard driver is loaded: `lsmod | grep picocalc_kbd`
2. Verify input events: `evtest` to see if raw events are coming through
3. Ensure SDL keyboard grabbing is working

### Font Display Issues

If text doesn't appear:
- The utility will work without fonts but won't show labels
- Install DejaVu fonts: `opkg install ttf-dejavu-sans`

## Development

The source code is in:
```
meta-calculinux-apps/recipes-apps/picocalc-kbd-test/files/picocalc-kbd-test.c
```

To modify the keyboard layout, edit the `keyboard_layout[]` array in the source file. Each key is defined by:
- Position (x, y)
- Size (w, h)
- SDL_Keycode
- Display label
- Type (special or normal)

## License

MIT License - See LICENSE file for details
