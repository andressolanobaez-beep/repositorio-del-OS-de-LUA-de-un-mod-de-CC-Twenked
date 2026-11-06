local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local first, second = 1, 1
local rolls = 0

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "DADOS", colors.white, colors.blue, width - 8)
    graphics.panel(4, 6, width - 8, 10, "Lanzamiento", colors.white, colors.gray)
    graphics.centerText(10, "[" .. first .. "]     [" .. second .. "]",
        colors.white, colors.gray)
    graphics.text(4, 18, "Suma: " .. (first + second) .. " | Tiradas: " .. rolls,
        colors.lightGray)
    graphics.button(4, height - 3, 18, "TIRAR", colors.green)
    graphics.button(width - 19, height - 3, 17, "CERRAR", colors.red)
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height - 3 then
        if x < 23 then
            first, second = math.random(1, 6), math.random(1, 6)
            rolls = rolls + 1
        else
            break
        end
    end
end
