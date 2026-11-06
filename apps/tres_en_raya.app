local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local board = {"", "", "", "", "", "", "", "", ""}
local player = "X"
local message = "Turno de X"
local finished = false
local cell_size = math.max(3, math.min(8, math.floor((height - 12) / 3)))
local board_x = math.floor((width - cell_size * 3) / 2) + 1
local board_y = 5

local wins = {
    {1, 2, 3}, {4, 5, 6}, {7, 8, 9},
    {1, 4, 7}, {2, 5, 8}, {3, 6, 9},
    {1, 5, 9}, {3, 5, 7}
}

local function winner()
    for _, line in ipairs(wins) do
        if board[line[1]] ~= "" and board[line[1]] == board[line[2]]
            and board[line[2]] == board[line[3]] then
            return board[line[1]]
        end
    end
end

local function draw()
    graphics.clear(colors.black)
    graphics.text(2, 1, "TRES EN RAYA", colors.white, colors.blue, width - 8)
    graphics.centerText(3, message, colors.lightGray)
    for index = 1, 9 do
        local row = math.floor((index - 1) / 3)
        local column = (index - 1) % 3
        local x = board_x + column * cell_size
        local y = board_y + row * cell_size
        graphics.panel(x, y, cell_size, cell_size, nil,
            colors.white, colors.gray)
        if board[index] ~= "" then
            graphics.text(x + math.floor(cell_size / 2), y + math.floor(cell_size / 2),
                board[index], board[index] == "X" and colors.lightBlue or colors.orange,
                colors.gray)
        end
    end
    graphics.button(math.floor((width - 16) / 2), height - 2, 16,
        "NUEVA PARTIDA", colors.green)
end

while true do
    draw()
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side then
        if y == height - 2 then
            board = {"", "", "", "", "", "", "", "", ""}
            player, message, finished = "X", "Turno de X", false
        elseif not finished and x >= board_x and x < board_x + cell_size * 3
            and y >= board_y and y < board_y + cell_size * 3 then
            local column = math.floor((x - board_x) / cell_size)
            local row = math.floor((y - board_y) / cell_size)
            local index = row * 3 + column + 1
            if board[index] == "" then
                board[index] = player
                local won = winner()
                local occupied = 0
                for _, value in ipairs(board) do
                    if value ~= "" then
                        occupied = occupied + 1
                    end
                end
                if won then
                    message = won .. " gana!"
                    finished = true
                elseif occupied == #board then
                    message = "Empate."
                    finished = true
                else
                    player = player == "X" and "O" or "X"
                    message = "Turno de " .. player
                end
            end
        end
    end
end
