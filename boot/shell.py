-- CANDOS shell library. This is Lua source despite its requested .py filename:
-- CC:Tweaked executes Lua and does not provide a Python runtime.

local original_shell = shell
local native_run = type(original_shell) == "table" and original_shell.run or nil
local system_root
local modern_layout = fs.exists("/disk2/boot/shell.py")
if modern_layout then
    system_root = fs.combine("disk2")
elseif fs.exists("/disk2/shell.py") then
    system_root = fs.combine("disk2")
elseif type(original_shell) == "table" and type(original_shell.dir) == "function" then
    system_root = fs.combine(original_shell.dir() or "")
else
    system_root = fs.combine("")
end
local files_root = fs.combine(system_root, "files")
local current_dir = fs.exists(files_root) and fs.isDir(files_root)
    and files_root or system_root
local native_shell = original_shell

if type(native_shell) ~= "table" then
    native_shell = {}
end
if type(native_shell.dir) ~= "function" then
    native_shell.dir = function()
        return current_dir
    end
end
if type(native_shell.setDir) ~= "function" then
    native_shell.setDir = function(path)
        local target = fs.combine(path or "")
        if not fs.exists(target) or not fs.isDir(target) then
            return false, "La carpeta no existe: " .. target
        end
        current_dir = target
        return true
    end
end

local config_dir = fs.combine(system_root, ".candOS")
local path_file = fs.combine(config_dir, "path.txt")
local importing_file = fs.combine(system_root,
    modern_layout and "boot/importing.txt" or "importing.txt")
local legacy_importing_file = fs.combine(system_root, "importing.txt")
local custom_paths = {}
local api = {}

