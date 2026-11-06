local arguments = {...}
local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()

graphics.clear(colors.black)
graphics.text(2, 1, "BIENVENIDO A CANDOS", colors.white, colors.blue, width - 8)
graphics.panel(4, 5, width - 8, 11, "Hola", colors.white, colors.gray)
graphics.centerText(9, "Tu sistema ya esta listo.", colors.white, colors.gray)
if #arguments > 0 then
    graphics.centerText(12, table.concat(arguments, " "), colors.lightBlue, colors.gray)
else
    graphics.centerText(12, "Abre una app desde Inicio.", colors.lightBlue, colors.gray)
end
graphics.button(math.floor((width - 14) / 2), height - 3, 14,
    "VOLVER", colors.blue)

while true do
    local event, side, _, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side
        and y == height - 3 then
        break
    end
end
