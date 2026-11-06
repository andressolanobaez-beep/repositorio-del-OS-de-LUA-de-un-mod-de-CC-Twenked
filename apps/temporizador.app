local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local remaining = 0
local running = false
local timer_id
local message = "Define minutos para iniciar."

local function start_timer()
    local minutes = tonumber(input("Minutos", "1", "number"))
    if not minutes or minutes <= 0 then
        message = "Escribe un numero positivo."
        return
    end
    remaining = math.floor(minutes * 60)
    running = true
    if timer_id then
        os.cancelTimer(timer_id)
    end
    timer_id = os.startTimer(1)
    message = "Temporizador activo."
end

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "TEMPORIZADOR", colors.white, colors.blue, width - 8)
    graphics.panel(4, 5, width - 8, 10, "Cuenta atras",
        colors.white, colors.gray)
    graphics.centerText(9, string.format("%02d:%02d",
        math.floor(remaining / 60), remaining % 60), colors.white, colors.gray)
    graphics.text(3, height - 5, message, colors.lightGray)
    local button_width = math.max(1, math.floor((width - 2) / 3))
    graphics.button(2, height, button_width, "INICIAR", colors.green)
    graphics.button(2 + button_width, height, button_width, "DETENER", colors.gray)
    graphics.button(2 + button_width * 2, height, width, "CERRAR", colors.red)

    local event, id, x, y = os.pullEvent()
    if event == "timer" and id == timer_id and running then
        remaining = math.max(0, remaining - 1)
        if remaining == 0 then
            running = false
            timer_id = nil
            message = "Tiempo terminado."
            if candOS.speaker then
                candOS.speaker.playSound("block.note_block.bell")
            end
        else
            timer_id = os.startTimer(1)
        end
    elseif event == "monitor_touch" and id == candOS.monitor_side and y == height then
        if x < 2 + button_width then
            start_timer()
        elseif x < 2 + button_width * 2 then
            running = false
            remaining = 0
            if timer_id then
                os.cancelTimer(timer_id)
                timer_id = nil
            end
            message = "Temporizador detenido."
        else
            if timer_id then
                os.cancelTimer(timer_id)
            end
            break
        end
    end
end
