# CANDOS compatibility simulator

Run `npm install` once, then `npm test` to boot `boot/startup.lua` and
`boot/shell.py` against a simulated 50x50 monitor, filesystem, Basalt controls,
and touch events. The fixture uses the installed layout:

- `/disk2/boot/` contains the OS runtime and libraries, including Basalt.
- `/disk2/apps/<name>.app/` contains `main.app` and `icon.app`.
- `/disk2/files/` is the user's default working directory.

The test checks all 30 app packages and their icon metadata, discovery of
dynamically named drives, monitors, printers, and modems, compatibility with
older shell APIs, graphical `input()`/`io.read()`, bordered Basalt keyboard
controls, and pausing, resuming, and closing an app. It also verifies startup
reports a missing main monitor on `monitor_1` without writing to the computer
terminal.

The **Dispositivos** app lists peripherals as they connect and disconnect.
The **Red CANDOS** app searches only after the user enables discovery; PCs need
compatible CANDOS versions, a modem, and a manual pairing acceptance on both
ends. Pairing shares presence and role information only, not remote code or
screen control. **CANDOS FPS** is an original, touch-controlled first-person
maze shooter with its own map and characters; it does not include Doom assets.

This is a focused regression simulator, not a replacement for Minecraft or the
CC:Tweaked runtime. It uses Fengari's Lua 5.3 interpreter and mocks the CC APIs
used by this boot path. For testing against the actual 1.21.x runtime, use the
official [CC:Tweaked Standalone](https://github.com/cc-tweaked/CC-Tweaked/tree/mc-1.21.x/projects/standalone),
which requires a JDK 21 or newer.
