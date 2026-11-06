local REPOSITORY = "andressolanobaez-beep/repositorio-del-OS-de-LUA-de-un-mod-de-CC-Twenked"
local BRANCH = "main"
local RAW_BASE = "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. BRANCH .. "/"
local SYSTEM_APPS_DIR = "apps/candos"

local files = {
    {source = "startup.lua", target = "startup.lua"},
    {source = "shell.py", target = "shell.py"},
    {source = "utils.lua", target = "utils.lua"},
    {source = "disk_manager.lua", target = "disk_manager.lua"},
    {source = "buzzer.lua", target = "buzzer.lua"},
    {source = "importing.txt", target = "importing.txt", preserve_existing = true},
    {source = "apps/archivador.app", target = SYSTEM_APPS_DIR .. "/archivador.app"},
    {source = "apps/hardware.app", target = SYSTEM_APPS_DIR .. "/hardware.app"},
    {source = "apps/hola.app", target = SYSTEM_APPS_DIR .. "/hola.app"},
    {source = "apps/notas.app", target = SYSTEM_APPS_DIR .. "/notas.app"},
    {source = "apps/terminal.app", target = SYSTEM_APPS_DIR .. "/terminal.app"},
    {source = "installer.lua", target = "installer.lua", optional = true}
}

local function stop(message)
    printError(message)
end

local function mounted_drives()
    local drives = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "drive" then
            local drive = peripheral.wrap(name)
            if drive then
                local ok, mount = pcall(drive.getMountPath)
                if ok and type(mount) == "string" and mount ~= "" then
                    drives[#drives + 1] = {
                        name = name,
                        mount = fs.combine(mount)
                    }
                elseif not ok then
                    print("Aviso: no se pudo consultar la unidad " .. name .. ": " ..
                        tostring(mount))
                end
            end
        end
    end
    return drives
end

local function choose_drive(drives)
    if #drives == 0 then
        return nil, "No hay discos montados. Inserta un disco en una disquetera y vuelve a ejecutar el instalador."
    end

    print("Discos montados:")
    for index, drive in ipairs(drives) do
        print(string.format("  %d) %s -> /%s", index, drive.name, drive.mount))
    end
    write("Numero del disco destino (q para cancelar): ")
    local choice = read()
    if choice:lower() == "q" then
        return nil, "Instalacion cancelada."
    end

    local index = tonumber(choice)
    if not index or index % 1 ~= 0 or not drives[index] then
        return nil, "Seleccion invalida; vuelve a ejecutar el instalador."
    end
    return drives[index]
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

if not http or type(http.get) ~= "function" then
    stop("La API HTTP de CC:Tweaked no esta disponible.")
    return
end

local drives = mounted_drives()
local selected, selection_error = choose_drive(drives)
if not selected then
    stop(selection_error)
    return
end

if not fs.exists(selected.mount) or not fs.isDir(selected.mount) then
    stop("La ruta montada no existe o no es una carpeta: /" .. selected.mount)
    return
end

print("")
print("Se instalara CANDOS en /" .. selected.mount)
print("Los archivos del sistema se actualizaran; no se borraran documentos.")
print("Las apps del sistema se guardaran en /" .. selected.mount .. "/" .. SYSTEM_APPS_DIR)
write("Escribe INSTALAR para continuar: ")
if read() ~= "INSTALAR" then
    stop("Instalacion cancelada.")
    return
end

local downloaded = {}
for index, entry in ipairs(files) do
    write(string.format("[%d/%d] Descargando %s ... ", index, #files, entry.source))
    local contents, download_error = download_file(entry.source)
    if not contents then
        if entry.optional then
            print("omitido: " .. download_error)
        else
            print("fallo")
            stop("No se pudo descargar " .. entry.source .. ": " .. download_error ..
                "\nNo se escribieron archivos. Comprueba la conexion y vuelve a intentarlo.")
            return
        end
    else
        downloaded[#downloaded + 1] = {
            target = fs.combine(selected.mount, entry.target),
            contents = contents,
            source = entry.source
        }
        print("OK")
    end
end

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
print("CANDOS se instalo correctamente en /" .. selected.mount .. ".")
print("Tus documentos y las apps que ya tenias no se eliminaron.")
print("Para iniciarlo ahora, cambia a esa unidad con 'cd " .. selected.mount ..
    "' y ejecuta 'startup.lua'.")
print("Para actualizarlo, vuelve a ejecutar installer.lua con el disco conectado.")
