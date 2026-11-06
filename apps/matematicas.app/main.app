local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local score, answer, question = 0, 0, ""
local message = "Toca NUEVA para comenzar."

local function new_question()
    local a, b = math.random(2, 20), math.random(2, 12)
    local operation = math.random(1, 3)
    if operation == 1 then
        answer, question = a + b, a .. " + " .. b
    elseif operation == 2 then
        answer, question = a * b, a .. " x " .. b
    else
        answer, question = a, (a * b) .. " / " .. b
    end
end

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "RETO MATEMATICO", colors.white, colors.blue, width - 8)
    graphics.panel(4, 6, width - 8, 8, "Resuelve", colors.white, colors.gray)
    graphics.centerText(10, question, colors.yellow, colors.gray)
    graphics.text(4, 17, message, colors.lightGray)
    graphics.text(4, 19, "Aciertos: " .. score, colors.white)
    graphics.button(4, height - 3, 20, "RESPONDER", colors.green)
    graphics.button(width - 21, height - 3, 18, "NUEVA", colors.blue)
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height - 3 then
        if x < width / 2 then
            if question == "" then
                message = "Primero toca NUEVA."
            else
                local guess = tonumber(input(question .. " = ?", "", "number"))
                if guess == answer then
                    score = score + 1
                    message = "Correcto! Muy bien."
                else
                    message = "La respuesta era " .. answer .. "."
                end
            end
        else
            new_question()
            message = "Resuelve la operacion."
        end
    end
end
