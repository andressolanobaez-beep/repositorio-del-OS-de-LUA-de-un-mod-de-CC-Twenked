local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local symbols = {"A", "B", "C", "D", "E", "F", "G", "H"}
local cards = {}
for _, symbol in ipairs(symbols) do
    cards[#cards + 1] = symbol
    cards[#cards + 1] = symbol
end
for index = #cards, 2, -1 do
    local other = math.random(1, index)
    cards[index], cards[other] = cards[other], cards[index]
end
local revealed, matched = {}, {}
local first, moves, message = nil, 0, "Toca dos tarjetas para buscar parejas."
local mismatch = false

local function draw()
    graphics.clear(colors.black)
    graphics.text(2, 2, "MEMORIA", colors.white, colors.blue, width - 8)
    graphics.text(3, 4, "Movimientos: " .. moves, colors.lightGray)
    local cell_width, cell_height = math.floor((width - 4) / 4), 3
    for index = 1, 16 do
        local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
        local face_up = revealed[index] or matched[index]
        graphics.button(2 + column * cell_width, 6 + row * (cell_height + 1),
            cell_width, face_up and cards[index] or "?", matched[index] and colors.green or colors.blue)
    end
    graphics.text(3, height - 2, message, colors.lightGray, colors.black, width - 6)
end

while true do
    draw()
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side then
        if y >= 6 and y <= 21 then
            local cell_width = math.floor((width - 4) / 4)
            local column = math.floor((x - 2) / cell_width)
            local row = math.floor((y - 6) / 4)
            local index = row * 4 + column + 1
            if index >= 1 and index <= 16 and not matched[index] and not revealed[index] then
                if mismatch then
                    revealed, first, mismatch = {}, nil, false
                end
                if not first then
                    first, revealed[index] = index, true
                else
                    revealed[index] = true
                    moves = moves + 1
                    if cards[first] == cards[index] then
                        matched[first], matched[index] = true, true
                        message = "Pareja encontrada!"
                    else
                        mismatch = true
                        message = "No coinciden; toca otra tarjeta para continuar."
                    end
                    first = nil
                end
                local complete = true
                for card_index = 1, 16 do
                    if not matched[card_index] then complete = false end
                end
                if complete then message = "Ganaste en " .. moves .. " movimientos!" end
            end
        end
    end
end
