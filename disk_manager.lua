--[[
  Disk Manager para CC: Tweaked
  Gestiona los archivos en tus disqueteras conectadas a los lados
  
  Comandos:
  - disk_manager list     : Listar archivos en disqueteras
  - disk_manager load <n> : Cargar archivo por número
  - disk_manager make <n> <nombre> : Crear nuevo archivo
--]]

-- Verificar que hay disqueteras
local function verify_disks()
    local disks = {}
    for _, side in ipairs({"left", "right"}) do
        if peripheral.isPresent(side) then
            local disk = peripheral.wrap(side)
            table.insert(disks, {side = side, label = disk.getLabel() or "Sin nombre", capacity = disk.capacity()})
        else
            table.insert(disks, {side = side, label = "Ninguna", capacity = 0})
        end
    end
    return disks
end

-- Listar archivos en todas las disqueteras
local function list_files()
    local disks = verify_disks()
    cprint("=== Archivos en Disqueteras ===")
    
    local total = 0
    for _, disk in ipairs(disks) do
        if disk.label and disk.label ~= "Ninguna" then
            local files = disk.list() or {}
            cprint("--- " .. disk.side .. ": " .. disk.label .. " ---")
            for _, fname in ipairs(files) do
                local attr = disk.isReadOnly(fname) and " [SO]" or ""
                cprint("  " .. fname .. attr)
                total = total + 1
            end
            if #files == 0 then
                cprint("  (vacío)")
            end
        end
    end
    cprint("")
    cprint("Total de archivos: " .. total)
end

-- Cargar y ejecutar un archivo por número
local function load_by_number()
    list_files()
    cprint ""
    cprint "Número del archivo a cargar: "
    local num = tonumber(read())
    
    local disks = verify_disks()
    local current = 0
    
    for _, disk in ipairs(disks) do
        if disk.label and disk.label ~= "Ninguna" then
            local files = disk.list() or {}
            for _, fname in ipairs(files) do
                current = current + 1
                if current == num then
                    -- Leer y ejecutar archivo
                    local file = fs.open(fname, "r")
                    if file then
                        local content = file.readAll()
                        file.close()
                        
                        local func, err = load(content, fname, "t", _G)
                        if func then
                            setfenv(func, _G)
                            local ok, err2 = pcall(func)
                            if ok then
                                cprint("Ejecutado: " .. fname)
                            else
                                cprint("Error: " .. tostring(err2))
                            end
                        else
                            cprint("Error de sintaxis: " .. tostring(err))
                        end
                    else
                        cprint("No se pudo abrir archivo")
                    end
                    return
                end
            end
        end
    end
    cprint("Número fuera de rango")
end

-- crear archivo de texto
local function make_file()
    list_files()
    cprint ""
    cprint "Número de archivo (o nombre): "
    local fname = read():gsub("^%s*(.-)%s*$", "%1")
    
    if fname == "" then
        cprint "Nombre inválido"
        return
    end
    
    -- Intentar encontrar o crear en primera disquetera disponible
    for _, side in ipairs({"left", "right"}) do
        if peripheral.isPresent(side) then
            local disk = peripheral.wrap(side)
            -- Si archivo existe, preguntar si sobrescribir
            if disk.exists(fname) then
                cprint "Archivo existente. ¿Sobrescribir? (s/n)"
                local resp = read():gsub("^%s*(.-)%s*$", "%1")
                if resp ~= "s" and resp ~= "S" then
                    return
                end
            end
            
            local file = fs.open(fname, "w")
            if file then
                cprint ""
                cprint "¿Escribir contenido? (Escribe 'listo' cuando termines)"
                
                -- Modo interactivo para escribir
                local line = read()
                while line ~= "listo" do
                    file.writeLine(line)
                    line = read()
                end
                file.close()
                cprint "Archivo creado exitosamente: " .. fname
            else
                cprint "Error al crear archivo"
            end
            return
        end
    end
    cprint "No hay disqueteras disponibles"
end

-- Programa principal - bucle simple
cprint "=== Disk Manager CC: Tweaked ==="
cprint ""

-- Procesar comando si se pasó como argumento
local arg = ...

if arg == "list" or arg == "ls" then
    list_files()
elseif arg == "load" then
    load_by_number()
elseif arg == "make" then
    make_file()
else
    -- Menú interactivo
    cprint "Comandos disponibles:"
    cprint "  disk_manager list   - Listar archivos"
    cprint "  disk_manager load <n> - Cargar archivo por número"
    cprint "  disk_manager make <n> - Crear nuevo archivo"
    cprint ""
    cprint "Ingresa comando (o 'help' para más info):"
    local cmd = read():gsub("^%s*(.-)%s*$", "%1")
    
    if cmd == "help" then
        cprint "Disk Manager ayuda:"
        cprint "  list/ls  - Listar todos los archivos en disqueteras"
        cprint "  load <n> - Cargar y ejecutar archivo número n"
        cprint "  make     - Crear nuevo archivo de texto interactivo"
    elseif cmd == "list" or cmd == "ls" then
        list_files()
    end
end