local function display_path(path)
    path = fs.combine(path or "")
    if system_root ~= "" then
        if path == system_root then
            return "/"
        end
        local prefix = system_root .. "/"
        if path:sub(1, #prefix) == prefix then
            path = path:sub(#prefix + 1)
        end
    end
    return path == "" and "/" or "/" .. path
end

local function resolve(path)
    path = tostring(path or "")
    path = path:gsub("\\", "/")
    if path:sub(1, 1) == "/" then
        local relative = path:sub(2)
        if relative == "" then
            return system_root
        end
        local first = relative:match("^([^/]+)")
        if first == "apps" or first == "boot" or first == "files"
            or first == ".candOS" then
            return fs.combine(system_root, relative)
        end
        if modern_layout then
            return fs.combine(files_root, relative)
        end
        return fs.combine(system_root, relative)
    end
    return fs.combine(current_dir, path)
end

local function read_file(path)
    local file, err = fs.open(path, "r")
    if not file then
        return nil, err
    end
    local contents = file.readAll()
    file.close()
    return contents
end

local function write_file(path, contents)
    local file, err = fs.open(path, "w")
    if not file then
        return false, err
    end
    file.write(contents)
    file.close()
    return true
end

local function add_unique(list, path)
    path = fs.combine(path)
    for _, existing in ipairs(list) do
        if existing:lower() == path:lower() then
            return false
        end
    end
    list[#list + 1] = path
    return true
end

local function load_saved_paths()
    fs.makeDir(config_dir)
    if not fs.exists(path_file) then
        return
    end
    local contents, err = read_file(path_file)
    if not contents then
        print("No se pudo leer " .. path_file .. ": " .. tostring(err))
        return
    end
    for source_line in contents:gmatch("[^\r\n]+") do
        local line = source_line:gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" then
            add_unique(custom_paths, resolve(line))
        end
    end
end

local function get_path_entries()
    local entries, seen = {}, {}
    local function add(path, side)
        path = fs.combine(path)
        if not fs.exists(path) or not fs.isDir(path) then
            return
        end
        local key = path:lower()
        if not seen[key] then
            seen[key] = true
            entries[#entries + 1] = {path = path, side = side or "computador"}
        end
    end

    add(fs.combine(system_root, "apps"), "computador")
    add(fs.combine(system_root, "apps/candos"), "compatibilidad")
    for _, path in ipairs(custom_paths) do
        add(path, "computador")
    end
    local names = type(peripheral.getNames) == "function"
        and peripheral.getNames() or {"left", "right"}
    for _, name in ipairs(names) do
        if peripheral.getType(name) == "drive" then
            local drive = peripheral.wrap(name)
            if drive and type(drive.getMountPath) == "function" then
                local mount = drive.getMountPath()
                if mount then
                    add(mount, name)
                end
            end
        end
    end
    return entries
end

local function connected_peripherals()
    local devices = {}
    if type(peripheral.getNames) ~= "function" then
        for _, name in ipairs({"left", "right", "top", "bottom", "front", "back"}) do
            local kind = peripheral.getType(name)
            if kind then
                devices[#devices + 1] = {name = name, type = kind}
            end
        end
        return devices
    end

    for _, name in ipairs(peripheral.getNames()) do
        local kind = peripheral.getType(name)
        if kind then
            devices[#devices + 1] = {name = name, type = kind}
        end
    end
    table.sort(devices, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return devices
end

local function path_string()
    local paths = {}
    for _, entry in ipairs(get_path_entries()) do
        paths[#paths + 1] = display_path(entry.path)
    end
    return table.concat(paths, ";")
end

local function parse_words(line)
    local words, current = {}, {}
    local quote, started = nil, false
    local index = 1

    while index <= #line do
        local character = line:sub(index, index)
        if quote then
            if character == quote then
                quote = nil
            elseif character == "\\" and index < #line
                and line:sub(index + 1, index + 1) == quote then
                index = index + 1
                current[#current + 1] = quote
            else
                current[#current + 1] = character
            end
            started = true
        elseif character == '"' or character == "'" then
            quote = character
            started = true
        elseif character:match("%s") then
            if started then
                words[#words + 1] = table.concat(current)
                current, started = {}, false
            end
        else
            current[#current + 1] = character
            started = true
        end
        index = index + 1
    end

    if quote then
        return nil, "Comillas sin cerrar."
    end
    if started then
        words[#words + 1] = table.concat(current)
    end
    return words
end

local function expand_variables(words)
    local current_path = path_string()
    for index, word in ipairs(words) do
        words[index] = word:gsub("%%path%%", function()
            return current_path
        end)
    end
end

local function base_name(path)
    return fs.combine(path):match("([^/]+)$") or ""
end

local function executable_candidates(name)
    if name:lower():match("%.app$") or name:lower():match("%.lua$") then
        return {name}
    end
    return {name .. ".app", name .. ".lua"}
end

local function scan_for_name(directory, wanted, results, depth)
    if depth > 10 or not fs.exists(directory) or not fs.isDir(directory) then
        return
    end
    local names = fs.list(directory)
    table.sort(names)
    for _, name in ipairs(names) do
        local path = fs.combine(directory, name)
        if fs.isDir(path) then
            if name:lower():match("%.app$") then
                if name:lower() == wanted:lower()
                    and fs.exists(fs.combine(path, "main.app")) then
                    results[#results + 1] = path
                end
            else
                scan_for_name(path, wanted, results, depth + 1)
            end
        elseif name:lower() == wanted:lower() then
            results[#results + 1] = path
        end
    end
end

local function find_in_paths(name)
    for _, candidate in ipairs(executable_candidates(name)) do
        local direct = resolve(candidate)
        if fs.exists(direct) and (not fs.isDir(direct)
            or fs.exists(fs.combine(direct, "main.app"))) then
            return direct
        end
        for _, entry in ipairs(get_path_entries()) do
            local matches = {}
            scan_for_name(entry.path, base_name(candidate), matches, 0)
            if #matches > 0 then
                return matches[1]
            end
        end
    end
end

local function execute_file(path, arguments)
    local program_path = path
    if fs.isDir(program_path) then
        program_path = fs.combine(program_path, "main.app")
    end
    local source, read_error = read_file(program_path)
    if not source then
        return false, "No se pudo leer " .. display_path(program_path) ..
            ": " .. tostring(read_error)
    end
    local program, syntax_error = load(source, "@" .. display_path(program_path), "t", _ENV)
    if not program then
        return false, "Error de sintaxis en " .. display_path(program_path) ..
            ": " .. tostring(syntax_error)
    end
    local ok, runtime_error = pcall(program, table.unpack(arguments, 1, #arguments))
    if not ok then
        return false, "Error al ejecutar " .. display_path(path) .. ": " .. tostring(runtime_error)
    end
    return true
end

local function persist_paths()
    fs.makeDir(config_dir)
    local lines = {}
    for _, path in ipairs(custom_paths) do
        lines[#lines + 1] = display_path(path)
    end
    return write_file(path_file, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function load_imports()
    local import_path = importing_file
    if not fs.exists(import_path) and fs.exists(legacy_importing_file) then
        import_path = legacy_importing_file
    end
    if not fs.exists(import_path) then
        return true
    end
    local contents, err = read_file(import_path)
    if not contents then
        print("No se pudo leer importing.txt: " .. tostring(err))
        return false
    end

    local success = true
    for source_line in contents:gmatch("[^\r\n]+") do
        local line = source_line:gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" and line:sub(1, 1) ~= "#" and line:sub(1, 2) ~= "--" then
            local path = resolve(line)
            if fs.exists(path) and not fs.isDir(path) then
                local ok, load_error = execute_file(path, {})
                if not ok then
                    print("Driver " .. display_path(path) .. ": " .. load_error)
                    success = false
                end
            else
                print("Driver no encontrado: " .. line)
                success = false
            end
        end
    end
    return success
end

local function add_import(path)
    local file_path = find_in_paths(path)
    if not file_path then
        return false, "No se encontro el archivo para importar."
    end
    if not file_path:lower():match("%.app$") and not file_path:lower():match("%.lua$") then
        return false, "Solo se pueden importar archivos .app o .lua."
    end

    local existing, err = read_file(importing_file)
    if not existing and fs.exists(importing_file) then
        return false, "No se pudo leer importing.txt: " .. tostring(err)
    end
    existing = existing or ""
    local canonical = display_path(file_path)
    for line in existing:gmatch("[^\r\n]+") do
        if line:gsub("^%s*(.-)%s*$", "%1"):lower() == canonical:lower() then
            return true, "El driver ya estaba registrado: " .. canonical
        end
    end

    local separator = existing ~= "" and not existing:match("\n$") and "\n" or ""
    local ok, write_error = write_file(importing_file, existing .. separator .. canonical .. "\n")
    if not ok then
        return false, "No se pudo actualizar importing.txt: " .. tostring(write_error)
    end
    local loaded, load_error = execute_file(file_path, {})
    if not loaded then
        return false, "Registrado para el proximo inicio, pero fallo al cargarlo: " .. load_error
    end
    return true, "Driver cargado y registrado para el proximo inicio: " .. canonical
end

local function change_directory(path)
    if not path or path == "" then
        path = "/"
    end
    local target = resolve(path)
    if not fs.exists(target) or not fs.isDir(target) then
        return false, "La carpeta no existe: " .. display_path(target)
    end
    local changed, err = native_shell.setDir(target)
    if changed == false then
        return false, "No se pudo cambiar de carpeta: " .. tostring(err or target)
    end
    current_dir = target
    return true
end

local function find_path(name)
    for _, candidate in ipairs(executable_candidates(name)) do
        local direct = resolve(candidate)
        if fs.exists(direct) and (not fs.isDir(direct)
            or fs.exists(fs.combine(direct, "main.app"))) then
            return direct
        end
        for _, entry in ipairs(get_path_entries()) do
            local results = {}
            scan_for_name(entry.path, base_name(candidate), results, 0)
            if #results > 0 then
                return results[1]
            end
        end
    end
end

local function nano(path)
    if not path or path == "" then
        return false, "Uso: nano <archivo>"
    end
    local target = resolve(path)
    if fs.exists(target) and fs.isDir(target) then
        return false, "No se puede editar una carpeta."
    end

    local contents = ""
    if fs.exists(target) then
        local read_error
        contents, read_error = read_file(target)
        if not contents then
            return false, "No se pudo leer el archivo: " .. tostring(read_error)
        end
        print("Contenido actual:")
        for line in (contents .. "\n"):gmatch("(.-)\n") do
            print(line)
        end
    end

    print("Editor simple: escribe el archivo completo; :wq guarda, :q cancela.")
    local lines = {}
    while true do
        local line = read()
        if line == ":wq" then
            break
        elseif line == ":q" then
            return true, "Edicion cancelada."
        end
        lines[#lines + 1] = line
    end
    local ok, err = write_file(target, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
    if not ok then
        return false, "No se pudo guardar el archivo: " .. tostring(err)
    end
    return true, "Guardado: " .. display_path(target)
end

local function copy_file(source, destination)
    if not source or not destination then
        return false, "Uso: copy <archivo> <carpeta_destino>"
    end
    local source_path = resolve(source)
    if not fs.exists(source_path) or fs.isDir(source_path) then
        return false, "El archivo de origen no existe o es una carpeta."
    end
    local destination_path = resolve(destination)
    if fs.exists(destination_path) and fs.isDir(destination_path) then
        destination_path = fs.combine(destination_path, base_name(source_path))
    end
    if fs.exists(destination_path) and fs.isDir(destination_path) then
        return false, "El destino no puede ser una carpeta."
    end
    local contents, read_error = read_file(source_path)
    if not contents then
        return false, "No se pudo leer el origen: " .. tostring(read_error)
    end
    local ok, write_error = write_file(destination_path, contents)
    if not ok then
        return false, "No se pudo escribir el destino: " .. tostring(write_error)
    end
    return true, "Copiado a " .. display_path(destination_path)
end

local function delete_file(path)
    if not path or path == "" then
        return false, "Uso: del <archivo>"
    end
    local target = resolve(path)
    if not fs.exists(target) then
        return false, "El archivo no existe: " .. display_path(target)
    end
    if fs.isDir(target) then
        return false, "del solo elimina archivos, no carpetas."
    end
    local ok, err = pcall(fs.delete, target)
    if not ok then
        return false, "No se pudo eliminar: " .. tostring(err)
    end
    return true, "Eliminado: " .. display_path(target)
end

local function add_path(path)
    if not path or path == "" then
        return false, "Uso: path <carpeta>"
    end
    local target = resolve(path)
    if not fs.exists(target) or not fs.isDir(target) then
        return false, "La carpeta no existe: " .. display_path(target)
    end
    if not add_unique(custom_paths, target) then
        return true, "La carpeta ya esta en el path."
    end
    local ok, err = persist_paths()
    if not ok then
        custom_paths[#custom_paths] = nil
        return false, "No se pudo guardar el path: " .. tostring(err)
    end
    return true, "Agregada al path: " .. display_path(target)
end

local function print_result(ok, message)
    if message then
        print(message)
    end
    return ok
end

function api.dir()
    return display_path(current_dir)
end

function api.resolve(path)
    return resolve(path)
end

function api.display(path)
    return display_path(path)
end

function api.path_entries()
    return get_path_entries()
end

function api.peripherals()
    return connected_peripherals()
end

function api.list_apps()
    local apps, seen = {}, {}
    local function scan(entry, directory, depth)
        if depth > 10 or not fs.exists(directory) or not fs.isDir(directory) then
            return
        end
        local names = fs.list(directory)
        table.sort(names)
        for _, name in ipairs(names) do
            local path = fs.combine(directory, name)
            if fs.isDir(path) then
                if name:lower():match("%.app$") then
                    local main_path = fs.combine(path, "main.app")
                    local key = name:lower()
                    if fs.exists(main_path) and not seen[key] then
                        seen[key] = true
                        local icon_path = fs.combine(path, "icon.app")
                        local icon = fs.exists(icon_path) and read_file(icon_path) or ""
                        local glyph, color = tostring(icon):match("^%s*([^%s]+)%s*([^%s]*)")
                        apps[#apps + 1] = {
                            name = name,
                            path = path,
                            main_path = main_path,
                            icon = glyph or "APP",
                            icon_color = color or "blue",
                            side = entry.side,
                            relative_path = display_path(path)
                        }
                    end
                else
                    scan(entry, path, depth + 1)
                end
            elseif name:lower():match("%.app$") then
                local key = name:lower()
                if not seen[key] then
                    seen[key] = true
                    apps[#apps + 1] = {
                        name = name,
                        path = path,
                        main_path = path,
                        icon = "APP",
                        icon_color = "gray",
                        side = entry.side,
                        relative_path = display_path(path)
                    }
                end
            end
        end
    end
    for _, entry in ipairs(get_path_entries()) do
        scan(entry, entry.path, 0)
    end
    table.sort(apps, function(a, b)
        local a_name, b_name = a.name:lower(), b.name:lower()
        if a_name == b_name then
            return a.path:lower() < b.path:lower()
        end
        return a_name < b_name
    end)
    return apps
end

function api.start(path, arguments)
    if not path or path == "" then
        return false, "Uso: start <archivo.lua|archivo.app> [argumentos]"
    end
    local target = find_path(path)
    if not target then
        return false, "No se encontro la aplicacion: " .. path
    end
    if not target:lower():match("%.app$") and not target:lower():match("%.lua$")
        and not (fs.isDir(target)
            and fs.exists(fs.combine(target, "main.app"))) then
        return false, "Solo se pueden ejecutar archivos .app o .lua."
    end
    return execute_file(target, arguments or {})
end

function api.where(name)
    if not name or name == "" then
        return nil
    end
    return find_path(name)
end

function api.load_imports()
    return load_imports()
end

function api.cc(command_line)
    local words, err = parse_words(tostring(command_line or ""))
    if not words then
        return print_result(false, err)
    end
    if #words == 0 then
        return true
    end
    if type(native_run) ~= "function" then
        return print_result(false, "La shell nativa de CC:Tweaked no esta disponible.")
    end
    local ok = native_run(table.unpack(words))
    current_dir = fs.combine(native_shell.dir() or current_dir)
    return ok
end

function api.run(command_line)
    local words, err = parse_words(tostring(command_line or ""))
    if not words then
        return print_result(false, err)
    end
    if #words == 0 then
        return true
    end
    expand_variables(words)

    local command = words[1]:lower()
    if command == "cd" then
        return print_result(change_directory(words[2]))
    elseif command == "start" then
        local arguments = {}
        for index = 3, #words do
            arguments[#arguments + 1] = words[index]
        end
        local ok, start_error = api.start(words[2], arguments)
        return print_result(ok, start_error)
    elseif command == "importing" then
        return print_result(add_import(words[2]))
    elseif command == "path" then
        if not words[2] then
            print(path_string())
            return true
        end
        local folder = table.concat(words, " ", 2)
        return print_result(add_path(folder))
    elseif command == "where" then
        local path = api.where(words[2])
        if path then
            print(display_path(path))
            return true
        end
        return print_result(false, "No se encontro: " .. tostring(words[2] or ""))
    elseif command == "echo" then
        local message = {}
        for index = 2, #words do
            message[#message + 1] = words[index]
        end
        print(table.concat(message, " "))
        return true
    elseif command == "nano" then
        return print_result(nano(words[2]))
    elseif command == "del" then
        return print_result(delete_file(words[2]))
    elseif command == "copy" then
        return print_result(copy_file(words[2], words[3]))
    elseif command == "pwd" then
        print(api.dir())
        return true
    elseif command == "clear" or command == "cls" then
        term.clear()
        term.setCursorPos(1, 1)
        return true
    elseif command == "help" then
        print("Comandos CANDOS: cd, start, importing, path, where, echo, nano, del, copy")
        print("Tambien: pwd, apps, clear, exit. Usa shell.cc(...) para la shell de CC:Tweaked.")
        return true
    elseif command == "apps" then
        local apps = api.list_apps()
        for index, app in ipairs(apps) do
            print(string.format("%d. %s [%s]", index, app.name, display_path(app.path)))
        end
        if #apps == 0 then
            print("No hay archivos .app en el path.")
        end
        return true
    elseif command == "exit" then
        return true, "exit"
    end

    local target = find_path(words[1])
    if target then
        local arguments = {}
        for index = 2, #words do
            arguments[#arguments + 1] = words[index]
        end
        local ok, run_error = execute_file(target, arguments)
        return print_result(ok, run_error)
    end

    return print_result(false, "Comando CANDOS desconocido: " .. words[1] ..
        ". Usa shell.cc(...) para ejecutar un comando de CC:Tweaked.")
end

function api.add_import(path)
    return add_import(path)
end

load_saved_paths()

setmetatable(api, {__index = native_shell})
return api
