local REPOSITORY = "andressolanobaez-beep/repositorio-del-OS-de-LUA-de-un-mod-de-CC-Twenked"
local REVISION = "7c193152434d665fab7b9bf83fa776b0c7eab4ef"
local RAW_BASE = "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. REVISION .. "/"
local BASALT_REVISION = "14c0630c1e110c5b507534e19e6c9607ba10df3e"
local BASALT_BASE = "https://raw.githubusercontent.com/Pyroxenium/Basalt/" ..
    BASALT_REVISION .. "/"
local INSTALL_DIR = "disk"
local SYSTEM_ROOT = "disk2"
local APP_DISK_3 = "disk3"
local APP_DISK_4 = "disk4"
local SYSTEM_APPS_DIR = "apps"
local SYSTEM_BOOT_DIR = "boot"
local SYSTEM_FILES_DIR = "files"
local DISK_ROOTS = {INSTALL_DIR, SYSTEM_ROOT, APP_DISK_3, APP_DISK_4}

local files = {
    {source = "boot/startup.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/startup.lua"},
    {source = "boot/shell.py", root = APP_DISK_4, target = SYSTEM_BOOT_DIR .. "/shell.py"},
    {source = "boot/utils.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/utils.lua"},
    {source = "boot/disk_manager.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/disk_manager.lua"},
    {source = "boot/buzzer.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/buzzer.lua"},
    {source = "boot/importing.txt", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/importing.txt", preserve_existing = true},
    {source = "basalt-1.6.6.lua",
        url = BASALT_BASE .. "docs/versions/basalt-1.6.6.lua",
        split_basalt = true},
    {source = "Basalt-MIT-LICENSE.txt", url = BASALT_BASE .. "LICENSE",
        root = APP_DISK_4, target = SYSTEM_BOOT_DIR .. "/licenses/Basalt-MIT-LICENSE.txt"}
}

local app_names = {
    "adivina", "ajustes", "archivador", "bloc", "calculadora", "calendario",
    "candos_fps", "carrera", "convertidor", "dados", "dispositivos", "hardware",
    "hola", "matematicas", "mayor_menor", "memoria", "moneda", "notas",
    "palabra", "pong", "ppt", "quiz", "red", "reflejos", "reloj", "simon",
    "tareas", "temporizador", "terminal", "tres_en_raya"
}

local app_disk_groups = {
    [INSTALL_DIR] = {
        "archivador", "dispositivos", "quiz", "ppt", "moneda"
    },
    [SYSTEM_ROOT] = {
        "red", "ajustes", "pong", "bloc", "hardware", "notas"
    },
    [APP_DISK_3] = {
        "candos_fps", "tres_en_raya", "memoria", "simon",
        "matematicas", "adivina", "hola", "reloj", "terminal"
    },
    [APP_DISK_4] = {
        "carrera", "temporizador", "calendario", "palabra",
        "calculadora", "reflejos", "convertidor", "mayor_menor",
        "tareas", "dados"
    }
}
local app_roots = {}
for root, names in pairs(app_disk_groups) do
    for _, name in ipairs(names) do
        if app_roots[name] then
            error("La app " .. name .. " fue asignada a mas de un disquete.")
        end
        app_roots[name] = root
    end
end

for _, name in ipairs(app_names) do
    local package = name .. ".app"
    local app_root = app_roots[name]
    if not app_root then
        error("La app " .. name .. " no fue asignada a un disquete.")
    end
    for _, member in ipairs({"main.app", "icon.app"}) do
        local source = "apps/" .. package .. "/" .. member
        files[#files + 1] = {
            source = source,
            root = app_root,
            target = SYSTEM_APPS_DIR .. "/" .. package .. "/" .. member
        }
    end
end

local function stop(message)
    printError(message)
end

local function download_file(path)
    local url = path:match("^https?://") and path or RAW_BASE .. path
    local response, request_error = http.get(url)
    if not response then
        return nil, tostring(request_error or "solicitud HTTP fallida")
    end

    local status, status_text = response.getResponseCode()
    if status and (status < 200 or status >= 300) then
        response.close()
        return nil, "HTTP " .. tostring(status) .. " " .. tostring(status_text or "")
    end

    local contents = response.readAll()
    response.close()
    return contents
end

local function write_file(path, contents)
    local parent = fs.getDir(path)
    if parent ~= "" then
        fs.makeDir(parent)
        if not fs.exists(parent) or not fs.isDir(parent) then
            return false, "No se pudo crear la carpeta /" .. parent
        end
    end

    local file, open_error = fs.open(path, "w")
    if not file then
        return false, tostring(open_error or "no se pudo abrir el archivo")
    end
    file.write(contents)
    file.close()
    return true
end

local function split_basalt(contents)
    local fractions = {0.27, 0.38, 0.75, 1}
    local previous_end = 0
    local chunks = {}
    for index, fraction in ipairs(fractions) do
        local chunk_end = index == #fractions
            and #contents or math.floor(#contents * fraction)
        chunks[index] = contents:sub(previous_end + 1, chunk_end)
        previous_end = chunk_end
    end
    return chunks
end

local function read_running_installer()
    local path = shell.getRunningProgram()
    if not path or path == "" then
        return nil, "No se pudo identificar el archivo installer.lua en ejecucion."
    end

    local file, open_error = fs.open(path, "r")
    if not file then
        return nil, "No se pudo leer el instalador actual: " ..
            tostring(open_error or path)
    end
    local contents = file.readAll()
    file.close()
    return contents
end

if not http or type(http.get) ~= "function" then
    stop("La API HTTP de CC:Tweaked no esta disponible.")
    return
end

for _, directory in ipairs(DISK_ROOTS) do
    if not fs.exists(directory) or not fs.isDir(directory) then
        stop("No se encontro la carpeta /" .. directory ..
            ". Conecta los cuatro disquetes y vuelve a intentarlo.")
        return
    end
end

local boot_path = fs.combine(INSTALL_DIR, "startup.lua")
local boot_source = [[
local original_dir = shell.dir()
shell.setDir("/disk2")
local ok, run_error = shell.run("boot/startup.lua")
shell.setDir(original_dir or "/")
if not ok then
    error("No se pudo iniciar CANDOS desde /disk2/boot: " .. tostring(run_error))
end
]]

local function confirm_installation()
    print("")
    print("CANDOS se instalara asi:")
    print("  /" .. INSTALL_DIR .. "/startup.lua: lanzador de inicio")
    print("  /" .. SYSTEM_ROOT .. "/boot: nucleo y archivos del sistema")
    print("  /" .. APP_DISK_4 .. "/boot: shell y parte de Basalt")
    print("  Basalt y las 30 apps se reparten entre los cuatro disquetes.")
    for _, root in ipairs(DISK_ROOTS) do
        print("  /" .. root .. "/apps: " ..
            #app_disk_groups[root] .. " aplicaciones .app")
    end
    print("  /" .. SYSTEM_ROOT .. "/" .. SYSTEM_FILES_DIR .. ": archivos del usuario")
    print("  /" .. INSTALL_DIR .. "/installer.lua: instalador para actualizar")
    print("Los documentos y las apps personales existentes se conservaran.")
    print("Las apps antiguas incluidas se respaldaran antes de empaquetarse.")
    write("Escribe INSTALAR para continuar: ")
    return read() == "INSTALAR"
end

if not confirm_installation() then
    stop("Instalacion cancelada.")
    return
end

local downloaded = {}
for index, entry in ipairs(files) do
    write(string.format("[%d/%d] Descargando %s ... ", index, #files, entry.source))
    local contents, download_error = download_file(entry.url or entry.source)
    if not contents then
        print("fallo")
        stop("No se pudo descargar " .. entry.source .. ": " .. download_error ..
            "\nNo se escribieron archivos. Comprueba la conexion y vuelve a intentarlo.")
        return
    else
        if entry.split_basalt then
            for part, chunk in ipairs(split_basalt(contents)) do
                local root = DISK_ROOTS[part]
                downloaded[#downloaded + 1] = {
                    target = fs.combine(root, SYSTEM_BOOT_DIR,
                        "lib/basalt/part" .. part .. ".lua"),
                    contents = chunk,
                    source = "Basalt parte " .. part .. "/4"
                }
            end
        else
            downloaded[#downloaded + 1] = {
                target = fs.combine(entry.root, entry.target),
                contents = contents,
                source = entry.source,
                preserve_existing = entry.preserve_existing
            }
        end
        print("OK")
    end

end

local legacy_basalt = fs.combine(SYSTEM_ROOT, SYSTEM_BOOT_DIR,
    "lib/basalt.lua")
if fs.exists(legacy_basalt) and not fs.isDir(legacy_basalt) then
    fs.delete(legacy_basalt)
    if fs.exists(legacy_basalt) then
        stop("No se pudo liberar el Basalt antiguo en /" .. legacy_basalt ..
            ". Libera ese archivo y vuelve a ejecutar el instalador.")
        return
    end
end

for _, directory in ipairs({
    SYSTEM_APPS_DIR, SYSTEM_FILES_DIR, SYSTEM_BOOT_DIR
}) do
    local path = fs.combine(SYSTEM_ROOT, directory)
    fs.makeDir(path)
    if not fs.exists(path) or not fs.isDir(path) then
        stop("No se pudo preparar la carpeta del sistema /" .. path)
        return
    end
end

local legacy_imports = fs.combine(SYSTEM_ROOT, "importing.txt")
local boot_imports = fs.combine(SYSTEM_ROOT, SYSTEM_BOOT_DIR .. "/importing.txt")
if fs.exists(legacy_imports) and not fs.exists(boot_imports) then
    local legacy_file, legacy_error = fs.open(legacy_imports, "r")
    if not legacy_file then
        stop("No se pudo conservar importing.txt anterior: " ..
            tostring(legacy_error or legacy_imports))
        return
    end
    local legacy_contents = legacy_file.readAll()
    legacy_file.close()
    local migrated, migration_error = write_file(boot_imports, legacy_contents)
    if not migrated then
        stop("No se pudo migrar importing.txt a /" .. boot_imports .. ": " ..
            tostring(migration_error))
        return
    end
end

local legacy_apps_dir = fs.combine(".candOS", "legacy-apps")
for _, name in ipairs(app_names) do
    local app_root = app_roots[name]
    local package_path = fs.combine(app_root, SYSTEM_APPS_DIR,
        name .. ".app")
    if fs.exists(package_path) and not fs.isDir(package_path) then
        local app_backup_dir = fs.combine(app_root, legacy_apps_dir)
        local backup_path = fs.combine(app_backup_dir, name .. ".app")
        fs.makeDir(app_backup_dir)
        if not fs.exists(app_backup_dir) or not fs.isDir(app_backup_dir) then
            stop("No se pudo preparar el respaldo de apps antiguas en /" ..
                app_backup_dir)
            return
        end
        if fs.exists(backup_path) then
            stop("Ya existe un respaldo de la app antigua /" .. backup_path ..
                "; no se sobrescribio.")
            return
        end
        local moved, move_error = pcall(fs.move, package_path, backup_path)
        if not moved or not fs.exists(backup_path) or fs.exists(package_path) then
            stop("No se pudo respaldar la app antigua /" .. package_path ..
                ": " .. tostring(move_error or "movimiento incompleto"))
            return
        end
        fs.makeDir(package_path)
        if not fs.exists(package_path) or not fs.isDir(package_path) then
            stop("No se pudo convertir /" .. package_path ..
                " en un paquete de app; el respaldo permanece en /" .. backup_path)
            return
        end
    end
end

local installer_source, installer_error = read_running_installer()
if not installer_source then
    stop(installer_error .. "\nNo se escribieron archivos.")
    return
end

downloaded[#downloaded + 1] = {
    target = fs.combine(INSTALL_DIR, "installer.lua"),
    contents = installer_source,
    source = "installer.lua",
    preserve_existing = false
}

downloaded[#downloaded + 1] = {
    target = boot_path,
    contents = boot_source,
    source = "lanzador de inicio",
    preserve_existing = false
}

for index, entry in ipairs(downloaded) do
    if entry.preserve_existing and fs.exists(entry.target) then
        print("Se conserva la configuracion existente: /" .. entry.target)
    else
        local ok, write_error = write_file(entry.target, entry.contents)
        if not ok then
            stop("Error al instalar " .. entry.source .. " en /" .. entry.target ..
                ": " .. tostring(write_error) ..
                "\nLa instalacion quedo incompleta; vuelve a ejecutar installer.lua para reintentar.")
            return
        end
        print(string.format("[%d/%d] Instalado: /%s", index, #downloaded, entry.target))
    end
end

print("")
print("CANDOS se instalo correctamente.")
print("El sistema esta en /" .. SYSTEM_ROOT .. "/" .. SYSTEM_BOOT_DIR .. ".")
print("Las 30 apps y Basalt estan repartidos entre /disk, /disk2, /disk3 y /disk4.")
print("Tus archivos nuevos se guardan en /" .. SYSTEM_ROOT .. "/" ..
    SYSTEM_FILES_DIR .. ".")
print("Las apps antiguas reemplazadas se respaldan en /.candOS/legacy-apps de cada disquete.")
print("El inicio y el actualizador estan en /" .. INSTALL_DIR .. ".")
print("Para actualizar, vuelve a ejecutar /" .. INSTALL_DIR .. "/installer.lua.")
