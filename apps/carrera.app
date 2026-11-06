local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local lane, obstacle_lane, obstacle_row = 2, math.random(1, 3), 5
local score, running, timer_id = 0, false, nil
local message = "Toca INICIAR. Cambia de carril para esquivar."
local button_width = math.floor((width - 2) / 3)

local function draw()
    graphics.clear(colors.black)
    graphics.text(2, 2, "CARRERA DE CARRILES", colors.white, colors.blue, width - 8)
    for row = 1, 8 do
        for column = 1, 3 do
            local mark, color = " ", colors.gray
            if row == obstacle_row and column == obstacle_lane then mark, color = "X", colors.red end
            if row == 8 and column == lane then mark, color = "@", colors.yellow end
            graphics.button(10 + (column - 1) * 7, 5 + (row - 1) * 2, 5, mark, color)
        end
    end
    graphics.text(3, height - 4, "Puntos: " .. score .. " | " .. message,
        colors.lightGray, colors.black, width - 6)
    if not running then
        graphics.button(width - 13, height - 3, 12, "INICIAR", colors.green)
    end
    for column = 1, 3 do
        graphics.button(2 + (column - 1) * button_width, height,
            button_width, "CARRIL " .. column, colors.blue)
    end
end

local function tick()
    if timer_id then os.cancelTimer(timer_id) end
    timer_id = os.startTimer(0.7)
end

while true do
    draw()
    local event, id, x, y = os.pullEvent()
    if event == "timer" and id == timer_id and running then
        obstacle_row = obstacle_row + 1
        if obstacle_row >= 8 then
            if obstacle_lane == lane then
                running = false
                message = "Choque! Toca INICIAR para otra carrera."
            else
                score = score + 1
                obstacle_row, obstacle_lane = 1, math.random(1, 3)
            end
        end
        if running then tick() else timer_id = nil end
    elseif event == "monitor_touch" and id == candOS.monitor_side then
        if y == height then
            lane = math.min(3, math.max(1, math.floor((x - 2) / button_width) + 1))
        elseif y == height - 3 then
            if not running then
                score, obstacle_row, obstacle_lane, running = 0, 5, math.random(1, 3), true
                message = "Esquiva los obstaculos."
                tick()
            end
        end
    end
end
