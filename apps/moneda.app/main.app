local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local face = "Toca LANZAR"
local heads, tails = 0, 0

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "CARA O CRUZ", colors.white, colors.blue, width - 8)
    graphics.panel(5, 6, width - 10, 10, "Moneda", colors.white, colors.gray)
    graphics.centerText(10, face, colors.yellow, colors.gray)
    graphics.text(5, 18, "Cara: " .. heads .. "     Cruz: " .. tails, colors.lightGray)
    graphics.button(4, height - 3, 18, "LANZAR", colors.green)
    graphics.button(width - 19, height - 3, 17, "CERRAR", colors.red)
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height - 3 then
        if x < 23 then
            face = math.random(0, 1) == 0 and "CARA" or "CRUZ"
            if face == "CARA" then heads = heads + 1 else tails = tails + 1 end
        else
            break
        end
    end
end
