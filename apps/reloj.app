local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()

while true do
    graphics.clear(colors.black)
    graphics.text(2, 1, "RELOJ", colors.white, colors.blue, width - 8)
    graphics.panel(4, 5, width - 8, 10, "Hora del computador",
        colors.white, colors.gray)
    graphics.centerText(9, os.date("%H:%M:%S"), colors.white, colors.gray)
    graphics.centerText(12, os.date("%d/%m/%Y"), colors.lightGray, colors.gray)
    graphics.text(3, height - 2, "Se actualiza cada segundo.", colors.lightGray)
    local timer = os.startTimer(1)
    local event, timer_id = os.pullEvent("timer")
    if event == "timer" and timer_id ~= timer then
        os.cancelTimer(timer_id)
    end
end
