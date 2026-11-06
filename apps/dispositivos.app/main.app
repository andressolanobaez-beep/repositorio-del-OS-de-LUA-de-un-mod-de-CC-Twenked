local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local devices = {}
local page = 1
local message = "Se actualiza al conectar o quitar un dispositivo."

local function refresh()
    devices = shell.peripherals()
    local monitors = candOS.getMonitors()
    local monitors_by_name = {}
    for _, screen in ipairs(monitors) do
        monitors_by_name[screen.name] = screen
    end
    for _, device in ipairs(devices) do
        local screen = monitors_by_name[device.name]
        if screen then
            device.width = screen.width
            device.height = screen.height
            device.primary = screen.primary
        end
    end
    table.sort(devices, function(a, b)
        if a.name == b.name then
            return a.type < b.type
        end
        return a.name:lower() < b.name:lower()
    end)
    page = math.max(1, math.min(page,
        math.max(1, math.ceil(#devices / math.max(1, height - 8)))))
end

local function set_primary(name)
    if name == "monitor_1" then
        message = "monitor_1 esta reservado para mensajes de error."
        return
    end
    local file, err = fs.open(shell.resolve("/.candOS/display.txt"), "w")
    if not file then
        message = "No se pudo guardar la pantalla: " .. tostring(err)
        return
    end
    file.write(name)
    file.close()
    message = name .. " sera la pantalla principal al reiniciar."
end

refresh()
while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "CENTRO DE DISPOSITIVOS", colors.white, colors.blue, width - 8)
    graphics.text(2, 3, #devices .. " conexiones detectadas", colors.lightGray)

    local page_size = math.max(1, height - 8)
    local first = (page - 1) * page_size + 1
    for index = first, math.min(first + page_size - 1, #devices) do
        local device = devices[index]
        local detail = device.type
        if device.width then
            detail = detail .. " | " .. device.width .. "x" .. device.height
        end
        if device.type == "drive" then
            local drive = peripheral.wrap(device.name)
            local mount = drive and drive.getMountPath and drive.getMountPath()
            detail = detail .. (mount and (" | /" .. mount) or " | sin disco")
        end
        if device.primary then
            detail = detail .. " | PRINCIPAL"
        end
        graphics.panel(2, 5 + index - first, width - 4, 1, nil,
            colors.white, index % 2 == 0 and colors.gray or colors.black)
        graphics.text(3, 5 + index - first, device.name .. " | " .. detail,
            colors.white, index % 2 == 0 and colors.gray or colors.black, width - 6)
    end
    if #devices == 0 then
        graphics.panel(3, 7, width - 6, 5, "Sin perifericos",
            colors.white, colors.gray)
        graphics.centerText(9, "Conecta discos, pantallas o modems.", colors.lightGray, colors.gray)
    end
    graphics.text(2, height - 3, message, colors.lightGray, colors.black, width - 2)
    graphics.button(2, height, math.floor(width / 3), "ANTERIOR", colors.gray)
    graphics.button(math.floor(width / 3) + 1, height,
        math.floor(width / 3), "SIGUIENTE", colors.blue)
    graphics.button(width - math.floor(width / 3) + 1, height,
        math.floor(width / 3), "CERRAR", colors.red)

    local event, side, x, y = os.pullEvent()
    if event == "peripheral" or event == "peripheral_detach"
        or event == "monitor_resize" then
        refresh()
        width, height = monitor.getSize()
        message = "Dispositivos actualizados."
    elseif event == "monitor_touch" and side == candOS.monitor_side then
        if y == height then
            if x <= math.floor(width / 3) then
                page = math.max(1, page - 1)
            elseif x <= math.floor(width * 2 / 3) then
                page = math.min(math.max(1,
                    math.ceil(#devices / math.max(1, height - 8))), page + 1)
            else
                break
            end
        elseif y >= 5 and y < 5 + page_size then
            local device = devices[(page - 1) * page_size + y - 4]
            if device and device.type == "monitor" then
                set_primary(device.name)
            end
        end
    end
end
