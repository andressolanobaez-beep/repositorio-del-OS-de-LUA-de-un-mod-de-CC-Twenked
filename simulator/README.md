# CANDOS compatibility simulator

Run `npm install` once, then `npm test` to boot the real `startup.lua` and
`shell.py` against a simulated 50x50 monitor, filesystem, and touch events.
The test checks app discovery, compatibility with older shell APIs, graphical
`input()`/`io.read()`, and pausing, resuming, and closing an app with the window
controls. It also verifies startup reports a missing main monitor on
`monitor_1` without writing to the computer terminal.

This is a focused regression simulator, not a replacement for Minecraft or the
CC:Tweaked runtime. It uses Fengari's Lua 5.3 interpreter and mocks the CC APIs
used by this boot path. For testing against the actual 1.21.x runtime, use the
official [CC:Tweaked Standalone](https://github.com/cc-tweaked/CC-Tweaked/tree/mc-1.21.x/projects/standalone),
which requires a JDK 21 or newer.
