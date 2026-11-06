local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local card = math.random(1, 13)
local score = 0
local message = "Adivina si la siguiente carta sera mayor o menor."
local finished = false

local function card_name(value)
    local faces = {[1] = "AS", [11] = "J", [12] = "Q", [13] = "K"}
    return faces[value] or tostring(value)
end

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "MAYOR O MENOR", colors.white, colors.blue, width - 8)
    graphics.panel(5, 5, width - 10, 10, "Carta actual",
        colors.white, colors.gray)
    graphics.centerText(10, card_name(card), colors.yellow, colors.gray)
    graphics.text(4, 17, message, colors.lightGray, colors.black, width - 8)
    graphics.text(4, 19, "Puntos: " .. score, colors.white)
    graphics.button(4, height - 3, 18, "MAYOR", colors.green)
    graphics.button(width - 21, height - 3, 18, "MENOR", colors.blue)
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height - 3 then
        if finished then
            card, score, finished = math.random(1, 13), 0, false
            message = "Nueva partida."
        else
            local guess = x < width / 2 and "mayor" or "menor"
            local next_card = math.random(1, 13)
            if next_card == card then
                message = "Mismo valor; turno neutral."
            elseif (next_card > card and guess == "mayor")
                or (next_card < card and guess == "menor") then
                score = score + 1
                message = "Correcto! Siguiente carta: " .. card_name(next_card)
            else
                message = "Fin de la ronda. Toca para reiniciar."
                finished = true
            end
            card = next_card
        end
    end
end
