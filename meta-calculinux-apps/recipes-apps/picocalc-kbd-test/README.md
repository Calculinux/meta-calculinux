# PicoCalc Keyboard Test Utility

Visual keyboard testing utility for the PicoCalc device with real-time feedback.

## Features

- **Visual Keyboard Display**: Shows a graphical representation of the PicoCalc keyboard layout
- **Real-time Key Feedback**: Keys light up when pressed
- **Key Information Panel**: Displays detailed information about pressed keys including:
  - Key name and keycode (hex)
  - Scancode name and number
  - Active modifier keys (Shift, Ctrl, Alt, GUI)
  - Number of simultaneously pressed keys
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
- **ESC + Q** or **Ctrl + Q**: Quit the application

## Technical Details

### Implementation

- Built with SDL2 and SDL2_ttf
- Uses SDL2 keyboard events for accurate key detection
- Displays both keycode and scancode information
- Shows modifier state (Shift, Ctrl, Alt combinations)
- Fullscreen rendering at 320x480 resolution

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
