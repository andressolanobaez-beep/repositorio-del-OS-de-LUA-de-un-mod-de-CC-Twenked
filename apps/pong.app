local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local paddle, ball_x, ball_y = 2, 4, 4
local direction_x, direction_y = 1, 1
local player_score, cpu_score = 0, 0
local running, timer_id = false, nil
local message = "Toca INICIAR. Mueve la paleta con IZQ y DER."

local function draw()
    graphics.clear(colors.black)
    graphics.text(2, 2, "PONG", colors.white, colors.blue, width - 8)
    graphics.text(3, 4, "Tu: " .. player_score .. " | PC: " .. cpu_score,
        colors.lightGray)
    local left, top = 7, 7
    for row = 1, 10 do
        for column = 1, 12 do
            local label, color = " ", colors.gray
            if column == ball_x and row == ball_y then label, color = "O", colors.yellow end
            if row == 10 and column >= paddle and column <= paddle + 2 then
                label, color = "=", colors.green
            end
            if row == 1 and column >= 6 and column <= 8 then label, color = "=", colors.red end
            graphics.button(left + (column - 1) * 2, top + (row - 1) * 2,
                1, label, color)
        end
    end
    graphics.text(3, height - 4, message, colors.lightGray, colors.black, width - 6)
    graphics.button(2, height, 12, "IZQ", colors.blue)
    graphics.button(15, height, 12, "INICIAR", colors.green)
    graphics.button(28, height, 12, "DER", colors.blue)
end

local function tick()
    if timer_id then os.cancelTimer(timer_id) end
    timer_id = os.startTimer(0.35)
end

while true do
    draw()
    local event, id, x, y = os.pullEvent()
    if event == "timer" and id == timer_id and running then
        ball_x, ball_y = ball_x + direction_x, ball_y + direction_y
        if ball_x <= 1 or ball_x >= 12 then
            direction_x = -direction_x
            ball_x = math.min(12, math.max(1, ball_x))
        end
        if ball_y <= 2 then
            if ball_x >= 6 and ball_x <= 8 then
                direction_y = 1
            else
                player_score = player_score + 1
                ball_x, ball_y, direction_y = math.random(3, 10), 3, 1
            end
        elseif ball_y >= 9 then
            if ball_x >= paddle and ball_x <= paddle + 2 then
                direction_y = -1
            else
                cpu_score = cpu_score + 1
                ball_x, ball_y, direction_y = math.random(3, 10), 8, -1
            end
        end
        tick()
    elseif event == "monitor_touch" and id == candOS.monitor_side and y == height then
        if x < 14 then
            paddle = math.max(1, paddle - 1)
        elseif x < 27 then
            if not running then
                running = true
                message = "En juego."
                tick()
            end
        else
            paddle = math.min(10, paddle + 1)
        end
    end
end
