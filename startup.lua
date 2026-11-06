-- CANDOS: lanzador grafico de aplicaciones Lua para CC: Tweaked.
-- Hardware previsto: monitor grande arriba, lectoras a izquierda/derecha,
-- y speaker atras. Los archivos .app contienen codigo Lua normal.

local monitor, monitor_side
if peripheral.getType("top") == "monitor" then
    monitor = peripheral.wrap("top")
    monitor_side = "top"
else
    monitor, monitor_side = peripheral.find("monitor")
end

local speaker
if peripheral.getType("back") == "speaker" then
    speaker = peripheral.wrap("back")
else
    speaker = peripheral.find("speaker")
end

local original_terminal = term.current()
local screen_width, screen_height

if monitor then
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    screen_width, screen_height = monitor.getSize()
    term.redirect(monitor)
end

local function move_to_next_line(output_term, width, height)
    local _, y = output_term.getCursorPos()
    if y >= height then
        output_term.scroll(1)
        output_term.setCursorPos(1, height)
    else
        output_term.setCursorPos(1, y + 1)
    end
end

local function write_wrapped(text, add_newline)
    local output_term = term.current()
    if not output_term then
        return
    end

    local width, height = output_term.getSize()
    local function write_line(line)
        local words = {}
        for word in line:gmatch("%S+") do
            words[#words + 1] = word
        end
        for index, word in ipairs(words) do
            local x, y = output_term.getCursorPos()
            if y > height then
                output_term.scroll(y - height)
                output_term.setCursorPos(x, height)
                x = select(1, output_term.getCursorPos())
            end

            if x > 1 and x + #word - 1 > width then
                move_to_next_line(output_term, width, height)
                x = 1
            end
            output_term.write(word)

            local next_word = words[index + 1]
            if next_word then
                x = select(1, output_term.getCursorPos())
                if x + #next_word > width then
                    move_to_next_line(output_term, width, height)
                else
                    output_term.write(" ")
                end
            end
        end
    end

    text = tostring(text or ""):gsub("\r", "")
    local start = 1
    while true do
        local newline = text:find("\n", start, true)
        write_line(newline and text:sub(start, newline - 1) or text:sub(start))
        if not newline then
            break
        end
        move_to_next_line(output_term, width, height)
        start = newline + 1
    end

    if add_newline then
        move_to_next_line(output_term, width, height)
    end
end

_G.print = function(...)
    local values = {}
    for index = 1, select("#", ...) do
        values[index] = tostring(select(index, ...))
    end
    write_wrapped(table.concat(values, " "), true)
end

_G.write = function(value)
    write_wrapped(tostring(value or ""), false)
end

local shell_path = fs.exists("/disk2/shell.py") and "/disk2/shell.py" or "shell.py"
local shell_chunk, shell_load_error = loadfile(shell_path)
if not shell_chunk then
    error("No se pudo cargar " .. shell_path .. ": " .. tostring(shell_load_error))
end
local shell_ok, shell_api = pcall(shell_chunk)
if not shell_ok then
    error("No se pudo iniciar shell.py: " .. tostring(shell_api))
end
_G.shell = shell_api
_G.candOS = {
    monitor = monitor,
    monitor_side = monitor_side,
    speaker = speaker
}
if type(shell.load_imports) == "function" then
    shell.load_imports()
else
    print("Aviso: shell.py no admite la carga de drivers; actualiza CANDOS.")
end

local function collect_apps()
    if type(shell.list_apps) == "function" then
        return shell.list_apps()
    end

    local apps = {}
    local function scan(directory, depth)
        if depth > 10 or not fs.exists(directory) or not fs.isDir(directory) then
            return
        end
        for _, name in ipairs(fs.list(directory)) do
            local path = fs.combine(directory, name)
            if fs.isDir(path) then
                scan(path, depth + 1)
            elseif name:lower():match("%.app$") then
                apps[#apps + 1] = {
                    name = name,
                    path = path,
                    side = "CANDOS",
                    relative_path = path
                }
            end
        end
    end

    scan("/disk2/apps", 0)
    table.sort(apps, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return apps
end

local function screen_write(x, y, text, foreground, background, max_width)
    if y < 1 or y > screen_height or x > screen_width then
        return
    end
    text = tostring(text)
    local available = math.min(max_width or screen_width, screen_width - x + 1)
    if available <= 0 then
        return
    end
    if #text > available then
        text = text:sub(1, available)
        local last_space = text:match(".*()%s")
        if last_space then
            text = text:sub(1, last_space - 1)
        end
    end
    monitor.setCursorPos(x, y)
    monitor.setTextColor(foreground or colors.white)
    monitor.setBackgroundColor(background or colors.black)
    monitor.write(text .. string.rep(" ", available - #text))
end

local function button(x, y, width, label, background)
    local text = (" " .. label .. " "):sub(1, width)
    screen_write(x, y, text, colors.white, background or colors.blue, width)
end

local function layout()
    local columns = math.max(1, math.min(4, math.floor((screen_width - 2) / 14)))
    local rows = math.max(1, math.floor((screen_height - 5) / 4))
    local card_width = math.max(1, math.floor((screen_width - (columns + 1) * 2) / columns))
    return columns, rows, card_width, columns * rows
end

local function draw_launcher(apps, page, message)
    local columns, rows, card_width, page_size = layout()
    local page_count = math.max(1, math.ceil(#apps / page_size))
    page = math.max(1, math.min(page, page_count))

    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    screen_write(1, 1, " CANDOS | LANZADOR DE APPS ", colors.white, colors.blue)
    screen_write(1, 2, message or (#apps .. " app(s) disponibles"), colors.lightGray)

    local page_text = " ACTUALIZAR "
    screen_write(math.max(1, screen_width - #page_text + 1), 2, page_text,
        colors.white, colors.gray)

    local first = (page - 1) * page_size + 1
    for index = first, math.min(first + page_size - 1, #apps) do
        local local_index = index - first
        local column = local_index % columns
        local row = math.floor(local_index / columns)
        local x = 2 + column * (card_width + 2)
        local y = 4 + row * 4
        local app = apps[index]
        local name = app.name:gsub("%.app$", "")

        screen_write(x, y, "", colors.white, colors.lightBlue, card_width)
        screen_write(x, y + 1, "  > " .. name, colors.white, colors.lightBlue, card_width)
        screen_write(x, y + 2, "  " .. app.side .. ": " .. app.relative_path,
            colors.white, colors.blue, card_width)
    end

    if #apps == 0 then
        screen_write(2, 5, "No hay archivos .app en los", colors.lightGray)
        screen_write(2, 6, "discos montados de las lectoras.", colors.lightGray)
        screen_write(2, 8, "Copia archivos Lua con extension .app", colors.lightGray)
    end

    local footer_y = screen_height
    button(2, footer_y, 10, "ANTERIOR", colors.gray)
    button(math.floor((screen_width - 6) / 2), footer_y, 8, "SALIR", colors.red)
    button(screen_width - 10, footer_y, 10, "SIGUIENTE", colors.gray)
    screen_write(math.max(1, math.floor((screen_width - 15) / 2)), screen_height - 1,
        "Pagina " .. page .. "/" .. page_count, colors.lightGray)
    return page, page_count, columns, rows, card_width, page_size
end

local function execute_app(app)
    if monitor then
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
        monitor.clear()
        monitor.setCursorPos(1, 1)
    end
    local ok, runtime_error
    if type(shell.start) == "function" then
        ok, runtime_error = shell.start(app.path, {})
    else
        local file, open_error = fs.open(app.path, "r")
        if not file then
            ok, runtime_error = false, "No se pudo abrir " .. app.path ..
                ": " .. tostring(open_error)
        else
            local source = file.readAll()
            file.close()
            local program, syntax_error = load(source, "@" .. app.path, "t", _ENV)
            if not program then
                ok, runtime_error = false, "Error de sintaxis en " .. app.path ..
                    ": " .. tostring(syntax_error)
            else
                ok, runtime_error = pcall(program)
            end
        end
    end
    if monitor then
        term.redirect(monitor)
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
    end
    if not ok then
        return false, runtime_error
    end
    return true, app.name .. " termino. Toca una app para volver a abrirla."
end

local function run_graphical_launcher()
    local apps = collect_apps()
    local page, page_count = 1, 1
    local message

    while true do
        local columns, rows, card_width, page_size
        page, page_count, columns, rows, card_width, page_size =
            draw_launcher(apps, page, message)
        message = nil

        local event, side, x, y = os.pullEvent()
        if event == "monitor_touch" and side == monitor_side then
            if y == 2 and x >= screen_width - 11 then
                apps = collect_apps()
                page = math.min(page, math.max(1, math.ceil(#apps / page_size)))
            elseif y == screen_height then
                if x <= 11 then
                    page = math.max(1, page - 1)
                elseif x >= screen_width - 10 then
                    page = math.min(page_count, page + 1)
                elseif x >= math.floor((screen_width - 6) / 2)
                    and x < math.floor((screen_width - 6) / 2) + 8 then
                    return true
                end
            elseif y >= 4 and y < 4 + rows * 4 then
                local row = math.floor((y - 4) / 4)
                local column = math.floor((x - 2) / (card_width + 2))
                local card_x = 2 + column * (card_width + 2)
                if column >= 0 and column < columns and x >= card_x
                    and x < card_x + card_width then
                    local index = (page - 1) * page_size + row * columns + column + 1
                    local app = apps[index]
                    if app then
                        local _, result = execute_app(app)
                        message = result
                        apps = collect_apps()
                        page = math.min(page, math.max(1, math.ceil(#apps / page_size)))
                    end
                end
            end
        elseif event == "monitor_resize" and side == monitor_side then
            screen_width, screen_height = monitor.getSize()
        elseif event == "peripheral_detach" and side == monitor_side then
            return false
        end
    end
end

local function show_hardware()
    print("=== Hardware CC: Tweaked ===")
    if monitor then
        print("Monitor: " .. screen_width .. "x" .. screen_height .. " caracteres")
        print("El tamano fisico 5x5 se configura en Minecraft.")
    else
        print("Monitor: no detectado; usando pantalla del computador.")
    end

    for _, side in ipairs({"left", "right"}) do
        if peripheral.getType(side) == "drive" then
            local drive = peripheral.wrap(side)
            local mount = drive.getMountPath()
            print(side .. ": lectora conectada, " ..
                (mount and ("disco montado en " .. mount) or "sin disco de datos"))
        else
            print(side .. ": lectora no detectada")
        end
    end
    print("Altavoz atras: " .. (speaker and "conectado" or "no detectado"))
    print("Computador: " .. (os.getComputerLabel() or tostring(os.getComputerID())))
    print("")
end

local function run_terminal_launcher()
    print("CANDOS - Shell del sistema")
    print("Comandos: apps, launch <numero>, hardware, cc <comando CC>, exit")
    while true do
        write(shell.dir() .. "> ")
        local line = read()
        local command = line:match("^%s*(%S+)")
        command = command and command:lower() or ""
        if command == "exit" then
            return
        elseif command == "hardware" or command == "hw" then
            show_hardware()
        elseif command == "apps" or command == "list" then
            local apps = collect_apps()
            for index, app in ipairs(apps) do
                print(string.format("%d. %s [%s]", index, app.name, app.side))
            end
            if #apps == 0 then
                print("No hay archivos .app en el path.")
            end
        elseif command == "launch" then
            local selected = tonumber(line:match("^%s*%S+%s+(%S+)"))
            local apps = collect_apps()
            local app = selected and apps[selected]
            if not app then
                print("Numero de app invalido. Usa 'apps' para ver la lista.")
            else
                local _, result = execute_app(app)
                print(result)
            end
        elseif command == "cc" then
            shell.cc(line:gsub("^%s*%S+%s*", "", 1))
        elseif command ~= "" then
            local _, result = shell.run(line)
            if result == "exit" then
                return
            end
        end
    end
end

local keep_monitor_terminal = false
if monitor then
    keep_monitor_terminal = run_graphical_launcher()
else
    run_terminal_launcher()
end

if keep_monitor_terminal then
    term.redirect(monitor)
else
    term.redirect(original_terminal)
end
print("CANDOS finalizado; la terminal de CC:Tweaked esta disponible.")
