local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local state, timer_id, started_at = "listo", nil, 0
local message = "Toca PREPARAR y espera la senal."
local best

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "PRUEBA DE REFLEJOS", colors.white, colors.blue, width - 8)
    graphics.panel(4, 6, width - 8, 9, "Pulsa cuando cambie a VERDE",
        colors.white, state == "senal" and colors.green or colors.gray)
    graphics.centerText(10, state == "senal" and "AHORA!" or "ESPERA...",
        colors.white, state == "senal" and colors.green or colors.gray)
    graphics.text(4, 17, message, colors.lightGray)
    graphics.text(4, 19, "Mejor: " .. (best and string.format("%.3f s", best) or "--"),
        colors.yellow)
    graphics.button(4, height - 3, 20, "PREPARAR", colors.blue)
    graphics.button(width - 21, height - 3, 18, "CERRAR", colors.red)
    local event, side, x, y = os.pullEvent()
    if event == "timer" and timer_id == x and state == "espera" then
        state = "senal"
        started_at = os.clock()
        timer_id = nil
    elseif event == "monitor_touch" and side == candOS.monitor_side then
        if y == height - 3 and x >= width - 21 then
            if timer_id then os.cancelTimer(timer_id) end
            break
        elseif y == height - 3 and x < 24 then
            if timer_id then os.cancelTimer(timer_id) end
            state = "espera"
            message = "Preparate..."
            timer_id = os.startTimer(math.random(15, 50) / 10)
        elseif state == "senal" then
            local elapsed = os.clock() - started_at
            if not best or elapsed < best then best = elapsed end
            state = "listo"
            message = string.format("Tu tiempo: %.3f segundos.", elapsed)
        elseif state == "espera" then
            state = "listo"
            if timer_id then os.cancelTimer(timer_id) end
            timer_id = nil
            message = "Demasiado pronto! Toca PREPARAR."
        end
    end
end
