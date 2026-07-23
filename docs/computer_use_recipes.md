# Instruction Manual: GUI Automation & Vision-Based Computer Use

This reference manual provides practical instructions, scripts, and best practices for setting up and performing vision-based GUI automation and visual inspection (computer use) in XFCE/X11 and Wayland environments.

> [!TIP]
> **Quick Start Commands:**
> * **Python Virtualenv is available for computer use!** Activate it:
>   ```bash
>   source ~/.computer-use-venv/bin/activate
>   ```
> * **ydotool service is active!** Run it without sudo:
>   ```bash
>   export YDOTOOL_SOCKET=/tmp/.ydotool_socket && ydotool click 1
>   ```

---

## 1. System Requirements & Tooling Overview

An efficient AI agent or developer workstation requires a combination of display server control, keyboard/mouse input simulators, clipboard managers, and screenshot utilities.

| Utility | Description | Common Use Case |
| --- | --- | --- |
| **`xvfb`** | Virtual X11 framebuffer in memory | Runs GUI apps and web browsers headless |
| **`wmctrl`** | X11 Window Manager Controller | Queries window geometry and workspace properties |
| **`xdotool`** | X11 keyboard, mouse, and window simulation | Simulates human inputs and keyboard shortcut keys |
| **`ydotool`** | Wayland / uinput kernel-level input simulation | Performs inputs in Wayland desktops or raw consoles |
| **`xclip`** / **`xsel`** | Command-line X11 clipboard controllers | Synchronizes terminal clipboard with the active GUI |
| **`maim`** | Fast command-line screenshot tool | Captures root screens or target window client regions |
| **`scrot`** | Lightweight screenshot utility | Fast fallback for full-screen desktop captures |
| **`ffmpeg`** | Digital audio and video recorder | Screencasts automated user flows to video files |
| **`tesseract-ocr`** | Local optical character recognition engine | Extracts text from regions of interest (ROI) visually |

---

## 2. Python Virtual Environment Setup

To isolate computer use python scripts and prevent dependency pollution, a dedicated virtual environment is provisioned at `~/.computer-use-venv`.

### Activation
Activate the environment before executing any automation script:
```bash
source ~/.computer-use-venv/bin/activate
```

### Key Python Packages Pre-installed:
* **`mss`**: Ultra-fast screen capture library (fetches frames in <10ms without subprocess spawns).
* **`pyautogui`**: High-level cross-platform GUI automation library for mouse/keyboard inputs.
* **`pillow` (PIL)**: High-performance image processing library for crop/diff assertions.
* **`opencv-python-headless`**: Lightweight computer vision engine. Required to allow PyAutoGUI to support template search matching with confidence thresholds (`confidence=0.9`).

---

## 3. Practical Command Recipes

### Recipe 1: Precise Screen Capture
Use `maim` to capture full desktops or isolate a specific window using its X11 Window ID.

```bash
# Capture full virtual desktop
maim ~/screenshot.png

# Capture a specific window by its X11 Window ID
# (Get window ID using wmctrl or xdotool)
maim -i 0x026000f8 ~/window_screenshot.png

# Compress and downscale screenshot using ImageMagick
convert ~/screenshot.png -resize 1024x768 -quality 85 ~/compressed.jpg
```

---

### Recipe 2: Window Inspection & Geometry Queries
Use `wmctrl` to query mapped window coordinates, workspace layouts, and manipulate desktop boundaries.

```bash
# List all windows with workspace index and absolute boundaries
# Format: [Window ID] [Workspace] [X] [Y] [Width] [Height] [Host] [Title]
wmctrl -lG

# Focus a window and bring it to the foreground
wmctrl -a "Firefox"

# Resize and move a window
# Parameters format: gravity (usually 0), X, Y, Width, Height
# E.g., Move firefox to (50, 50) and resize to 1024x768
wmctrl -r "Firefox" -e 0,50,50,1024,768

# Maximize a window horizontally and vertically
wmctrl -r "Firefox" -b add,maximized_vert,maximized_horz
```

---

### Recipe 3: X11 Clipboard Synchronizer
Pass text selections directly between the active shell terminal and GUI applications.

```bash
# Copy terminal text into the clipboard
echo "Copied from Terminal" | xclip -selection clipboard

# Read contents from the clipboard
CLIP_TEXT=$(xclip -selection clipboard -o)
echo "Current clipboard: $CLIP_TEXT"
```

---

### Recipe 4: Python Visual Template Clicker
Execute high-speed visual matching and click on specific UI features. Save this script as `click_element.py` and run it via the virtual environment interpreter.

```python
import mss
import pyautogui
from PIL import Image
import sys

def find_and_click(template_path):
    """
    Captures screen in memory, locates template image, and simulates a click.
    """
    # 1. Capture screen quickly via mss
    with mss.mss() as sct:
        monitor = sct.monitors[1]
        sct_img = sct.grab(monitor)
        
        # Convert raw BGRA stream to PIL Image
        img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
        img.save("/tmp/current_screen.png")

    # 2. Search for the visual template using PyAutoGUI (requires opencv-python)
    try:
        match_region = pyautogui.locateOnScreen(template_path, confidence=0.9)
        if match_region:
            print(f"Found visual element at: {match_region}")
            # Calculate absolute center coordinates
            cx = match_region.left + match_region.width // 2
            cy = match_region.top + match_region.height // 2
            
            # Click the coordinates
            pyautogui.click(cx, cy)
            print("Successfully clicked element.")
            return True
        else:
            print("Element template not found on screen.")
            return False
    except Exception as e:
        print(f"Error during template matching: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python click_element.py <template_image_path>")
        sys.exit(1)
    find_and_click(sys.argv[1])
```

---

### Recipe 5: Automated Video Recording
Record automated test runs directly from the X11 display frame buffer using `ffmpeg`.

```bash
# Record virtual display :99 at 1280x1024, 15fps, output as mp4
ffmpeg -y -f x11grab -video_size 1280x1024 -i :99 -codec:v libx264 -r 15 ~/run_recording.mp4

# Record in the background for a fixed duration of 10 seconds
ffmpeg -y -f x11grab -video_size 1280x1024 -i :99 -codec:v libx264 -r 15 -t 10 ~/headless_test.mp4
```

---

## 4. Architectural Best Practices for AI Agents

When designing computer use automation routines, implement the following architectural rules to avoid instability and input failures:

1. **Avoid Window ID BadMatch Errors**:
   * Running `xdotool windowactivate <win_id>` on an invisible/unmapped desktop element (such as an `InputOnly` wrapper window) throws an X11 error.
   * **Rule**: Always parse the output of `wmctrl -lG` or filter query results with `xdotool search --onlyvisible` to ensure the window is active and fully mapped.
2. **Handle Port & Window Mapping Delays**:
   * UI components and network dev servers have startup latencies.
   * **Rule**: Implement retry loops when launching apps. Wait until either the network port is bound (`ss -tulpn`) or the window title appears in the list of client windows before sending keyboard or click streams.
3. **Handle Mouse Offsets**:
   * Coordinate queries on X11 refer to absolute display space. However, window structures might contain borders or title bars.
   * **Rule**: Use `wmctrl` to resolve absolute window positions, capture the window bounding box, and compute mouse inputs relative to the target window origin.
4. **Use Sub-Pixel Captures**:
   * Low-resolution screen captures lead to optical character recognition (OCR) and visual template matching mismatch errors.
   * **Rule**: Set display framebuffers to 24-bit depth (`Xvfb :99 -screen 0 1920x1080x24`) to preserve crisp anti-aliased sub-pixel details for vision processing.
