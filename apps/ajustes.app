local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local config = shell.resolve("/.candOS")
local role_file = fs.combine(config, "role.txt")
local roles = {"auxiliar", "nucleo", "pantalla"}
local role = "auxiliar"
local message = "Define el papel de esta PC en tu red local."

local file = fs.open(role_file, "r")
if file then
    role = file.readAll():match("^%s*(.-)%s*$")
    file.close()
    if role == "" then
        role = "auxiliar"
    end
end

while true do
    local monitors = candOS.getMonitors()
    graphics.clear(colors.black)
    graphics.text(2, 2, "AJUSTES DEL SISTEMA", colors.white, colors.blue, width - 8)
    graphics.panel(3, 4, width - 6, 6, "Papel de esta computadora",
        colors.white, colors.gray)
    graphics.centerText(7, "Rol actual: " .. role, colors.white, colors.gray)
    graphics.text(3, 12, "Pantallas conectadas: " .. #monitors, colors.lightGray)
    local row = 14
    for _, screen in ipairs(monitors) do
        graphics.button(3, row, width - 6,
            screen.name .. " | " .. screen.width .. "x" .. screen.height ..
                (screen.primary and " | PRINCIPAL" or " | tocar para elegir"),
            screen.primary and colors.green or colors.gray)
        row = row + 2
    end
    graphics.text(3, height - 4, message, colors.lightGray, colors.black, width - 6)
    local button_width = math.max(1, math.floor((width - 2) / 3))
    graphics.button(2, height, button_width, "CAMBIAR ROL", colors.blue)
    graphics.button(2 + button_width, height, button_width, "RECARGAR", colors.gray)
    graphics.button(2 + button_width * 2, height, width, "CERRAR", colors.red)

    local event, side, x, y = os.pullEvent()
    if event == "peripheral" or event == "peripheral_detach"
        or event == "monitor_resize" then
        width, height = monitor.getSize()
        message = "Dispositivos actualizados."
    elseif event == "monitor_touch" and side == candOS.monitor_side then
        if y == height then
            if x < 2 + button_width then
                local index = 1
                for position, candidate in ipairs(roles) do
                    if candidate == role then
                        index = position % #roles + 1
                    end
                end
                role = roles[index]
                fs.makeDir(config)
                file = fs.open(role_file, "w")
                if file then
                    file.write(role)
                    file.close()
                    message = "Rol guardado: " .. role
                else
                    message = "No se pudo guardar el rol."
                end
            elseif x < 2 + button_width * 2 then
                message = "Lista actualizada."
            else
                break
            end
        elseif y >= 14 and y < 14 + #monitors * 2 then
            local index = math.floor((y - 14) / 2) + 1
            local screen = monitors[index]
            if screen then
                fs.makeDir(config)
                file = fs.open(shell.resolve("/.candOS/display.txt"), "w")
                if file then
                    file.write(screen.name)
                    file.close()
                    message = screen.name .. " sera principal despues de reiniciar."
                else
                    message = "No se pudo guardar la pantalla."
                end
            end
        end
    end
end
