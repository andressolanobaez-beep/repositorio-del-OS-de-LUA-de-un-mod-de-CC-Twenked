--[[
  Utilidades varias para CC: Tweaked
  Funciones auxiliares para el sistema ESPAndOS adaptado
--]]

-- Verificar si un peripheral existe
local function has_peripheral(name)
    return peripheral.find(name) ~= nil
end

-- Obtener label del computador
local function get_computer_label()
    return os.getComputerLabel() or "Computador CC:Tweaked"
end

-- Formatear bytes a tamaño legible
local function format_bytes(bytes)
    if bytes >= 1073741824 then
        return string.format("%.2f GB", bytes / 1073741824)
    elseif bytes >= 1048576 then
        return string.format("%.2f MB", bytes / 1048576)
    elseif bytes >= 1024 then
        return string.format("%.2f KB", bytes / 1024)
    else
        return bytes .. " bytes"
    end
end

-- Esperar una tecla con timeout opcional
local function wait_key(timeout)
    local start = os.clock()
    while true do
        local event = os.pullEvent("key")
        return true
        if timeout and (os.clock() - start) > timeout then
            return false
        end
    end
end

-- Limpiar todo y mostrar banner
local function reset_system()
    clear_screen()
    show_banner()
end

-- Verificar estado del hardware
local function check_hardware()
    cprint "=== Estado del Hardware ==="
    cprint "Monitor: " .. (monitor and "✓" or "✗")
    cprint "Speaker: " .. (speaker and "✓" or "✗")
    
    local disks = 0
    for _, side in ipairs({"left", "right"}) do
        if peripheral.isPresent(side) then
            disks = disks + 1
        end
    end
    cprint "Disqueteras: " .. disks .. "/2"
    
    cprint "Computador: " .. get_computer_label()
    cprint ""
end

-- Programa principal
cprint "=== Utilidades CC: Tweaked ==="
cprint ""

-- Menú
while true do
    cprint "Comandos:"
    cprint "  hw    - Ver estado del hardware"
    cprint "  reset - Reiniciar configuración (banner)"
    cprint "  format <bytes> - Mostrar tamaño formateado (ej: format 1048576)"
    cprint "  exit - Salir"
    cprint ""
    
    local cmd = read():gsub("^%s*(.-)%s*$", "%1")
    
    if cmd == "hw" then
        check_hardware()
    elseif cmd == "reset" then
        reset_system()
    elseif cmd:sub(1, 6) == "format" then
        local size = tonumber(cmd:sub(7):gsub("^%s*(.-)%s*$", "%1"))
        if size then
            cprint "Tamaño: " .. format_bytes(size)
        else
            cprint "Uso: format <tamaño_en_bytes>"
        end
    elseif cmd == "exit" then
        break
    else
        cprint "Comando no reconocido"
    end
end