local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local protocol = "candOS.cluster.v1"
local config = shell.resolve("/.candOS")
local role_file = fs.combine(config, "role.txt")
local pairs_file = fs.combine(config, "peers.txt")
local roles = {"auxiliar", "nucleo", "pantalla"}
local role = "auxiliar"
local discovery = false
local peers = {}
local message = "Deteccion apagada. No envia nada por la red."
local timer_id

local function read_text(path)
    if not fs.exists(path) then
        return ""
    end
    local file, err = fs.open(path, "r")
    if not file then
        return nil, tostring(err)
    end
    local text = file.readAll()
    file.close()
    return text
end

local saved_role, role_error = read_text(role_file)
if saved_role == nil then
    message = "No se pudo leer el rol: " .. role_error
elseif saved_role:match("^%s*(.-)%s*$") ~= "" then
    role = saved_role:match("^%s*(.-)%s*$")
end

local function persist(path, value)
    fs.makeDir(config)
    local file, err = fs.open(path, "w")
    if not file then
        return false, tostring(err)
    end
    file.write(value)
    file.close()
    return true
end

local function load_paired_ids()
    local text, err = read_text(pairs_file)
    if text == nil then
        message = "No se pudo leer la lista de equipos: " .. err
        return
    end
    for line in text:gmatch("[^\r\n]+") do
        local id = tonumber(line)
        if id then
            peers[id] = {id = id, state = "emparejado"}
        end
    end
end

