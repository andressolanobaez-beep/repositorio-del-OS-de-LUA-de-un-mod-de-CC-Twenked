local function fail(message)
    io.stderr:write("FAIL: " .. message .. "\n")
    os.exit(1)
end

local function check(condition, message)
    if not condition then
        fail(message)
    end
end

local function normalize(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local value = tostring(select(index, ...) or ""):gsub("\\", "/")
        if value:sub(1, 1) == "/" then
            parts = {}
        end
        for part in value:gmatch("[^/]+") do
            if part == ".." then
                if #parts > 0 then
                    parts[#parts] = nil
                end
            elseif part ~= "." and part ~= "" then
                parts[#parts + 1] = part
            end
        end
    end
    return table.concat(parts, "/")
end

local function host_path(path)
    path = normalize(path)
    if path == "disk2" then
        return ""
    end
    if path:sub(1, 6) == "disk2/" then
        return path:sub(7)
    end
    return path
end

local app_names = {
    "ajustes.app",
    "archivador.app",
    "adivina.app",
    "bloc.app",
    "calendario.app",
    "calculadora.app",
    "carrera.app",
    "convertidor.app",
    "dados.app",
    "dispositivos.app",
    "hardware.app",
    "hola.app",
    "candos_fps.app",
    "matematicas.app",
    "mayor_menor.app",
    "memoria.app",
    "moneda.app",
    "notas.app",
    "palabra.app",
    "pong.app",
    "ppt.app",
    "quiz.app",
    "red.app",
    "reflejos.app",
    "reloj.app",
    "terminal.app",
    "simon.app",
    "tareas.app",
    "temporizador.app",
    "tres_en_raya.app"
}

local test_input_source = [[
local first = input("Primero")
local second = io.read()
print("RESULT:" .. first .. ":" .. second)
local number = io.read("*n")
print("NUMBER:" .. tostring(number))
local _, key = os.pullEvent("key")
print("EVENT:" .. tostring(key))
os.pullEvent("key")
]]
local icon_fixtures = {
    ["adivina.app"] = "? yellow",
    ["ajustes.app"] = "CFG lightBlue",
    ["archivador.app"] = "FS cyan",
    ["bloc.app"] = "TXT orange",
    ["calculadora.app"] = "CAL lime",
    ["calendario.app"] = "DAY pink",
    ["candos_fps.app"] = "FPS red",
    ["carrera.app"] = "RUN green",
    ["convertidor.app"] = "CON orange",
    ["dados.app"] = "D6 white",
    ["dispositivos.app"] = "DEV cyan",
    ["hardware.app"] = "HW gray",
    ["hola.app"] = "HI lime",
    ["matematicas.app"] = "M+ magenta",
    ["mayor_menor.app"] = "<> yellow",
    ["memoria.app"] = "MEM purple",
    ["moneda.app"] = "COIN yellow",
    ["notas.app"] = "NOTE orange",
    ["palabra.app"] = "ABC lightBlue",
    ["pong.app"] = "PONG blue",
    ["ppt.app"] = "PPT red",
    ["quiz.app"] = "Q yellow",
    ["red.app"] = "NET red",
    ["reflejos.app"] = "FAST green",
    ["reloj.app"] = "CLK white",
    ["simon.app"] = "SIMON yellow",
    ["tareas.app"] = "TASK lightBlue",
    ["temporizador.app"] = "TMR green",
    ["terminal.app"] = "CLI gray",
    ["tres_en_raya.app"] = "XO magenta"
}
local basalt_source = [[
local frames = {}
local function make_control(frame)
    local control = {}
    frame.controls[#frame.controls + 1] = control
    for _, method in ipairs({
        "setPosition", "setSize", "setText", "setForeground",
        "setBackground", "setBorder"
    }) do
        control[method] = function(self, ...)
            self[method .. "_args"] = {...}
            if method == "setBorder" then
                basalt_border_count = basalt_border_count + 1
            end
            return self
        end
    end
    function control:onClick(callback)
        self.callback = callback
        return self
    end
    return control
end
local api = {}
function api.createFrame(name)
    local frame = {controls = {}}
    function frame:setBackground() return self end
    function frame:addLabel() return make_control(self) end
    function frame:addButton() return make_control(self) end
    frames[name] = frame
    return frame
end
function api.removeFrame(name)
    frames[name] = nil
end
function api.update(event, side, x, y)
    if event ~= "monitor_touch" then return end
    for _, frame in pairs(frames) do
        for _, control in ipairs(frame.controls) do
            local position = control.setPosition_args
            local size = control.setSize_args
            if position and size and x >= position[1] and x < position[1] + size[1]
                and y >= position[2] and y < position[2] + size[2]
                and control.callback then
                basalt_click_count = basalt_click_count + 1
                control.callback()
                return
            end
        end
    end
end
return api
]]
local calculator_left, calculator_operator, calculator_right =
    ("-12.5 / 2"):match("^%s*(%-?[%d%.]+)%s*([%+%-%*/])%s*(%-?[%d%.]+)%s*$")
check(tonumber(calculator_left) == -12.5 and calculator_operator == "/"
    and tonumber(calculator_right) == 2,
    "La expresion de calculadora no reconoce negativos, decimales y operadores")

local system_files = {
    ["boot/buzzer.lua"] = true,
    ["boot/disk_manager.lua"] = true,
    ["boot/importing.txt"] = true,
    ["boot/shell.py"] = true,
    ["boot/startup.lua"] = true,
    ["boot/utils.lua"] = true,
    ["boot/lib/basalt.lua"] = true
}

local function host_exists(path)
    path = host_path(path)
    if path == "apps/test_input.app/main.app"
        or path == "apps/test_input.app/icon.app" then
        return true
    end
    if system_files[path] then
        return true
    end
    for _, name in ipairs(app_names) do
        if path == "apps/" .. name .. "/main.app"
            or path == "apps/" .. name .. "/icon.app" then
            return true
        end
    end
    return false
end

local function host_is_dir(path)
    path = normalize(path)
    return path == ""
        or path == "disk2"
        or path == "disk2/apps"
        or path == "disk2/files"
        or path == "disk2/boot"
        or path == "disk2/boot/lib"
        or path == "disk2/boot/licenses"
        or path == "disk2/.candOS"
        or path == "."
        or path == "apps"
        or path == "boot"
        or path == "boot/lib"
        or path == "apps/test_input.app"
        or path:match("^apps/[^/]+%.app$")
        or path:match("^disk2/apps/[^/]+%.app$")
        or path == "storageA"
        or path == "storageB"
        or path == "storage20k"
end

fs = {
    combine = normalize,
    exists = function(path)
        path = normalize(path)
        return host_is_dir(path) or host_exists(path)
    end,
    isDir = host_is_dir,
    list = function(path)
        path = normalize(path)
        if path == "disk2/apps" or path == "apps" then
            local result = {}
            for index, name in ipairs(app_names) do
                result[index] = name
            end
            result[#result + 1] = "test_input.app"
            return result
        end
        if path == "disk2/.candOS" or path == "disk2/boot/lib"
            or path == "disk2/boot/licenses" or path == "disk2/files" then
            return {}
        end
        if path:match("^disk2/apps/[^/]+%.app$") or path:match("^apps/[^/]+%.app$") then
            return {"icon.app", "main.app"}
        end
        if path == "storageA" or path == "storageB" or path == "storage20k" then
            return {}
        end
        error("El simulador no permite listar: /" .. path)
    end,
    makeDir = function(path)
        check(normalize(path) == "disk2/.candOS", "makeDir uso una ruta fuera del sistema")
    end,
    getDir = function(path)
        return normalize(path):match("^(.*)/[^/]+$") or ""
    end,
    open = function(path, mode)
        path = normalize(path)
        if mode == "r" and host_exists(path) then
            local contents = path == "disk2/boot/importing.txt"
                and "# Simulator fixture: no startup imports.\n"
                or ""
            if path == "disk2/apps/test_input.app/main.app" then
                contents = test_input_source
            elseif path:match("^disk2/apps/[^/]+%.app/icon%.app$") then
                local package = path:match("^disk2/apps/([^/]+%.app)/icon%.app$")
                contents = icon_fixtures[package] or "APP blue"
            elseif path == "disk2/boot/lib/basalt.lua" then
                contents = basalt_source
            end
            local closed = false
            return {
                readAll = function()
                    check(not closed, "Se intento leer un archivo cerrado")
                    return contents
                end,
                close = function()
                    closed = true
                end
            }
        end
        return nil, "El simulador no permite abrir /" .. path .. " en modo " .. mode
    end
}

local native_loadfile = loadfile
loadfile = function(path, mode, environment)
    path = tostring(path):gsub("\\", "/")
    if path:sub(1, 7) == "/disk2/" then
        path = path:sub(8)
    elseif path:sub(1, 6) == "disk2/" then
        path = path:sub(7)
    end
    if mode == nil then
        return native_loadfile(path)
    end
    return native_loadfile(path, mode, environment)
end

local width, height = 50, 50
local cursor_x, cursor_y = 1, 1
local screen = {}
local monitor_writes = {}
local monitor_1_only = false
local terminal_write_count = 0
local device_names = {"top", "drive_left", "drive_extra", "drive_20000",
    "monitor_1", "printer_1", "modem_1"}
local drive_mounts = {
    drive_left = "storageA",
    drive_extra = "storageB",
    drive_20000 = "storage20k"
}
local function clear_screen()
    screen = {}
    for row = 1, height do
        screen[row] = string.rep(" ", width)
    end
    cursor_x, cursor_y = 1, 1
end
clear_screen()

local monitor = {}
function monitor.getSize()
    return width, height
end
function monitor.setTextScale() end
function monitor.setBackgroundColor() end
function monitor.setTextColor() end
function monitor.clear()
    clear_screen()
end
function monitor.setCursorPos(x, y)
    cursor_x, cursor_y = x, y
end
function monitor.getCursorPos()
    return cursor_x, cursor_y
end
function monitor.write(text)
    monitor_writes[#monitor_writes + 1] = {
        x = cursor_x,
        y = cursor_y,
        text = tostring(text)
    }
    local line = screen[cursor_y]
    if not line then
        return
    end
    text = tostring(text)
    local before = line:sub(1, cursor_x - 1)
    local after_start = cursor_x + #text
    local after = after_start <= width and line:sub(after_start) or ""
    screen[cursor_y] = (before .. text .. after):sub(1, width)
    cursor_x = cursor_x + #text
end
function monitor.scroll(lines)
    for _ = 1, lines do
        table.remove(screen, 1)
        screen[#screen + 1] = string.rep(" ", width)
    end
end

local terminal = {}
function terminal.getSize()
    return width, height
end
function terminal.setCursorPos(x, y)
    cursor_x, cursor_y = x, y
end
function terminal.getCursorPos()
    return cursor_x, cursor_y
end
function terminal.write(text)
    terminal_write_count = terminal_write_count + 1
    monitor.write(text)
end
function terminal.scroll(lines)
    monitor.scroll(lines)
end
function terminal.clear()
    monitor.clear()
end
function terminal.setTextColor() end
function terminal.setBackgroundColor() end

term = {
    current = function()
        return terminal
    end,
    redirect = function(target)
        local previous = terminal
        terminal = target
        return previous
    end
}

colors = {
    black = 1,
    white = 2,
    blue = 4,
    orange = 8,
    magenta = 16,
    lightBlue = 32,
    yellow = 64,
    lime = 128,
    pink = 256,
    gray = 512,
    lightGray = 1024,
    cyan = 2048,
    purple = 4096,
    brown = 8192,
    green = 16384,
    red = 32768
}

peripheral = {
    getType = function(name)
        if monitor_1_only then
            return name == "monitor_1" and "monitor" or nil
        end
        if name == "top" or name == "monitor_1" then
            return "monitor"
        end
        if name == "printer_1" then return "printer" end
        if name == "modem_1" then return "modem" end
        return drive_mounts[name] and "drive" or nil
    end,
    wrap = function(name)
        if monitor_1_only then
            return name == "monitor_1" and monitor or nil
        end
        if name == "top" or name == "monitor_1" then
            return monitor
        end
        if name == "printer_1" then return {} end
        if name == "modem_1" then return {} end
        if drive_mounts[name] then
            return {getMountPath = function()
                return drive_mounts[name]
            end}
        end
        return nil
    end,
    find = function(kind)
        if kind == "monitor" and not monitor_1_only then
            return monitor, "top"
        end
        return nil
    end,
    getNames = function()
        return device_names
    end
}

local native_cwd = ""
shell = {
    dir = function()
        return native_cwd
    end,
    setDir = function(path)
        local target = normalize(path)
        if not fs.exists(target) or not fs.isDir(target) then
            return false, "No existe la carpeta /" .. target
        end
        native_cwd = target
        return true
    end,
    run = function()
        return false, "El simulador no ejecuta comandos de la shell ROM."
    end
}
local native_shell_environment = shell

local touch_events = {
    {"monitor_touch", "top", 25, height},
    {"peripheral_detach", "top"}
}
local touch_index = 0
local SIMULATOR_END = "SIMULATOR_EVENT_QUEUE_EXHAUSTED"
os.pullEvent = function()
    touch_index = touch_index + 1
    local event = touch_events[touch_index]
    if not event then
        touch_index = touch_index - 1
        error(SIMULATOR_END, 0)
    end
    return table.unpack(event)
end
os.pullEventRaw = os.pullEvent
os.getComputerLabel = function()
    return "CANDOS simulator"
end
os.getComputerID = function()
    return 1
end

local saved_print = print
basalt_border_count = 0
basalt_click_count = 0
printError = function(message)
    saved_print("CANDOS ERROR: " .. tostring(message))
end

local startup, load_error = native_loadfile("boot/startup.lua")
check(startup ~= nil, "No se pudo cargar startup.lua: " .. tostring(load_error))

local lua_files = {
    "boot/buzzer.lua",
    "boot/disk_manager.lua",
    "installer.lua",
    "boot/shell.py",
    "boot/startup.lua",
    "boot/utils.lua"
}
for _, app_name in ipairs(app_names) do
    lua_files[#lua_files + 1] = "apps/" .. app_name .. "/main.app"
end
local test_input_chunk, test_input_error =
load(test_input_source, "@test_input.app", "t", _ENV)
check(test_input_chunk ~= nil, "Error de sintaxis en la app de prueba: " ..
tostring(test_input_error))
for _, path in ipairs(lua_files) do
    local chunk, syntax_error = native_loadfile(path)
    check(chunk ~= nil, "Error de sintaxis en " .. path .. ": " ..
        tostring(syntax_error))
end

local function run_until_events_exhausted(entry, message)
    local ok, runtime_error = xpcall(entry, debug.traceback)
    check(not ok and tostring(runtime_error):find(SIMULATOR_END, 1, true),
        message .. ": " .. tostring(runtime_error))
end

run_until_events_exhausted(startup, "Fallo al arrancar")
check(touch_index == #touch_events, "El lanzador no proceso todos los toques simulados")
check(type(shell.load_imports) == "function", "shell.load_imports no fue exportada")
check(type(shell.list_apps) == "function", "shell.list_apps no fue exportada")
check(type(shell.start) == "function", "shell.start no fue exportada")
check(shell.dir() == "/files", "El directorio inicial no apunta a /files")

local apps = shell.list_apps()
check(#apps == #app_names + 1, "Se esperaban " .. #app_names ..
    " apps instaladas y una app de prueba; se encontraron " .. #apps)
local app_packages = 0
for _, app in ipairs(apps) do
    check(app.main_path == "disk2/apps/" .. app.name .. "/main.app",
        "Una app empaquetada no apunta a main.app: " .. app.name)
    check(type(app.icon) == "string" and app.icon ~= ""
        and type(app.icon_color) == "string" and app.icon_color ~= "",
        "No se leyo icon.app para " .. app.name)
    check(colors[app.icon_color] ~= nil,
        "icon.app usa un color no disponible: " .. app.icon_color)
    if app.name ~= "test_input.app" then
        app_packages = app_packages + 1
        check(fs.exists("disk2/apps/" .. app.name .. "/icon.app"),
            "Falta icon.app en " .. app.name)
    end
end
check(app_packages == #app_names, "El simulador no encontro los 30 paquetes .app")
check(shell.where("terminal") == "disk2/apps/terminal.app",
    "No se encontro la app terminal en disk2/apps")
check(shell.resolve("/notas.txt") == "disk2/files/notas.txt",
    "Las rutas de usuario no se resolvieron desde /disk2/files")
local device_list = shell.peripherals()
check(#device_list == #device_names,
    "No se enumeraron los periféricos fuera de los lados tradicionales")
local device_types = {}
for _, device in ipairs(device_list) do
    device_types[device.type] = true
end
check(device_types.printer and device_types.modem and device_types.monitor,
    "No se detectaron pantallas, impresoras y modems")
local paths = shell.path_entries()
local mounted = {}
for _, entry in ipairs(paths) do
    mounted[entry.path] = true
end
check(mounted.storageA and mounted.storageB and mounted.storage20k,
    "No se detectaron todas las unidades conectadas")

local launcher_visible = false
for _, write in ipairs(monitor_writes) do
    if write.y == 1 and write.text:find("CANDOS  |  INICIO", 1, true) then
        launcher_visible = true
        break
    end
end
check(launcher_visible, "No se dibujo el lanzador en el monitor")

local real_loadfile = loadfile
local old_shell_api = {
    dir = function()
        return "/"
    end,
    run = function()
        return true
    end,
    cc = function()
        return true
    end
}
loadfile = function(path, mode, environment)
    if tostring(path):match("shell%.py$") then
        return function()
            return old_shell_api
        end
    end
    return real_loadfile(path, mode, environment)
end
shell = native_shell_environment
touch_events = {
    {"monitor_touch", "top", 5, 5},
    {"peripheral_detach", "top"}
}
touch_index = 0
monitor_writes = {}
clear_screen()

local compatible_startup, compatible_load_error =
    native_loadfile("boot/startup.lua")
check(compatible_startup ~= nil,
    "No se pudo cargar startup.lua para la prueba de compatibilidad: " ..
        tostring(compatible_load_error))
run_until_events_exhausted(compatible_startup,
    "El arranque no tolero una shell anterior")

local writes = {}
for _, write in ipairs(monitor_writes) do
    writes[#writes + 1] = write.text
end
check(table.concat(writes):find("no admite la carga de drivers", 1, true) ~= nil,
    "No se aviso cuando shell.py es una version anterior")
check(table.concat(writes):find("[APP]", 1, true) ~= nil,
    "El lanzador no descubrio paquetes .app sin list_apps")
check(touch_index == #touch_events,
    "El lanzador de compatibilidad no ejecuto y cerro tras los toques simulados")

loadfile = real_loadfile
shell = nil
touch_events = {
    {"monitor_touch", "top", 25, height},
    {"peripheral_detach", "top"}
}
touch_index = 0
monitor_writes = {}
clear_screen()

local no_native_shell_startup, no_native_shell_load_error =
    native_loadfile("boot/startup.lua")
check(no_native_shell_startup ~= nil,
    "No se pudo cargar startup.lua sin shell nativa: " ..
        tostring(no_native_shell_load_error))
run_until_events_exhausted(no_native_shell_startup,
    "El arranque necesita una shell nativa")
check(type(shell.load_imports) == "function",
    "Falta load_imports cuando no hay shell nativa")
local graphics_width, graphics_height = candOS.graphics.getSize()
check(graphics_width == width and graphics_height == height,
    "La API grafica no informo el tamano del monitor")
check(type(candOS.graphics.panel) == "function"
    and type(candOS.graphics.textArea) == "function"
    and type(candOS.graphics.switch) == "function"
    and type(candOS.graphics.progressBar) == "function",
    "Faltan controles graficos reutilizables")

shell = nil
touch_events = {
    {"monitor_touch", "top", 45, height},
    {"monitor_touch", "top", 36, 24},
    {"monitor_touch", "top", 49, 1},
    {"monitor_touch", "top", 25, height - 3},
    {"monitor_touch", "top", 8, 48},
    {"monitor_touch", "top", 8, 48},
    {"monitor_touch", "top", 4, 42},
    {"monitor_touch", "top", 29, 39},
    {"monitor_touch", "top", 37, 36},
    {"monitor_touch", "top", 46, 42},
    {"monitor_touch", "top", 37, 36},
    {"monitor_touch", "top", 35, 48},
    {"monitor_touch", "top", 42, 36},
    {"monitor_touch", "top", 40, 39},
    {"monitor_touch", "top", 35, 48},
    {"monitor_touch", "top", 17, 39},
    {"monitor_touch", "top", 35, 48},
    {"key", "x"},
    {"monitor_touch", "top", 46, 1},
    {"peripheral_detach", "top"}
}
touch_index = 0
monitor_writes = {}
clear_screen()
local interactive_startup = assert(native_loadfile("boot/startup.lua"))
run_until_events_exhausted(interactive_startup,
    "Fallo la prueba de input/minimizar")
local interactive_output = {}
for _, write in ipairs(monitor_writes) do
    interactive_output[#interactive_output + 1] = write.text
end
local rendered = table.concat(interactive_output)
local result_position = rendered:find("RESULT:", 1, true)
local result_text = result_position
    and rendered:sub(result_position, result_position + 30) or "missing"
local recent_writes = {}
for index = math.max(1, #interactive_output - 12), #interactive_output do
    recent_writes[#recent_writes + 1] = interactive_output[index]
end
check(rendered:find("RESULT:Hi:ok", 1, true) ~= nil,
    "io.read/input perdieron el texto al minimizar y reanudar: " .. result_text ..
        "; eventos procesados=" .. touch_index .. "; recientes=" ..
        table.concat(recent_writes, "|"))
check(rendered:find("NUMBER:4", 1, true) ~= nil,
    "io.read('*n') no entrego un valor numerico desde el teclado grafico")
check(rendered:find("EVENT:x", 1, true) ~= nil,
    "La app no recibio el evento al reanudarse")
check(basalt_border_count > 0 and basalt_click_count >= 9,
    "El teclado no creo controles Basalt con borde o no proceso sus clics")
check(touch_index == #touch_events,
    "La app interactiva no se cerro con el boton X")

monitor_1_only = true
monitor_writes = {}
clear_screen()
local previous_terminal_writes = terminal_write_count
local missing_monitor_startup = assert(native_loadfile("boot/startup.lua"))
local missing_monitor_ok, missing_monitor_error =
    xpcall(missing_monitor_startup, debug.traceback)
check(missing_monitor_ok, "El arranque con solo monitor_1 fallo: " ..
    tostring(missing_monitor_error))
check(screen[1]:find("CANDOS: falta monitor principal", 1, true) ~= nil,
    "No se mostro el error en monitor_1 cuando falta monitor_0")
check(terminal_write_count == previous_terminal_writes,
    "El sistema intento usar la terminal principal de la PC")

io.write(string.format(
    "PASS: %d archivos Lua validos; %d apps; arranque grafico sin terminal principal; input grafico, pausa y cierre comprobados.\n",
    #lua_files,
    #app_names
))
