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
    "archivador.app",
    "hardware.app",
    "hola.app",
    "notas.app",
    "terminal.app"
}

local system_files = {
    ["buzzer.lua"] = true,
    ["disk_manager.lua"] = true,
    ["hello.lua"] = true,
    ["importing.txt"] = true,
    ["shell.py"] = true,
    ["startup.lua"] = true,
    ["utils.lua"] = true
}

local function host_exists(path)
    path = host_path(path)
    if system_files[path] then
        return true
    end
    for _, name in ipairs(app_names) do
        if path == "apps/" .. name then
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
        or path == "disk2/.candOS"
        or path == "."
        or path == "apps"
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
            return result
        end
        if path == "disk2/.candOS" then
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
            local contents = path == "disk2/importing.txt"
                and "# Simulator fixture: no startup imports.\n"
                or ""
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
    lightBlue = 8,
    gray = 16,
    lightGray = 32,
    red = 64
}

peripheral = {
    getType = function(name)
        return name == "top" and "monitor" or nil
    end,
    wrap = function(name)
        return name == "top" and monitor or nil
    end,
    find = function(kind)
        if kind == "monitor" then
            return monitor, "top"
        end
        return nil
    end,
    getNames = function()
        return {"top"}
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
    {"monitor_touch", "top", 25, height}
}
local touch_index = 0
os.pullEvent = function()
    touch_index = touch_index + 1
    local event = touch_events[touch_index]
    check(event ~= nil, "CANDOS solicito mas eventos de los esperados")
    return table.unpack(event)
end
os.getComputerLabel = function()
    return "CANDOS simulator"
end
os.getComputerID = function()
    return 1
end

local saved_print = print
printError = function(message)
    saved_print("CANDOS ERROR: " .. tostring(message))
end

local startup, load_error = native_loadfile("startup.lua")
check(startup ~= nil, "No se pudo cargar startup.lua: " .. tostring(load_error))

local lua_files = {
    "buzzer.lua",
    "disk_manager.lua",
    "hello.lua",
    "shell.py",
    "startup.lua",
    "utils.lua"
}
for _, app_name in ipairs(app_names) do
    lua_files[#lua_files + 1] = "apps/" .. app_name
end
for _, path in ipairs(lua_files) do
    local chunk, syntax_error = native_loadfile(path)
    check(chunk ~= nil, "Error de sintaxis en " .. path .. ": " ..
        tostring(syntax_error))
end

local ok, startup_error = xpcall(startup, debug.traceback)
check(ok, "Fallo al arrancar: " .. tostring(startup_error))
check(touch_index == #touch_events, "El lanzador no proceso todos los toques simulados")
check(type(shell.load_imports) == "function", "shell.load_imports no fue exportada")
check(type(shell.list_apps) == "function", "shell.list_apps no fue exportada")
check(type(shell.start) == "function", "shell.start no fue exportada")
check(shell.dir() == "/", "La raiz logica de CANDOS no es /")

local apps = shell.list_apps()
check(#apps == #app_names, "Se esperaban 5 apps; se encontraron " .. #apps)
check(shell.where("terminal") == "disk2/apps/terminal.app",
    "No se encontro la app terminal en disk2/apps")
check(shell.resolve("/notas.txt") == "disk2/notas.txt",
    "Las rutas absolutas no se resolvieron desde disk2")

local launcher_visible = false
for _, write in ipairs(monitor_writes) do
    if write.y == 1 and write.text:find("CANDOS | LANZADOR DE APPS", 1, true) then
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
    {"monitor_touch", "top", 25, height}
}
touch_index = 0
monitor_writes = {}
clear_screen()

local compatible_startup, compatible_load_error = native_loadfile("startup.lua")
check(compatible_startup ~= nil,
    "No se pudo cargar startup.lua para la prueba de compatibilidad: " ..
        tostring(compatible_load_error))
local compatible_ok, compatible_error = xpcall(compatible_startup, debug.traceback)
check(compatible_ok,
    "El arranque no tolero una shell anterior: " .. tostring(compatible_error))

local writes = {}
for _, write in ipairs(monitor_writes) do
    writes[#writes + 1] = write.text
end
check(table.concat(writes):find("no admite la carga de drivers", 1, true) ~= nil,
    "No se aviso cuando shell.py es una version anterior")
check(table.concat(writes):find("> archivador", 1, true) ~= nil,
    "La lista de apps de disk2 no se mostro con una shell anterior sin list_apps")
check(touch_index == #touch_events,
    "El lanzador de compatibilidad no ejecuto y cerro tras los toques simulados")

loadfile = real_loadfile
shell = nil
touch_events = {
    {"monitor_touch", "top", 25, height}
}
touch_index = 0
monitor_writes = {}
clear_screen()

local no_native_shell_startup, no_native_shell_load_error =
    native_loadfile("startup.lua")
check(no_native_shell_startup ~= nil,
    "No se pudo cargar startup.lua sin shell nativa: " ..
        tostring(no_native_shell_load_error))
local no_native_shell_ok, no_native_shell_error =
    xpcall(no_native_shell_startup, debug.traceback)
check(no_native_shell_ok,
    "El arranque necesita una shell nativa: " .. tostring(no_native_shell_error))
check(type(shell.load_imports) == "function",
    "Falta load_imports cuando no hay shell nativa")

io.write(string.format(
    "PASS: %d archivos Lua validos; CANDOS arranca en %dx%d con shell actual, shell anterior y sin shell nativa; %d apps detectadas; rutas confinadas a disk2.\n",
    #lua_files,
    width,
    height,
    #apps
))
