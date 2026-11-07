-- CANDOS desktop runtime. Network peripherals are discovered by their
-- peripheral names so no device depends on a fixed computer side.

local monitor, monitor_side
local display_preference_file = fs.exists("/disk2/boot/shell.py")
    and "/disk2/.candOS/display.txt"
    or fs.exists("/disk2/shell.py")
    and "/disk2/.candOS/display.txt" or "/.candOS/display.txt"

local function read_display_preference()
    if not fs.exists(display_preference_file) then
        return nil
    end
    local file = fs.open(display_preference_file, "r")
    if not file then
        return nil
    end
    local name = file.readAll():gsub("^%s*(.-)%s*$", "%1")
    file.close()
    return name ~= "" and name or nil
end

local function find_main_monitor()
    local preferred = read_display_preference()
    if preferred and preferred ~= "monitor_1"
        and peripheral.getType(preferred) == "monitor" then
        return peripheral.wrap(preferred), preferred
    end
    if type(peripheral.getNames) == "function" then
        for _, name in ipairs(peripheral.getNames()) do
            if name ~= "monitor_1" and peripheral.getType(name) == "monitor" then
                return peripheral.wrap(name), name
            end
        end
    else
        local fallback, name = peripheral.find("monitor")
        if fallback and name ~= "monitor_1" then
            return fallback, name
        end
    end
end

monitor, monitor_side = find_main_monitor()

if not monitor then
    local error_monitor
    if peripheral.getType("monitor_1") == "monitor" then
        error_monitor = peripheral.wrap("monitor_1")
    else
        error_monitor = peripheral.find("monitor")
    end
    if error_monitor then
        error_monitor.setTextScale(0.5)
        error_monitor.setBackgroundColor(colors.black)
        error_monitor.setTextColor(colors.white)
        error_monitor.clear()
        error_monitor.setCursorPos(1, 1)
        error_monitor.write("CANDOS: falta monitor principal.")
        error_monitor.setCursorPos(1, 2)
        error_monitor.write("Conecta un monitor por cable de red.")
    end
    return
end

local speaker
if type(peripheral.getNames) == "function" then
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "speaker" then
            speaker = peripheral.wrap(name)
            break
        end
    end
else
    speaker = peripheral.find("speaker")
end

local screen_width, screen_height

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()
monitor.setCursorPos(1, 1)
screen_width, screen_height = monitor.getSize()
term.redirect(monitor)

local function refresh_main_monitor()
    local next_monitor, next_side = find_main_monitor()
    if next_monitor ~= monitor or next_side ~= monitor_side then
        monitor, monitor_side = next_monitor, next_side
        if monitor then
            monitor.setTextScale(0.5)
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.white)
            screen_width, screen_height = monitor.getSize()
            term.redirect(monitor)
        end
        candOS.monitor = monitor
        candOS.monitor_side = monitor_side
    elseif monitor then
        screen_width, screen_height = monitor.getSize()
    end
    return monitor ~= nil
end

local function move_to_next_line(output_term, width, height)
    local _, y = output_term.getCursorPos()
    if y >= height then
        output_term.scroll(1)
        output_term.setCursorPos(1, height)
    else
        output_term.setCursorPos(1, y + 1)
    end
end