local function save_paired_ids()
    local ids = {}
    for id, peer in pairs(peers) do
        if peer.state == "emparejado" then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    local lines = {}
    for _, id in ipairs(ids) do
        lines[#lines + 1] = tostring(id)
    end
    return persist(pairs_file, table.concat(lines, "\n"))
end

local function visible_peers()
    local visible = {}
    for _, peer in pairs(peers) do
        visible[#visible + 1] = peer
    end
    table.sort(visible, function(a, b)
        return a.id < b.id
    end)
    return visible
end

local function modems()
    local result = {}
    for _, device in ipairs(shell.peripherals()) do
        if device.type == "modem" then
            result[#result + 1] = device.name
        end
    end
    return result
end

local function call_rednet(method, ...)
    if type(rednet) ~= "table" or type(rednet[method]) ~= "function" then
        return false, "La funcion rednet." .. method .. "() no esta disponible."
    end
    local ok, result = pcall(rednet[method], ...)
    if not ok then
        return false, tostring(result)
    end
    return true, result
end

local function broadcast()
    if not discovery then
        return false
    end
    local ok, err = call_rednet("broadcast", {
        kind = "hello",
        os = "CANDOS",
        kernel = "CANDOS Lua",
        id = os.getComputerID(),
        label = os.getComputerLabel() or ("PC " .. os.getComputerID()),
        role = role
    }, protocol)
    if not ok then
        message = "No se pudo buscar equipos: " .. err
    end
    return ok
end

local function set_discovery(enabled)
    if type(rednet) ~= "table" or type(rednet.open) ~= "function" then
        message = "La API rednet no esta disponible en este runtime."
        return
    end
    local found = modems()
    if enabled and #found == 0 then
        message = "No hay modems conectados. Conecta uno y vuelve a intentar."
        return
    end
    local opened = 0
    local failures = {}
    for _, name in ipairs(found) do
        if enabled then
            local ok, err = call_rednet("open", name)
            if ok then
                opened = opened + 1
            else
                failures[#failures + 1] = name .. ": " .. err
            end
        else
            local is_open, state = call_rednet("isOpen", name)
            if not is_open then
                failures[#failures + 1] = name .. ": " .. state
            elseif state then
                local closed, close_error = call_rednet("close", name)
                if not closed then
                    failures[#failures + 1] = name .. ": " .. close_error
                end
            end
        end
    end
    if enabled and opened == 0 then
        message = "No se pudo abrir ningun modem. " ..
            table.concat(failures, " | ")
        return
    end
    discovery = enabled
    if discovery then
        if broadcast() then
            message = #failures > 0
                and ("Buscando con algunos modems; errores: " ..
                    table.concat(failures, " | "))
                or "Buscando CANDOS. Acepta cada vinculo manualmente."
        end
        timer_id = os.startTimer(4)
    else
        if timer_id then
            os.cancelTimer(timer_id)
            timer_id = nil
        end
        message = "Deteccion apagada."
        if #failures > 0 then
            message = message .. " Errores: " .. table.concat(failures, " | ")
        end
    end
end

local function remember_peer(id)
    local ok, err = save_paired_ids()
    if ok then
        message = "PC " .. id .. " emparejada. Solo se comparte presencia y rol."
    else
        message = "No se pudo guardar el vinculo: " .. tostring(err)
    end
end

local function receive_peer(id, data)
    if type(data) ~= "table" or data.os ~= "CANDOS"
        or data.kernel ~= "CANDOS Lua" or id == os.getComputerID() then
        return
    end
    local peer = peers[id] or {id = id, state = "disponible"}
    peer.label = tostring(data.label or ("PC " .. id))
    peer.role = tostring(data.role or "auxiliar")
    peer.seen = os.clock()
    if peer.state ~= "emparejado" and peer.state ~= "solicitud"
        and peer.state ~= "solicitud_enviada" then
        peer.state = "disponible"
    end
    peers[id] = peer

    if data.kind == "request" then
        if peer.state ~= "emparejado" then
            peer.state = "solicitud"
            message = peer.label .. " solicita emparejarse; toca su fila para aceptar."
        end
    elseif data.kind == "accept" and peer.state == "solicitud_enviada" then
        peer.state = "emparejado"
        remember_peer(id)
    elseif data.kind == "hello" and peer.state == "emparejado" then
        local ok, err = call_rednet("send", id, {
            kind = "hello",
            os = "CANDOS",
            kernel = "CANDOS Lua",
            id = os.getComputerID(),
            label = os.getComputerLabel() or ("PC " .. os.getComputerID()),
            role = role
        }, protocol)
        if not ok then
            message = "No se pudo responder a PC " .. id .. ": " .. err
        end
    end
end

local function draw()
    graphics.clear(colors.black)
    graphics.text(2, 2, "RED CANDOS", colors.white, colors.blue, width - 8)
    graphics.text(2, 3, "Rol local: " .. role .. " | Descubrimiento: " ..
        (discovery and "ACTIVO" or "apagado"), colors.lightGray)
    local row = 5
    for _, peer in ipairs(visible_peers()) do
        if row >= height - 7 then
            break
        end
        local state = peer.state == "emparejado" and "VINCULADA"
            or peer.state == "solicitud" and "ACEPTAR"
            or peer.state == "solicitud_enviada" and "ESPERANDO"
            or "DISPONIBLE"
        graphics.button(2, row, width - 4,
            peer.label .. " | PC " .. peer.id .. " | " .. peer.role .. " | " .. state,
            peer.state == "solicitud" and colors.orange or colors.gray)
        row = row + 2
    end
    if row == 5 then
        graphics.panel(3, 6, width - 6, 5, "Sin equipos",
            colors.white, colors.gray)
        graphics.centerText(8, "Activa la busqueda en ambas PCs.", colors.lightGray, colors.gray)
    end
    graphics.text(2, height - 5, message, colors.lightGray, colors.black, width - 2)
    local button_width = math.max(1, math.floor((width - 2) / 3))
    graphics.button(2, height, button_width,
        discovery and "DETENER" or "BUSCAR", discovery and colors.red or colors.green)
    graphics.button(2 + button_width, height, button_width, "CAMBIAR ROL", colors.blue)
    graphics.button(2 + button_width * 2, height, width, "CERRAR", colors.gray)
end

load_paired_ids()
while true do
    draw()
    local event, side, x, y = os.pullEvent()
    if event == "rednet_message" then
        local sender, data, received_protocol = side, x, y
        if received_protocol == protocol and type(data) == "table" then
            receive_peer(sender, data)
        end
    elseif event == "timer" and side == timer_id and discovery then
        broadcast()
        timer_id = os.startTimer(4)
    elseif (event == "peripheral" or event == "peripheral_detach")
        and discovery then
        set_discovery(true)
    elseif event == "monitor_touch" and side == candOS.monitor_side then
        local button_width = math.max(1, math.floor((width - 2) / 3))
        if y == height then
            if x < 2 + button_width then
                set_discovery(not discovery)
            elseif x < 2 + button_width * 2 then
                local index = 1
                for position, candidate in ipairs(roles) do
                    if candidate == role then
                        index = position % #roles + 1
                    end
                end
                role = roles[index]
                local ok, err = persist(role_file, role)
                message = ok and ("Rol guardado: " .. role)
                    or ("No se pudo guardar el rol: " .. tostring(err))
                broadcast()
            else
                set_discovery(false)
                break
            end
        elseif y >= 5 and y < height - 7 then
            local row_index = math.floor((y - 5) / 2) + 1
            local peer = visible_peers()[row_index]
            if peer and discovery then
                if peer.state == "disponible" then
                    local ok, err = call_rednet("send", peer.id, {
                        kind = "request", os = "CANDOS",
                        kernel = "CANDOS Lua", role = role
                    }, protocol)
                    if ok then
                        peer.state = "solicitud_enviada"
                        message = "Solicitud enviada a " .. peer.label .. "."
                    else
                        message = "No se pudo enviar la solicitud: " .. err
                    end
                elseif peer.state == "solicitud" then
                    local ok, err = call_rednet("send", peer.id, {
                        kind = "accept", os = "CANDOS",
                        kernel = "CANDOS Lua", role = role
                    }, protocol)
                    if ok then
                        peer.state = "emparejado"
                        remember_peer(peer.id)
                    else
                        message = "No se pudo aceptar la solicitud: " .. err
                    end
                end
            end
        end
    end
end
