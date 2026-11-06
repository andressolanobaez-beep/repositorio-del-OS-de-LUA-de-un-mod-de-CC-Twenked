local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local map = {
    "########",
    "#......#",
    "#.##...#",
    "#......#",
    "#..#...#",
    "#......#",
    "#......#",
    "########"
}
local player_x, player_y, direction = 2.5, 2.5, 0
local enemies = {{x = 6.5, y = 2.5}, {x = 5.5, y = 6.5}}
local health, ammo = 5, 12
local message = "Limpia el laberinto. Muevete, gira y dispara."
local game_over = false
local fov = math.pi / 3

local function wall_at(x, y)
    local row = map[math.floor(y)]
    return not row or row:sub(math.floor(x), math.floor(x)) ~= "."
end

local function clear_path(target_x, target_y)
    local dx, dy = target_x - player_x, target_y - player_y
    local distance = math.sqrt(dx * dx + dy * dy)
    local steps = math.max(1, math.floor(distance / 0.08))
    for step = 1, steps - 1 do
        local ratio = step / steps
        if wall_at(player_x + dx * ratio, player_y + dy * ratio) then
            return false
        end
    end
    return true
end

local function enemy_position(enemy)
    local dx, dy = enemy.x - player_x, enemy.y - player_y
    local forward = dx * math.cos(direction) + dy * math.sin(direction)
    local side = -dx * math.sin(direction) + dy * math.cos(direction)
    return forward, side, math.sqrt(dx * dx + dy * dy)
end

local function reset_game()
    player_x, player_y, direction = 2.5, 2.5, 0
    enemies = {{x = 6.5, y = 2.5}, {x = 5.5, y = 6.5}}
    health, ammo, game_over = 5, 12, false
    message = "Limpia el laberinto. Muévete, gira y dispara."
end

local function draw_world()
    local view_top, view_height = 5, height - 14
    local view_width = width - 4
    graphics.fillRect(2, view_top, view_width, math.floor(view_height / 2),
        colors.lightBlue)
    graphics.fillRect(2, view_top + math.floor(view_height / 2), view_width,
        math.ceil(view_height / 2), colors.gray)

    for column = 0, view_width - 1 do
        local ray_angle = direction + ((column / math.max(1, view_width - 1)) - 0.5) * fov
        local distance = 0.08
        while distance < 8 do
            local ray_x = player_x + math.cos(ray_angle) * distance
            local ray_y = player_y + math.sin(ray_angle) * distance
            if wall_at(ray_x, ray_y) then
                break
            end
            distance = distance + 0.08
        end
        local corrected = distance * math.cos(ray_angle - direction)
        local wall_height = math.min(view_height,
            math.floor(view_height / math.max(0.25, corrected)))
        local wall_top = view_top + math.floor((view_height - wall_height) / 2)
        local wall_color = corrected < 2 and colors.lightGray
            or corrected < 4 and colors.gray or colors.blue
        graphics.fillRect(2 + column, wall_top, 1, wall_height, wall_color)
    end

    for _, enemy in ipairs(enemies) do
        local forward, side = enemy_position(enemy)
        if forward > 0 and forward < 8 and clear_path(enemy.x, enemy.y) then
            local screen_x = math.floor(width / 2 +
                (side / forward) / math.tan(fov / 2) * (view_width / 2))
            local size = math.max(1, math.floor(view_height / forward / 5))
            graphics.text(screen_x, math.floor(height / 2), string.rep("M", size),
                colors.red, colors.gray, size)
        end
    end
end

local function enemy_turn()
    for _, enemy in ipairs(enemies) do
        local forward, side, distance = enemy_position(enemy)
        if distance < 3.5 and forward > 0 and math.abs(side) < 1.2
            and clear_path(enemy.x, enemy.y) then
            health = health - 1
            message = "Te alcanzó un invasor. Vida: " .. health
            if health <= 0 then
                game_over = true
                message = "Fin de la partida. Toca REINICIAR."
            end
            return
        end
    end
end

local function shoot()
    if ammo <= 0 then
        message = "Sin municion. Toca CARGAR."
        return
    end
    ammo = ammo - 1
    local target
    for index, enemy in ipairs(enemies) do
        local forward, side = enemy_position(enemy)
        if forward > 0 and forward < 7 and math.abs(side) < 0.3 * forward
            and clear_path(enemy.x, enemy.y)
            and (not target or forward < target.forward) then
            target = {index = index, forward = forward}
        end
    end
    if target then
        table.remove(enemies, target.index)
        message = "Invasor eliminado. Quedan " .. #enemies .. "."
        if #enemies == 0 then
            game_over = true
            message = "Victoria! Toca REINICIAR para otra partida."
        end
    else
        message = "Disparo perdido. Munición: " .. ammo
    end
end

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "CANDOS FPS | VIDA " .. health .. " | MUNICION " .. ammo,
        colors.white, colors.blue, width - 4)
    draw_world()
    graphics.text(2, height - 8, message, colors.white, colors.black, width - 4)
    local button_width = math.floor((width - 2) / 5)
    local labels = {"AVANZA", "GIRA <", "FUEGO", "GIRA >", "CARGAR"}
    local button_colors = {colors.green, colors.blue, colors.red, colors.blue, colors.gray}
    for index = 1, #labels do
        graphics.button(2 + (index - 1) * button_width, height,
            button_width, labels[index], button_colors[index])
    end

    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height then
        local choice = math.min(5,
            math.max(1, math.floor((x - 2) / button_width) + 1))
        if game_over then
            reset_game()
        elseif choice == 1 then
            local next_x = player_x + math.cos(direction) * 0.5
            local next_y = player_y + math.sin(direction) * 0.5
            if not wall_at(next_x, next_y) then
                player_x, player_y = next_x, next_y
                enemy_turn()
            else
                message = "Hay una pared delante."
            end
        elseif choice == 2 then
            direction = direction - math.pi / 6
            enemy_turn()
        elseif choice == 3 then
            shoot()
            if not game_over then enemy_turn() end
        elseif choice == 4 then
            direction = direction + math.pi / 6
            enemy_turn()
        else
            ammo = 12
            message = "Munición recargada."
        end
    end
end