local function write_wrapped(text, add_newline)
    local output_term = term.current()
    if not output_term then
        return
    end

    local width, height = output_term.getSize()
    local function write_line(line)
        local words = {}
        for word in line:gmatch("%S+") do
            words[#words + 1] = word
        end
        for index, word in ipairs(words) do
            local x, y = output_term.getCursorPos()
            if y > height then
                output_term.scroll(y - height)
                output_term.setCursorPos(x, height)
                x = select(1, output_term.getCursorPos())
            end

            if x > 1 and x + #word - 1 > width then
                move_to_next_line(output_term, width, height)
                x = 1
            end
            output_term.write(word)

            local next_word = words[index + 1]
            if next_word then
                x = select(1, output_term.getCursorPos())
                if x + #next_word > width then
                    move_to_next_line(output_term, width, height)
                else
                    output_term.write(" ")
                end
            end
        end
    end

    text = tostring(text or ""):gsub("\r", "")
    local start = 1
    while true do
        local newline = text:find("\n", start, true)
        write_line(newline and text:sub(start, newline - 1) or text:sub(start))
        if not newline then
            break
        end
        move_to_next_line(output_term, width, height)
        start = newline + 1
    end

    if add_newline then
        move_to_next_line(output_term, width, height)
    end
end

_G.print = function(...)
    local values = {}
    for index = 1, select("#", ...) do
        values[index] = tostring(select(index, ...))
    end
    write_wrapped(table.concat(values, " "), true)
end

_G.write = function(value)
    write_wrapped(tostring(value or ""), false)
end

local shell_path
for _, candidate in ipairs({
    "/disk2/boot/shell.py",
    "/disk2/shell.py"
}) do
    if fs.exists(candidate) then
        shell_path = candidate
        break
    end
end
if not shell_path and type(peripheral.getNames) == "function" then
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "drive" then
            local drive = peripheral.wrap(name)
            local mount = drive and type(drive.getMountPath) == "function"
                and drive.getMountPath()
            local candidate = mount and fs.combine(mount, "boot/shell.py")
            if candidate and fs.exists(candidate) then
                shell_path = candidate
                break
            end
        end
    end
end
shell_path = shell_path or "shell.py"
local shell_chunk, shell_load_error = loadfile(shell_path)
if not shell_chunk then
    error("No se pudo cargar " .. shell_path .. ": " .. tostring(shell_load_error))
end
local shell_ok, shell_api = pcall(shell_chunk)
if not shell_ok then
    error("No se pudo iniciar shell.py: " .. tostring(shell_api))
end
_G.shell = shell_api
_G.candOS = {
    monitor = monitor,
    monitor_side = monitor_side,
    speaker = speaker
}
if type(shell.load_imports) == "function" then
    shell.load_imports()
else
    print("Aviso: shell.py no admite la carga de drivers; actualiza CANDOS.")
end

local function load_basalt_source()
    local roots = {"disk", "disk2", "disk3", "disk4"}
    local parts = {}
    local missing_path
    for index, root in ipairs(roots) do
        local path = fs.combine(root, "boot/lib/basalt/part" .. index .. ".lua")
        local file, open_error = fs.open(path, "r")
        if not file then
            missing_path = path .. ": " .. tostring(open_error)
            parts = {}
            break
        end
        parts[index] = file.readAll()
        file.close()
    end
    if #parts == #roots then
        return table.concat(parts), "Basalt dividido entre los cuatro disquetes"
    end

    local legacy_path = "/disk2/boot/lib/basalt.lua"
    local legacy_file = fs.open(legacy_path, "r")
    if legacy_file then
        local source = legacy_file.readAll()
        legacy_file.close()
        return source, legacy_path
    end
    return nil, nil, "Falta " .. tostring(missing_path or
        "Basalt en /disk2/boot/lib/basalt.lua")
end

local basalt_source, basalt_path, basalt_open_error = load_basalt_source()
if not basalt_source then
    error("No se pudo cargar Basalt: " .. tostring(basalt_open_error))
end
local basalt_chunk, basalt_compile_error = load(basalt_source,
    "@" .. basalt_path, "t", _ENV)
if not basalt_chunk then
    error("Basalt contiene un error de sintaxis: " .. tostring(basalt_compile_error))
end
local basalt_ok, basalt_api = pcall(basalt_chunk)
if not basalt_ok then
    error("No se pudo iniciar Basalt: " .. tostring(basalt_api))
end
if type(basalt_api) ~= "table" or type(basalt_api.createFrame) ~= "function"
    or type(basalt_api.update) ~= "function" then
    error("Basalt no expuso createFrame() y update() como requiere CANDOS.")
end
_G.candOS.basalt = basalt_api

local function collect_apps()
    if type(shell.list_apps) == "function" then
        return shell.list_apps()
    end

    local apps = {}
    local function scan(directory, depth)
        if depth > 10 or not fs.exists(directory) or not fs.isDir(directory) then
            return
        end
        for _, name in ipairs(fs.list(directory)) do
            local path = fs.combine(directory, name)
            if fs.isDir(path) then
                if name:lower():match("%.app$")
                    and fs.exists(fs.combine(path, "main.app")) then
                    apps[#apps + 1] = {
                        name = name,
                        path = path,
                        main_path = fs.combine(path, "main.app"),
                        side = "CANDOS",
                        relative_path = path,
                        icon = "APP",
                        icon_color = "blue"
                    }
                else
                    scan(path, depth + 1)
                end
            elseif name:lower():match("%.app$") then
                apps[#apps + 1] = {
                    name = name,
                    path = path,
                    main_path = path,
                    side = "CANDOS",
                    relative_path = path
                }
            end
        end
    end

    scan("/disk2/apps", 0)
    table.sort(apps, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return apps
end

local function screen_write(x, y, text, foreground, background, max_width)
    if y < 1 or y > screen_height or x > screen_width then
        return
    end
    text = tostring(text)
    local available = math.min(max_width or screen_width, screen_width - x + 1)
    if available <= 0 then
        return
    end
    if #text > available then
        text = text:sub(1, available)
        local last_space = text:match(".*()%s")
        if last_space then
            text = text:sub(1, last_space - 1)
        end
    end
    monitor.setCursorPos(x, y)
    monitor.setTextColor(foreground or colors.white)
    monitor.setBackgroundColor(background or colors.black)
    monitor.write(text .. string.rep(" ", available - #text))
end

local native_read = _G.read
local native_input = _G.input
local native_io_read = type(_G.io) == "table" and _G.io.read or nil
local native_pull_event = os.pullEvent
local native_pull_event_raw = os.pullEventRaw or os.pullEvent
local original_pull_event_raw = os.pullEventRaw
local active_app_thread
local unpack_values = table.unpack or unpack

local function pack_values(...)
    return {n = select("#", ...), ...}
end

local function update_basalt(event)
    if candOS.basalt and event and event.n > 0 then
        candOS.basalt.update(unpack_values(event, 1, event.n))
    end
end

local function app_is_reading()
    return active_app_thread ~= nil and coroutine.running() == active_app_thread
end

local function graphical_input(prompt, default, numeric_only)
    if app_is_reading() then
        return coroutine.yield({
            candOS = true,
            kind = "input",
            prompt = tostring(prompt or ""),
            default = tostring(default or ""),
            numeric = numeric_only == true
        })
    end
    if type(native_read) == "function" then
        return native_read()
    end
    return ""
end

_G.read = function(replace_char, history, completion, default)
    if app_is_reading() then
        return graphical_input(nil, default)
    end
    if type(native_read) == "function" then
        return native_read(replace_char, history, completion, default)
    end
    return ""
end

_G.input = function(prompt, default, mode)
    if app_is_reading() then
        local numeric_only = mode == "number" or mode == "numeric"
        return graphical_input(prompt, default, numeric_only)
    end
    if type(native_input) == "function" then
        return native_input(prompt, default, mode)
    end
    return graphical_input(prompt, default)
end

_G.io = _G.io or {}
_G.io.read = function(...)
    if not app_is_reading() then
        if type(native_io_read) == "function" then
            return native_io_read(...)
        end
        return _G.read(...)
    end

    local formats = pack_values(...)
    if formats.n == 0 then
        return graphical_input()
    end

    local results = {n = formats.n}
    for index = 1, formats.n do
        local format = formats[index]
        if format == nil or format == "*l" or format == "*L" or format == "*a" then
            results[index] = graphical_input()
            if format == "*L" and results[index] then
                results[index] = results[index] .. "\n"
            end
        elseif format == "*n" then
            results[index] = tonumber(graphical_input(nil, nil, true))
        else
            error("Formato io.read no compatible con el input grafico: " ..
                tostring(format), 2)
        end
    end
    return unpack_values(results, 1, results.n)
end

local function wait_for_app_event(filter, raw)
    if app_is_reading() then
        local event = pack_values(coroutine.yield({
            candOS = true,
            kind = "event",
            filter = filter,
            raw = raw
        }))
        if event[1] == "terminate" and not raw then
            error("Terminated", 0)
        end
        return unpack_values(event, 1, event.n)
    end
    local pull = raw and native_pull_event_raw or native_pull_event
    return pull(filter)
end

os.pullEvent = function(filter)
    return wait_for_app_event(filter, false)
end
os.pullEventRaw = function(filter)
    return wait_for_app_event(filter, true)
end

local function button(x, y, width, label, background)
    local text
    if width >= 3 then
        text = ("[" .. tostring(label) .. "]"):sub(1, width)
    else
        text = tostring(label):sub(1, width)
    end
    screen_write(x, y, text, colors.white, background or colors.blue, width)
end

local graphics = {}

function graphics.getSize()
    return screen_width, screen_height
end

function graphics.clear(background)
    if not monitor then
        return
    end
    monitor.setBackgroundColor(background or colors.black)
    monitor.clear()
end

function graphics.text(x, y, text, foreground, background, width)
    screen_write(x, y, text, foreground, background, width)
end

function graphics.label(x, y, text, foreground, background, width)
    screen_write(x, y, text, foreground, background, width)
end

function graphics.fillRect(x, y, width, height, background)
    if not monitor or width < 1 or height < 1 then
        return
    end
    for row = y, y + height - 1 do
        screen_write(x, row, "", colors.white, background, width)
    end
end

function graphics.rect(x, y, width, height, foreground, background)
    if width < 2 or height < 2 then
        return
    end
    screen_write(x, y, "+" .. string.rep("-", width - 2) .. "+",
        foreground, background, width)
    for row = y + 1, y + height - 2 do
        screen_write(x, row, "|" .. string.rep(" ", width - 2) .. "|",
            foreground, background, width)
    end
    screen_write(x, y + height - 1, "+" .. string.rep("-", width - 2) .. "+",
        foreground, background, width)
end

function graphics.panel(x, y, width, height, title, foreground, background)
    graphics.fillRect(x, y, width, height, background or colors.gray)
    graphics.rect(x, y, width, height, foreground or colors.white,
        background or colors.gray)
    if title and width > 4 then
        screen_write(x + 2, y, " " .. tostring(title) .. " ",
            foreground or colors.white, background or colors.blue, width - 4)
    end
end

function graphics.textArea(x, y, width, height, content, first_line, foreground, background)
    if width < 3 or height < 3 then
        return 0
    end
    graphics.fillRect(x, y, width, height, background or colors.black)
    graphics.rect(x, y, width, height, foreground or colors.white,
        background or colors.black)
    local lines = {}
    if type(content) == "table" then
        lines = content
    else
        for line in (tostring(content or "") .. "\n"):gmatch("(.-)\n") do
            lines[#lines + 1] = line
        end
    end
    local visible = height - 2
    local start = math.max(1, tonumber(first_line) or 1)
    for row = 1, visible do
        local line = lines[start + row - 1]
        if line then
            screen_write(x + 1, y + row, line, foreground or colors.white,
                background or colors.black, width - 2)
        end
    end
    return #lines, visible
end

function graphics.button(x, y, width, label, background)
    button(x, y, width, label, background)
end

function graphics.switch(x, y, label, enabled, width)
    local value = enabled and "[ ON ]" or "[ OFF ]"
    local state_color = enabled and colors.green or colors.gray
    local text = tostring(label or "") .. " " .. value
    screen_write(x, y, text, colors.white, state_color, width)
end

function graphics.centerText(y, text, foreground, background)
    text = tostring(text or "")
    local x = math.max(1, math.floor((screen_width - #text) / 2) + 1)
    screen_write(x, y, text, foreground, background)
end

function graphics.progressBar(x, y, width, progress, foreground, background)
    if width < 1 then
        return
    end
    progress = math.max(0, math.min(1, tonumber(progress) or 0))
    local filled = math.floor(width * progress)
    screen_write(x, y, string.rep(" ", filled), colors.white,
        foreground or colors.green, filled)
    screen_write(x + filled, y, string.rep(" ", width - filled), colors.white,
        background or colors.gray, width - filled)
end

_G.candOS.graphics = graphics
_G.candOS.input = _G.input

local function draw_window_controls(app)
    if not monitor then
        return
    end
    local close_x = math.max(1, screen_width - 5)
    local minimize_x = math.max(1, screen_width - 2)
    screen_write(1, 1, " " .. app.name:gsub("%.app$", ""), colors.white, colors.blue,
        math.max(1, close_x - 2))
    button(close_x, 1, 3, "X", colors.red)
    button(minimize_x, 1, 3, "-", colors.gray)
end

local function handle_window_control(event, task)
    if event[1] ~= "monitor_touch"
        or (event[2] ~= monitor_side and event[2] ~= task.touch_side)
        or event[4] ~= 1 then
        return nil
    end
    local close_x = math.max(1, screen_width - 5)
    local minimize_x = math.max(1, screen_width - 2)
    if event[3] >= close_x and event[3] < close_x + 3 then
        return "close"
    elseif event[3] >= minimize_x then
        return "minimize"
    end
    return nil
end

local function keyboard_rows(symbols, numeric)
    if numeric then
        return {
            {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
            {"-", ".", "DEL"},
            {"<-", "/\\", "\\/", "->", "HOME", "END"},
            {"CLEAR", "SPACE", "ENTER"}
        }
    end
    if symbols then
        return {
            {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
            {"!", "@", "#", "$", "%", "^", "&", "*", "(", ")"},
            {"SHIFT", "-", "_", "=", "+", "/", "\\", ".", ",", "DEL"},
            {"<-", "/\\", "\\/", "->", "HOME", "END"},
            {"ABC", "SPACE", "ENTER"}
        }
    end
    return {
        {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p"},
        {"a", "s", "d", "f", "g", "h", "j", "k", "l"},
        {"SHIFT", "z", "x", "c", "v", "b", "n", "m", "DEL"},
        {"<-", "/\\", "\\/", "->", "HOME", "END"},
        {"#@/", "SPACE", "ENTER"}
    }
end

local function input_display_text(state, width)
    local display = state.value
    local visible_width = math.max(1, width - 2)
    local start = math.max(1, math.min(state.cursor - visible_width + 1, #display + 1))
    display = display:sub(start, start + visible_width - 1)
    local caret = state.cursor - start + 1
    local before = display:sub(1, caret - 1)
    local after = display:sub(caret)
    return (before .. "|" .. after):sub(1, visible_width)
end

local function input_button(frame, x, y, width, height, label, background, callback)
    local control = frame:addButton()
    control:setPosition(x, y)
    control:setSize(width, height)
    control:setText(label)
    control:setForeground(colors.white)
    control:setBackground(background)
    control:setBorder(colors.lightBlue, "top", "bottom", "left", "right")
    control:onClick(function()
        callback()
    end)
    return control
end

local function remove_input_frame(task)
    local state = task.input_state
    if state and state.frame_name then
        candOS.basalt.removeFrame(state.frame_name)
        state.frame_name = nil
        state.value_control = nil
    end
end

local function insert_at_cursor(state, text)
    state.value = state.value:sub(1, state.cursor - 1) .. text ..
        state.value:sub(state.cursor)
    state.cursor = state.cursor + #text
end

local function apply_keyboard_key(state, key)
    if key == "ENTER" then
        state.action = "submit"
    elseif key == "CLEAR" then
        state.value = ""
        state.cursor = 1
    elseif key == "SPACE" then
        insert_at_cursor(state, " ")
    elseif key == "DEL" then
        if state.cursor > 1 then
            state.value = state.value:sub(1, state.cursor - 2) ..
                state.value:sub(state.cursor)
            state.cursor = state.cursor - 1
        end
    elseif key == "SHIFT" then
        state.shift = not state.shift
    elseif key == "#@/" or key == "ABC" then
        state.symbols = not state.symbols
    elseif key == "<-" then
        state.cursor = math.max(1, state.cursor - 1)
    elseif key == "->" then
        state.cursor = math.min(#state.value + 1, state.cursor + 1)
    elseif key == "HOME" or key == "/\\" then
        state.cursor = 1
    elseif key == "END" or key == "\\/" then
        state.cursor = #state.value + 1
    elseif key and #key == 1 then
        insert_at_cursor(state, state.shift and key:upper() or key)
        state.shift = false
    end
end

local function draw_input(task)
    local request = task.pending
    local state = task.input_state
    if state.frame_name then
        if state.value_control then
            state.value_control:setText(input_display_text(state, screen_width - 4))
        end
        return
    end

    local rows = keyboard_rows(state.symbols, state.numeric)
    if state.shift then
        for _, row in ipairs(rows) do
            for index, key in ipairs(row) do
                if key:match("^[a-z]$") then
                    row[index] = key:upper()
                end
            end
        end
    end
    local key_height = math.max(1, math.min(3,
        math.floor(math.max(1, screen_height - 5) / #rows)))
    local keyboard_top = screen_height - #rows * key_height + 1
    local frame_name = "candOS_input_" ..
        tostring(task.app.path):gsub("[^%w_]", "_") .. "_" .. tostring(os.clock())
    local frame = candOS.basalt.createFrame(frame_name)
    frame:setBackground(colors.black)
    state.frame_name = frame_name

    local title = frame:addLabel()
    title:setPosition(1, 1)
    title:setSize(math.max(1, screen_width - 6), 1)
    title:setText(" " .. task.app.name:gsub("%.app$", ""))
    title:setForeground(colors.white)
    title:setBackground(colors.blue)
    input_button(frame, math.max(1, screen_width - 5), 1, 3, 1,
        "X", colors.red, function()
            state.action = "close"
        end)
    input_button(frame, math.max(1, screen_width - 2), 1, 3, 1,
        "-", colors.gray, function()
            state.action = "minimize"
        end)

    local prompt = frame:addLabel()
    prompt:setPosition(2, 2)
    prompt:setSize(math.max(1, screen_width - 2), 1)
    prompt:setText(request.prompt ~= "" and request.prompt or "Escribe y pulsa ENTER")
    prompt:setForeground(colors.white)
    prompt:setBackground(colors.gray)

    local value = frame:addLabel()
    value:setPosition(2, 3)
    value:setSize(math.max(1, screen_width - 4), 3)
    value:setText(input_display_text(state, screen_width - 4))
    value:setForeground(colors.black)
    value:setBackground(colors.white)
    value:setBorder(colors.cyan, "top", "bottom", "left", "right")
    state.value_control = value

    for row_index, keys in ipairs(rows) do
        local y = keyboard_top + (row_index - 1) * key_height
        for key_index, key in ipairs(keys) do
            local x = math.floor((key_index - 1) * screen_width / #keys) + 1
            local next_x = math.floor(key_index * screen_width / #keys) + 1
            local width = math.max(1, next_x - x - 1)
            local label = key == "SPACE" and "ESPACIO"
                or key == "SHIFT" and "SHIFT"
                or key == "/\\" and "ARRIBA"
                or key == "\\/" and "ABAJO"
                or key
            local color = colors.blue
            if key == "ENTER" then
                color = colors.green
            elseif key == "DEL" or key == "SHIFT" or key == "CLEAR" then
                color = colors.gray
            elseif key == "SPACE" then
                label = "ESPACIO"
                color = colors.lightBlue
            elseif key == "#@/" or key == "ABC" then
                color = colors.orange
            end
            input_button(frame, x, y, width, key_height, label, color, function()
                local shifted = state.shift
                apply_keyboard_key(state, key)
                if key == "#@/" or key == "ABC" or key == "SHIFT"
                    or shifted and #key == 1 then
                    remove_input_frame(task)
                elseif state.value_control then
                    state.value_control:setText(
                        input_display_text(state, screen_width - 4))
                end
            end)
        end
    end
end

local function matches_filter(request, event)
    return request.filter == nil or request.filter == event[1]
end

local tasks = {}

local function remove_task(task)
    for index, existing in ipairs(tasks) do
        if existing == task then
            table.remove(tasks, index)
            return
        end
    end
end

local function find_task(app)
    for _, task in ipairs(tasks) do
        if task.app.path == app.path then
            return task
        end
    end
end

_G.candOS.getTasks = function()
    local snapshot = {}
    for _, task in ipairs(tasks) do
        snapshot[#snapshot + 1] = {
            name = task.app.name,
            path = task.app.path,
            status = task.status
        }
    end
    return snapshot
end

_G.candOS.getMonitors = function()
    local monitors = {}
    local names = type(peripheral.getNames) == "function"
        and peripheral.getNames() or {}
    for _, name in ipairs(names) do
        if peripheral.getType(name) == "monitor" then
            local device = peripheral.wrap(name)
            local monitor_width, monitor_height = device.getSize()
            monitors[#monitors + 1] = {
                name = name,
                width = monitor_width,
                height = monitor_height,
                primary = name == monitor_side
            }
        end
    end
    return monitors
end

local function launch_app_thread(app)
    local thread = coroutine.create(function()
        if type(shell.start) == "function" then
            local ok, runtime_error = shell.start(app.path, {})
            if not ok then
                error(runtime_error or "La aplicacion no pudo iniciarse", 0)
            end
            return
        end
        local program_path = app.main_path or app.path
        local file, open_error = fs.open(program_path, "r")
        if not file then
            error("No se pudo abrir " .. program_path .. ": " ..
                tostring(open_error), 0)
        end
        local source = file.readAll()
        file.close()
        local program, syntax_error = load(source, "@" .. program_path, "t", _ENV)
        if not program then
            error("Error de sintaxis en " .. app.path .. ": " .. tostring(syntax_error), 0)
        end
        program()
    end)
    return {
        app = app,
        thread = thread,
        touch_side = monitor_side,
        pending = nil,
        input_state = nil,
        status = "active"
    }
end

local function resume_task(task, ...)
    local resume_args = pack_values(...)
    task.status = "active"
    while task.status == "active" do
        local request = task.pending
        if not request then
            active_app_thread = task.thread
            local result = pack_values(coroutine.resume(task.thread,
                unpack_values(resume_args, 1, resume_args.n)))
            active_app_thread = nil
            if not result[1] then
                remove_task(task)
                return false, tostring(result[2])
            end
            if coroutine.status(task.thread) == "dead" then
                remove_task(task)
                return true, task.app.name .. " termino."
            end

            request = result[2]
            if type(request) ~= "table" or request.candOS ~= true then
                remove_task(task)
                return false, "La aplicacion cedio el control con un yield no compatible."
            end
            task.pending = request
        end

        if request.kind == "input" then
            task.input_state = task.input_state or {
                value = request.default,
                cursor = #request.default + 1,
                symbols = false,
                shift = false,
                numeric = request.numeric
            }
            while task.status == "active" do
                if monitor then
                    draw_input(task)
                end
                local event = pack_values(native_pull_event_raw())
                if event[1] == "peripheral" or event[1] == "peripheral_detach"
                    or event[1] == "monitor_resize" then
                    refresh_main_monitor()
                    remove_input_frame(task)
                elseif event[1] == "monitor_touch" and event[2] == monitor_side then
                    event[2] = task.touch_side or monitor_side
                end
                update_basalt(event)
                local state = task.input_state
                local action = state.action
                state.action = nil
                if action == "close" then
                    remove_input_frame(task)
                    remove_task(task)
                    return true, task.app.name .. " cerrada."
                elseif action == "minimize" then
                    remove_input_frame(task)
                    task.status = "minimized"
                    return true, task.app.name ..
                        " pausada; toca su boton inferior para reanudar."
                elseif action == "submit" then
                    remove_input_frame(task)
                    local value = task.input_state.value
                    task.pending = nil
                    task.input_state = nil
                    resume_args = pack_values(value)
                    break
                end
            end
        elseif request.kind == "event" then
            while task.status == "active" do
                if monitor then
                    draw_window_controls(task.app)
                end
                local event = pack_values(native_pull_event_raw())
                if event[1] == "peripheral" or event[1] == "peripheral_detach"
                    or event[1] == "monitor_resize" then
                    refresh_main_monitor()
                elseif event[1] == "monitor_touch" and event[2] == monitor_side then
                    event[2] = task.touch_side or monitor_side
                end
                update_basalt(event)
                local action = handle_window_control(event, task)
                if action == "close" then
                    remove_task(task)
                    return true, task.app.name .. " cerrada."
                elseif action == "minimize" then
                    task.status = "minimized"
                    return true, task.app.name ..
                        " pausada; toca su boton inferior para reanudar."
                elseif matches_filter(request, event) then
                    task.pending = nil
                    resume_args = event
                    break
                end
            end
        else
            remove_task(task)
            return false, "Solicitud de app desconocida: " .. tostring(request.kind)
        end
    end
    return true, task.app.name .. " pausada."
end

local function draw_taskbar()
    local paused = {}
    for _, task in ipairs(tasks) do
        if task.status == "minimized" then
            paused[#paused + 1] = task
        end
    end
    local y = screen_height - 3
    local positions = {}
    if #paused == 0 or y < 1 then
        return positions
    end
    for index, task in ipairs(paused) do
        local x = math.floor((index - 1) * screen_width / #paused) + 1
        local next_x = math.floor(index * screen_width / #paused) + 1
        local cell_width = math.max(1, next_x - x)
        screen_write(x, y, " " .. task.app.name:gsub("%.app$", ""),
            colors.white, colors.gray, cell_width)
        positions[index] = {x = x, width = cell_width, task = task}
    end
    return positions
end

local function layout()
    local columns = math.max(1, math.min(4, math.floor((screen_width - 2) / 14)))
    local rows = math.max(1, math.floor((screen_height - 10) / 6))
    local card_width = math.max(1, math.floor((screen_width - (columns + 1) * 2) / columns))
    return columns, rows, card_width, columns * rows
end

local function draw_launcher(apps, page, message)
    local columns, rows, card_width, page_size = layout()
    local page_count = math.max(1, math.ceil(#apps / page_size))
    page = math.max(1, math.min(page, page_count))

    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    screen_write(1, 1, " CANDOS  |  INICIO", colors.white, colors.blue)
    screen_write(1, 2, message or (#apps .. " aplicaciones"), colors.lightGray)
    screen_write(math.max(1, screen_width - 12), 1, "ACTUALIZAR",
        colors.white, colors.gray, 12)
    screen_write(2, 3, "APLICACIONES", colors.white, colors.black)

    local first = (page - 1) * page_size + 1
    for index = first, math.min(first + page_size - 1, #apps) do
        local local_index = index - first
        local column = local_index % columns
        local row = math.floor(local_index / columns)
        local x = 2 + column * (card_width + 2)
        local y = 5 + row * 6
        local app = apps[index]
        local name = app.name:gsub("%.app$", "")
        graphics.panel(x, y, card_width, 5, nil, colors.lightGray, colors.gray)
        local icon_color = colors[app.icon_color or "blue"] or colors.blue
        screen_write(x + 1, y + 1, "[" .. tostring(app.icon or "APP") .. "]",
            colors.white, icon_color, math.min(5, card_width - 2))
        screen_write(x + 6, y + 1, " " .. name, colors.white,
            index % 2 == 0 and colors.blue or colors.lightBlue,
            math.max(1, card_width - 7))
        screen_write(x + 1, y + 2, "Abrir aplicacion", colors.lightGray,
            colors.gray, card_width - 2)
    end

    if #apps == 0 then
        graphics.panel(2, 5, screen_width - 2, 7, "Sin aplicaciones",
            colors.lightGray, colors.gray)
        screen_write(4, 8, "Instala apps .app en /disk2/apps.",
            colors.lightGray, colors.gray, screen_width - 6)
    end

    local footer_y = screen_height
    button(2, footer_y, 10, "ANTERIOR", colors.gray)
    button(math.floor((screen_width - 9) / 2), footer_y, 10, "RECARGAR", colors.blue)
    button(screen_width - 10, footer_y, 10, "SIGUIENTE", colors.gray)
    screen_write(math.max(1, math.floor((screen_width - 15) / 2)), screen_height - 1,
        "Pagina " .. page .. "/" .. page_count, colors.lightGray)
    draw_taskbar()
    return page, page_count, columns, rows, card_width, page_size
end

local function execute_app(app)
    if monitor then
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
        monitor.clear()
        monitor.setCursorPos(1, 1)
    end
    local task = find_task(app)
    if not task then
        task = launch_app_thread(app)
        tasks[#tasks + 1] = task
    end
    local ok, runtime_error = resume_task(task)
    if monitor then
        term.redirect(monitor)
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
    end
    if not ok then
        return false, "Error al ejecutar " .. app.name .. ": " .. tostring(runtime_error)
    end
    return true, runtime_error
end

local function run_graphical_launcher()
    local apps = collect_apps()
    local page, page_count = 1, 1
    local message

    while true do
        local columns, rows, card_width, page_size
        page, page_count, columns, rows, card_width, page_size =
            draw_launcher(apps, page, message)
        message = nil

        local taskbar = draw_taskbar()
        local event, side, x, y = native_pull_event_raw()
        update_basalt(pack_values(event, side, x, y))
        if event == "monitor_touch" and side == monitor_side then
            if y == 1 and x >= screen_width - 11 then
                apps = collect_apps()
                page = math.min(page, math.max(1, math.ceil(#apps / page_size)))
            elseif y == screen_height - 3 then
                for _, item in ipairs(taskbar) do
                    if x >= item.x and x < item.x + item.width then
                        local _, result = execute_app(item.task.app)
                        message = result
                        break
                    end
                end
            elseif y == screen_height then
                if x <= 11 then
                    page = math.max(1, page - 1)
                elseif x >= screen_width - 10 then
                    page = math.min(page_count, page + 1)
                else
                    apps = collect_apps()
                    page = math.min(page, math.max(1, math.ceil(#apps / page_size)))
                end
            elseif y >= 5 and y < 5 + rows * 6 then
                local row = math.floor((y - 5) / 6)
                local column = math.floor((x - 2) / (card_width + 2))
                local card_x = 2 + column * (card_width + 2)
                local card_y = 5 + row * 6
                if column >= 0 and column < columns and x >= card_x
                    and x < card_x + card_width and y < card_y + 5 then
                    local index = (page - 1) * page_size + row * columns + column + 1
                    local app = apps[index]
                    if app then
                        local _, result = execute_app(app)
                        message = result
                        apps = collect_apps()
                        page = math.min(page, math.max(1, math.ceil(#apps / page_size)))
                    end
                end
            end
        elseif event == "monitor_resize" or event == "peripheral"
            or event == "peripheral_detach" then
            refresh_main_monitor()
            if not monitor then
                local error_monitor
                if peripheral.getType("monitor_1") == "monitor" then
                    error_monitor = peripheral.wrap("monitor_1")
                end
                if error_monitor then
                    error_monitor.setTextScale(0.5)
                    error_monitor.setBackgroundColor(colors.black)
                    error_monitor.setTextColor(colors.white)
                    error_monitor.clear()
                    error_monitor.setCursorPos(1, 1)
                    error_monitor.write("CANDOS: falta monitor_0.")
                end
            end
        end
    end
end

run_graphical_launcher()
active_app_thread = nil
_G.read = native_read
_G.input = native_input
if native_io_read then
    _G.io.read = native_io_read
else
    _G.io.read = nil
end
os.pullEvent = native_pull_event
os.pullEventRaw = original_pull_event_raw
term.redirect(monitor)
