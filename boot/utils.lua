-- Herramientas de diagnostico para CC: Tweaked.

local function format_bytes(bytes)
    if bytes >= 1073741824 then
        return string.format("%.2f GB", bytes / 1073741824)
    elseif bytes >= 1048576 then
        return string.format("%.2f MB", bytes / 1048576)
    elseif bytes >= 1024 then
        return string.format("%.2f KB", bytes / 1024)
    end
    return string.format("%d bytes", math.floor(bytes))
end

local function check_hardware()
    print("=== Perifericos CC: Tweaked ===")

    local monitor = peripheral.find("monitor")
    if monitor then
        local width, height = monitor.getSize()
        print("Monitor: " .. width .. "x" .. height .. " caracteres")
    else
        print("Monitor: no detectado")
    end

    for _, side in ipairs({"left", "right"}) do
        if peripheral.getType(side) == "drive" then
            local drive = peripheral.wrap(side)
            local mount = drive.getMountPath()
            print(side .. ": lectora conectada; " ..
                (mount and ("disco de datos en " .. mount) or "sin disco de datos montado"))
        else
            print(side .. ": lectora no detectada")
        end
    end

    if peripheral.getType("back") == "speaker" then
        print("Speaker: conectado atras")
    elseif peripheral.find("speaker") then
        print("Speaker: conectado en otro lado")
    else
        print("Speaker: no detectado")
    end

    local label = os.getComputerLabel()
    print("Computador: " .. (label or tostring(os.getComputerID())))
    print("")
end

local function run(command, value)
    if command == "hw" then
        check_hardware()
    elseif command == "format" then
        local bytes = tonumber(value)
        if not bytes or bytes < 0 then
            print("Uso: format <bytes>")
        else
            print("Tamano: " .. format_bytes(bytes))
        end
    elseif command == "reset" then
        term.clear()
        term.setCursorPos(1, 1)
    elseif command == "help" then
        print("Uso: utils.lua hw | format <bytes> | reset | exit")
    else
        print("Comando desconocido. Escribe 'help'.")
    end
end

local command, value = ...
if command then
    run(command:lower(), value)
else
    print("Utilidades CC: Tweaked. Comandos: hw, format <bytes>, reset, exit")
    while true do
        write("utils> ")
        local words = {}
        for word in read():gmatch("%S+") do
            words[#words + 1] = word
        end
        if words[1] == "exit" then
            break
        end
        run((words[1] or ""):lower(), words[2])
    end
end
