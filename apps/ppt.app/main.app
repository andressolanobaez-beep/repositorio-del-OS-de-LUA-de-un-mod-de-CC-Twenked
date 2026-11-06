local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local choices = {"PIEDRA", "PAPEL", "TIJERA"}
local icons = {"[O]", "[=]", "[X]"}
local score = {0, 0, 0}
local result = "Elige tu jugada."

local function play(index)
    local computer = math.random(1, 3)
    if index == computer then
        result = "Empate: ambos " .. choices[index]
    elseif (index == 1 and computer == 3)
        or (index == 2 and computer == 1)
        or (index == 3 and computer == 2) then
        score[1] = score[1] + 1
        result = choices[index] .. " vence a " .. choices[computer]
    else
        score[2] = score[2] + 1
        result = choices[computer] .. " vence a " .. choices[index]
    end
    score[3] = score[3] + 1
end

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "PIEDRA, PAPEL O TIJERA", colors.white, colors.blue, width - 8)
    graphics.panel(3, 5, width - 6, 8, "Partida", colors.white, colors.gray)
    graphics.centerText(8, result, colors.white, colors.gray)
    graphics.text(4, 15, "Tu: " .. score[1] .. " | PC: " .. score[2] ..
        " | Jugadas: " .. score[3], colors.lightGray)
    for index, choice in ipairs(choices) do
        graphics.button(2 + (index - 1) * math.floor((width - 2) / 3),
            height - 4, math.floor((width - 2) / 3), icons[index] .. " " .. choice,
            colors.blue)
    end
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height - 4 then
        local index = math.min(3, math.floor((x - 2) / math.floor((width - 2) / 3)) + 1)
        play(index)
    end
end
