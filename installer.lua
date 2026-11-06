local REPOSITORY = "andressolanobaez-beep/repositorio-del-OS-de-LUA-de-un-mod-de-CC-Twenked"
local REVISION = "b07b57a84395ccb72d9d6898b55a44a3b143fcf0"
local RAW_BASE = "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. REVISION .. "/"
local INSTALL_DIR = "disk"
local SYSTEM_ROOT = "disk2"
local SYSTEM_APPS_DIR = "apps/candos"

local files = {
    {source = "startup.lua", root = SYSTEM_ROOT, target = "startup.lua"},
    {source = "shell.py", root = SYSTEM_ROOT, target = "shell.py"},
    {source = "utils.lua", root = SYSTEM_ROOT, target = "utils.lua"},
    {source = "disk_manager.lua", root = SYSTEM_ROOT, target = "disk_manager.lua"},
    {source = "buzzer.lua", root = SYSTEM_ROOT, target = "buzzer.lua"},
    {source = "importing.txt", root = SYSTEM_ROOT, target = "importing.txt", preserve_existing = true},
    {source = "apps/archivador.app", root = SYSTEM_ROOT, target = SYSTEM_APPS_DIR .. "/archivador.app"},
    {source = "apps/hardware.app", root = SYSTEM_ROOT, target = SYSTEM_APPS_DIR .. "/hardware.app"},
    {source = "apps/hola.app", root = SYSTEM_ROOT, target = SYSTEM_APPS_DIR .. "/hola.app"},
    {source = "apps/notas.app", root = SYSTEM_ROOT, target = SYSTEM_APPS_DIR .. "/notas.app"},
    {source = "apps/terminal.app", root = SYSTEM_ROOT, target = SYSTEM_APPS_DIR .. "/terminal.app"}
}

local function stop(message)
    printError(message)
end

local function download_file(path)
    local url = RAW_BASE .. path
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
local ok, run_error = shell.run("startup.lua")
shell.setDir(original_dir or "/")
if not ok then
    error("No se pudo iniciar CANDOS desde /disk2: " .. tostring(run_error))
end
]]

local function confirm_installation()
    print("")
    print("CANDOS se instalara asi:")
    print("  /" .. INSTALL_DIR .. "/startup.lua: lanzador de inicio")
    print("  /" .. SYSTEM_ROOT .. "/: sistema, aplicaciones y almacenamiento")
    print("  /" .. INSTALL_DIR .. "/installer.lua: instalador para actualizar")
    print("La BIOS en /disk3 no se consulta ni se modifica.")
    print("Los documentos y las apps personales existentes se conservaran.")
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
    local contents, download_error = download_file(entry.source)
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
print("El sistema y las apps estan en /" .. SYSTEM_ROOT .. ".")
print("El inicio y el actualizador estan en /" .. INSTALL_DIR .. ".")
print("La BIOS en /disk3 no se modifico.")
print("Para actualizar, vuelve a ejecutar /" .. INSTALL_DIR .. "/installer.lua.")
