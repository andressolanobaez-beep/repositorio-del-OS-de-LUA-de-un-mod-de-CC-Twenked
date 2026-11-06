-- Gestion de archivos en disquetes montados por las lectoras de CC: Tweaked.

local SIDES = {"left", "right"}

local function get_mounted_disks()
    local disks = {}
    for _, side in ipairs(SIDES) do
        if peripheral.getType(side) == "drive" then
            local drive = peripheral.wrap(side)
            local mount = drive.getMountPath()
            if mount then
                disks[#disks + 1] = {
                    side = side,
                    mount = mount,
                    label = drive.getDiskLabel() or "sin etiqueta"
                }
            end
        end
    end
    return disks
end

local function get_files(disk)
    local files = {}
    for _, name in ipairs(fs.list(disk.mount)) do
        local path = fs.combine(disk.mount, name)
        if not fs.isDir(path) then
            files[#files + 1] = name
        end
    end
    table.sort(files)
    return files
end

local function list_files()
    print("=== Archivos en disquetes ===")
    local disks = get_mounted_disks()
    local count = 0

    if #disks == 0 then
        print("No hay discos de datos montados en las lectoras left/right.")
        return
    end

    for _, disk in ipairs(disks) do
        print("--- " .. disk.side .. ": " .. disk.label .. " (" .. disk.mount .. ") ---")
        local files = get_files(disk)
        if #files == 0 then
            print("  (vacio)")
        end
        for _, name in ipairs(files) do
            count = count + 1
            print(string.format("  %d. %s", count, name))
        end
    end
    print("Total: " .. count .. " archivo(s)")
end

local function select_file(number)
    local disks = get_mounted_disks()
    local current = 0
    for _, disk in ipairs(disks) do
        for _, name in ipairs(get_files(disk)) do
            current = current + 1
            if current == number then
                return disk, name
            end
        end
    end
end

local function load_file(number)
    if not number then
        list_files()
        write("Numero del archivo a ejecutar: ")
        number = tonumber(read())
    end
    if not number or number < 1 or number % 1 ~= 0 then
        print("Numero invalido.")
        return
    end

    local disk, name = select_file(number)
    if not disk then
        print("No existe un archivo con ese numero.")
        return
    end
    if not name:lower():match("%.lua$") and not name:lower():match("%.app$") then
        print("Solo se pueden ejecutar archivos .lua o .app.")
        return
    end

    local path = fs.combine(disk.mount, name)
    local file, open_error = fs.open(path, "r")
    if not file then
        print("No se pudo abrir " .. path .. ": " .. tostring(open_error))
        return
    end
    local source = file.readAll()
    file.close()

    local program, syntax_error = load(source, "@" .. path, "t", _ENV)
    if not program then
        print("Error de sintaxis en " .. name .. ": " .. tostring(syntax_error))
        return
    end

    local ok, runtime_error = pcall(program)
    if not ok then
        print("Error al ejecutar " .. name .. ": " .. tostring(runtime_error))
        return
    end
    print("Ejecutado desde la lectora " .. disk.side .. ": " .. name)
end

local function valid_filename(name)
    return name ~= "" and name ~= "." and name ~= ".."
        and not name:find("/", 1, true)
        and not name:find("\\", 1, true)
        and not name:find(":", 1, true)
end

local function make_file(name)
    if not name or name == "" then
        write("Nombre del archivo (sin rutas): ")
        name = read():gsub("^%s*(.-)%s*$", "%1")
    end
    if not valid_filename(name) then
        print("Nombre invalido; usa un nombre simple sin rutas.")
        return
    end

    local disks = get_mounted_disks()
    if #disks == 0 then
        print("No hay discos de datos montados.")
        return
    end

    for _, disk in ipairs(disks) do
        local path = fs.combine(disk.mount, name)
        if fs.exists(path) then
            write("El archivo existe en " .. disk.side .. ". Sobrescribir? (s/n): ")
            local answer = read():lower()
            if answer ~= "s" then
                print("Cancelado.")
                return
            end
        end

        local file, open_error = fs.open(path, "w")
        if file then
            print("Escribe el contenido. Usa una linea con 'listo' para terminar.")
            while true do
                local line = read()
                if line == "listo" then
                    break
                end
                file.writeLine(line)
            end
            file.close()
            print("Creado en " .. disk.side .. ": " .. path)
            return
        end
        print("No se pudo escribir en " .. disk.side .. ": " .. tostring(open_error))
    end
    print("Ninguna lectora permitio crear el archivo.")
end

local action, value = ...
action = (action or ""):lower()

if action == "list" or action == "ls" then
    list_files()
elseif action == "load" then
    load_file(tonumber(value))
elseif action == "make" then
    make_file(value)
elseif action == "help" then
    print("Uso: disk_manager.lua list | load [numero] | make [nombre]")
else
    print("Comandos: list, load [numero], make [nombre], help")
end
