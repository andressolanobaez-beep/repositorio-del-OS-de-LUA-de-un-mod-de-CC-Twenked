if not candOS.monitor then
    print("El Archivador grafico necesita el monitor conectado.")
    return
end

local screen = term.current()
local side = candOS.monitor_side
local directory = shell.resolve("/")
local items = {}
local page = 1
local selection

local function sorted_items(path)
    local result = {}
    for _, name in ipairs(fs.list(path)) do
        result[#result + 1] = {
            name = name,
            path = fs.combine(path, name),
            is_dir = fs.isDir(fs.combine(path, name))
        }
    end
    table.sort(result, function(a, b)
        if a.is_dir ~= b.is_dir then
            return a.is_dir
        end
        return a.name:lower() < b.name:lower()
    end)
    return result
end

local function draw_wrapped(x, y, max_y, text)
    local width = screen.getSize()
    local words = {}
    for word in tostring(text):gmatch("%S+") do
        words[#words + 1] = word
    end
    for _, word in ipairs(words) do
        local cursor_x = select(1, screen.getCursorPos())
        if cursor_x > x and cursor_x + #word > width then
            y = y + 1
            if y > max_y then
                return y
            end
            screen.setCursorPos(x, y)
        end
        screen.write(word)
        if _ ~= #words then
            cursor_x = select(1, screen.getCursorPos())
            if cursor_x + #words[_ + 1] <= width then
                screen.write(" ")
            else
                y = y + 1
                if y > max_y then
                    return y
                end
                screen.setCursorPos(x, y)
            end
        end
    end
    return y
end

local function write_cell(x, y, text, width, background)
    local screen_width = select(1, screen.getSize())
    if x > screen_width or y < 1 then
        return
    end
    width = math.min(width, screen_width - x + 1)
    text = tostring(text)
    if #text > width then
        text = text:sub(1, width)
        local last_space = text:match(".*()%s")
        if last_space then
            text = text:sub(1, last_space - 1)
        end
    end
    screen.setCursorPos(x, y)
    screen.setBackgroundColor(background or colors.black)
    screen.setTextColor(colors.white)
    screen.write(text .. string.rep(" ", width - #text))
end

local function redraw_view_file()
    local file, err = fs.open(selection.path, "r")
    if not file then
        selection = nil
        return "No se pudo abrir el archivo: " .. tostring(err)
    end
    local contents = file.readAll()
    file.close()

    screen.setBackgroundColor(colors.black)
    screen.clear()
    local width, height = screen.getSize()
    write_cell(1, 1, " ARCHIVADOR | " .. selection.name, width, colors.blue)
    write_cell(1, 2, " TOCA ABAJO PARA VOLVER ", width, colors.gray)
    local line_number = 3
    for line in (contents .. "\n"):gmatch("(.-)\n") do
        if line_number >= height then
            break
        end
        screen.setCursorPos(1, line_number)
        line_number = draw_wrapped(1, line_number, height - 1, line)
        line_number = line_number + 1
    end
    write_cell(1, height, selection.name:lower():match("%.app$")
        and " EJECUTAR: TOCA IZQUIERDA | VOLVER: DERECHA"
        or " VOLVER AL ARCHIVADOR ", width, colors.gray)
end

local function redraw()
    items = sorted_items(directory)
    local width, height = screen.getSize()
    local page_size = math.max(1, height - 5)
    local page_count = math.max(1, math.ceil(#items / page_size))
    page = math.max(1, math.min(page, page_count))

    screen.setBackgroundColor(colors.black)
    screen.clear()
    write_cell(1, 1, " CANDOS | ARCHIVADOR ", width, colors.blue)
    write_cell(1, 2, " " .. shell.display(directory) .. " ", width, colors.black)
    write_cell(1, 3, " SUBIR ", math.floor(width / 3), colors.gray)
    write_cell(math.floor(width / 3) + 1, 3, " INICIO ", math.floor(width / 3), colors.gray)
    write_cell(width - math.floor(width / 3) + 1, 3, " SALIR ", math.floor(width / 3), colors.red)

    local first = (page - 1) * page_size + 1
    for index = first, math.min(first + page_size - 1, #items) do
        local y = 3 + index - first + 1
        local item = items[index]
        local kind = item.is_dir and "[DIR] " or "[FILE] "
        write_cell(1, y, string.format("%d. %s%s", index, kind, item.name),
            width, index % 2 == 0 and colors.gray or colors.black)
    end
    if #items == 0 then
        write_cell(2, 5, "Esta carpeta esta vacia.", width - 1, colors.black)
    end
    write_cell(1, height, " TOCA UN ELEMENTO | PAGINA " .. page .. "/" .. page_count,
        width, colors.blue)
    return page_size, page_count
end

while true do
    if selection then
        redraw_view_file()
        local event, touch_side, x, y = os.pullEvent()
        if event == "monitor_touch" and touch_side == side and y == select(2, screen.getSize()) then
            if x < select(1, screen.getSize()) / 2 and selection.name:lower():match("%.app$") then
                screen.setBackgroundColor(colors.black)
                screen.clear()
                screen.setCursorPos(1, 1)
                local ok, err = shell.start(selection.path, {})
                if not ok then
                    print(err)
                end
            end
            selection = nil
        end
    else
        local page_size, page_count = redraw()
        local event, touch_side, x, y = os.pullEvent()
        if event == "monitor_touch" and touch_side == side then
            local width, height = screen.getSize()
            if y == 3 then
                if x <= math.floor(width / 3) then
                    directory = directory == "" and "" or fs.getDir(directory)
                    page = 1
                elseif x <= math.floor(width * 2 / 3) then
                    directory = ""
                    page = 1
                else
                    break
                end
            elseif y == height then
                page = page % page_count + 1
            elseif y >= 4 and y < 4 + page_size then
                local index = (page - 1) * page_size + y - 3
                local item = items[index]
                if item then
                    if item.is_dir then
                        directory = item.path
                        page = 1
                    else
                        selection = item
                    end
                end
            end
        end
    end
end
