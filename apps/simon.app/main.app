local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local buttons = {
    {label = "ROJO", color = colors.red},
    {label = "VERDE", color = colors.green},
    {label = "AZUL", color = colors.blue},
    {label = "AMARILLO", color = colors.yellow}
}
local sequence, position, score, message = {}, 1, 0, "Toca EMPEZAR y repite la secuencia."
local started = false

local function add_step()
    sequence[#sequence + 1] = math.random(1, #buttons)
    position = 1
    started = true
    message = "Repite " .. #sequence .. " color(es)."
end

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "SIMON", colors.white, colors.blue, width - 8)
    graphics.panel(3, 4, width - 6, 5, "Secuencia", colors.white, colors.gray)
    local shown = {}
    for index, color_index in ipairs(sequence) do shown[index] = buttons[color_index].label end
    graphics.centerText(6, #shown > 0 and table.concat(shown, " - ") or "Lista",
        colors.white, colors.gray)
    graphics.text(3, 10, "Ronda: " .. #sequence .. " | Puntos: " .. score,
        colors.lightGray)
    local button_width = math.floor((width - 2) / 4)
    for index, button in ipairs(buttons) do
        graphics.button(2 + (index - 1) * button_width, 14,
            button_width, button.label, button.color)
    end
    graphics.text(3, height - 3, message, colors.lightGray, colors.black, width - 6)
    graphics.button(3, height, width - 5, "EMPEZAR / REINICIAR", colors.gray)
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side then
        if y == height then
            sequence, score, started = {}, 0, false
            add_step()
        elseif y == 14 and started then
            local index = math.min(4, math.floor((x - 2) / button_width) + 1)
            if index == sequence[position] then
                position = position + 1
                if position > #sequence then
                    score = score + #sequence
                    message = "Correcto! Memoriza la nueva secuencia."
                    add_step()
                else
                    message = "Bien. Continua con el siguiente color."
                end
            else
                message = "Incorrecto! Toca EMPEZAR para volver a intentar."
                sequence, started = {}, false
            end
        end
    end
end
