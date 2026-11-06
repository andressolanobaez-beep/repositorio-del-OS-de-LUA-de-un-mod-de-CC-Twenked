# CANDOS compatibility simulator

Run `npm install` once, then `npm test` to boot the real `startup.lua` and
`shell.py` against a simulated 50x50 monitor, filesystem, and touch event.
The test checks app discovery from `disk2` and reproduces the older shell API
that caused `shell.load_imports` to be nil.

This is a focused regression simulator, not a replacement for Minecraft or the
CC:Tweaked runtime. It uses Fengari's Lua 5.3 interpreter and mocks the CC APIs
used by this boot path. For testing against the actual 1.21.x runtime, use the
official [CC:Tweaked Standalone](https://github.com/cc-tweaked/CC-Tweaked/tree/mc-1.21.x/projects/standalone),
which requires a JDK 21 or newer.
