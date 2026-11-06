local REPOSITORY = "andressolanobaez-beep/repositorio-del-OS-de-LUA-de-un-mod-de-CC-Twenked"
local REVISION = "d1df505657492b8f5916f68f7b66c5c57db70e1a"
local RAW_BASE = "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. REVISION .. "/"
local BASALT_REVISION = "14c0630c1e110c5b507534e19e6c9607ba10df3e"
local BASALT_BASE = "https://raw.githubusercontent.com/Pyroxenium/Basalt/" ..
    BASALT_REVISION .. "/"
local INSTALL_DIR = "disk"
local SYSTEM_ROOT = "disk2"
local SYSTEM_APPS_DIR = "apps"
local SYSTEM_BOOT_DIR = "boot"
local SYSTEM_FILES_DIR = "files"

local files = {
    {source = "boot/startup.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/startup.lua"},
    {source = "boot/shell.py", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/shell.py"},
    {source = "boot/utils.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/utils.lua"},
    {source = "boot/disk_manager.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/disk_manager.lua"},
    {source = "boot/buzzer.lua", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/buzzer.lua"},
    {source = "boot/importing.txt", root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/importing.txt", preserve_existing = true},
    {source = "basalt-1.6.6.lua", url = BASALT_BASE .. "docs/versions/basalt-1.6.6.lua",
        root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/lib/basalt.lua"},
    {source = "Basalt-MIT-LICENSE.txt", url = BASALT_BASE .. "LICENSE",
        root = SYSTEM_ROOT, target = SYSTEM_BOOT_DIR .. "/licenses/Basalt-MIT-LICENSE.txt"}
}

local app_names = {
    "adivina", "ajustes", "archivador", "bloc", "calculadora", "calendario",
    "candos_fps", "carrera", "convertidor", "dados", "dispositivos", "hardware",
    "hola", "matematicas", "mayor_menor", "memoria", "moneda", "notas",
    "palabra", "pong", "ppt", "quiz", "red", "reflejos", "reloj", "simon",
    "tareas", "temporizador", "terminal", "tres_en_raya"
}

for _, name in ipairs(app_names) do
    local package = name .. ".app"
    for _, member in ipairs({"main.app", "icon.app"}) do
        local source = "apps/" .. package .. "/" .. member
        files[#files + 1] = {
            source = source,
            root = SYSTEM_ROOT,
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

for _, directory in ipairs({INSTALL_DIR, SYSTEM_ROOT}) do
    if not fs.exists(directory) or not fs.isDir(directory) then
        stop("No se encontro la carpeta /" .. directory ..
            ". Conecta las unidades de instalacion y almacenamiento y vuelve a intentarlo.")
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
    print("  /" .. SYSTEM_ROOT .. "/boot: sistema operativo y librerias")
    print("  /" .. SYSTEM_ROOT .. "/apps: aplicaciones en carpetas .app")
    print("  /" .. SYSTEM_ROOT .. "/" .. SYSTEM_FILES_DIR .. ": archivos del usuario")
    print("  /" .. INSTALL_DIR .. "/installer.lua: instalador para actualizar")
    print("La BIOS en /disk3 no se consulta ni se modifica.")
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
        downloaded[#downloaded + 1] = {
            target = fs.combine(entry.root, entry.target),
            contents = contents,
            source = entry.source,
            preserve_existing = entry.preserve_existing
        }
        print("OK")
    end

end

for _, directory in ipairs({
    SYSTEM_APPS_DIR, SYSTEM_FILES_DIR, SYSTEM_BOOT_DIR,
    SYSTEM_BOOT_DIR .. "/lib", SYSTEM_BOOT_DIR .. "/licenses"
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

local legacy_apps_dir = fs.combine(SYSTEM_ROOT, ".candOS/legacy-apps")
for _, name in ipairs(app_names) do
    local package_path = fs.combine(SYSTEM_ROOT, SYSTEM_APPS_DIR,
        name .. ".app")
    if fs.exists(package_path) and not fs.isDir(package_path) then
        local backup_path = fs.combine(legacy_apps_dir, name .. ".app")
        fs.makeDir(legacy_apps_dir)
        if not fs.exists(legacy_apps_dir) or not fs.isDir(legacy_apps_dir) then
            stop("No se pudo preparar el respaldo de apps antiguas en /" ..
                legacy_apps_dir)
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
print("Tus apps estan en /" .. SYSTEM_ROOT .. "/" .. SYSTEM_APPS_DIR .. ".")
print("Tus archivos nuevos se guardan en /" .. SYSTEM_ROOT .. "/" ..
    SYSTEM_FILES_DIR .. ".")
print("Las apps antiguas reemplazadas se respaldan en /" ..
    SYSTEM_ROOT .. "/.candOS/legacy-apps.")
print("El inicio y el actualizador estan en /" .. INSTALL_DIR .. ".")
print("La BIOS en /disk3 no se modifico.")
print("Para actualizar, vuelve a ejecutar /" .. INSTALL_DIR .. "/installer.lua.")
