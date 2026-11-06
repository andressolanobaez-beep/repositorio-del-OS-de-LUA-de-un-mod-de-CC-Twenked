local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local directory = shell.resolve("/")
local items = {}
local page = 1
local selected
local preview_lines = {}
local preview_offset = 1
local message = "Explora tus archivos y unidades."

local function safe_list(path)
    if not fs.exists(path) or not fs.isDir(path) then
        return {}
    end
    local names = fs.list(path)
    table.sort(names, function(a, b)
        local a_dir = fs.isDir(fs.combine(path, a))
        local b_dir = fs.isDir(fs.combine(path, b))
        if a_dir ~= b_dir then
            return a_dir
        end
        return a:lower() < b:lower()
    end)
    return names
end

local function refresh()
    items = safe_list(directory)
    local page_size = math.max(1, height - 8)
    page = math.max(1, math.min(page, math.max(1, math.ceil(#items / page_size))))
end

local function draw_header(title, subtitle)
    graphics.text(2, 2, title, colors.white, colors.blue, width - 8)
    graphics.text(2, 3, subtitle, colors.lightGray, colors.black, width - 2)
end

local function draw_home()
    graphics.clear(colors.black)
    draw_header("ARCHIVOS", shell.display(directory))
    local third = math.max(1, math.floor((width - 4) / 3))
    graphics.button(2, 4, third, "SUBIR", colors.gray)
    graphics.button(2 + third, 4, third, "INICIO", colors.blue)
    graphics.button(2 + third * 2, 4, third, "NUEVO", colors.green)
    graphics.button(2 + third * 3, 4, math.max(1, width - 2 - (2 + third * 3)),
        "CARPETA", colors.lightBlue)

    local page_size = math.max(1, height - 8)
    local first = (page - 1) * page_size + 1
    for index = first, math.min(first + page_size - 1, #items) do
        local row = index - first
        local path = fs.combine(directory, items[index])
        local is_dir = fs.isDir(path)
        local icon = is_dir and "[+] " or "[ ] "
        local background = index % 2 == 0 and colors.gray or colors.black
        graphics.button(2, 5 + row, width - 4, icon .. items[index], background)
    end
    if #items == 0 then
        graphics.panel(3, 7, width - 6, 5, "Carpeta vacia",
            colors.white, colors.gray)
        graphics.centerText(9, "Crea un archivo o una carpeta.", colors.lightGray, colors.gray)
    end

    graphics.text(2, height - 2,
        message .. "   Pagina " .. page .. "/" ..
            math.max(1, math.ceil(#items / page_size)),
        colors.lightGray, colors.black, width - 2)
    graphics.button(2, height, math.floor(width / 3), "ANTERIOR", colors.gray)
    graphics.button(math.floor(width / 3) + 1, height,
        math.floor(width / 3), "SIGUIENTE", colors.gray)
    graphics.button(width - math.floor(width / 3) + 1, height,
        math.floor(width / 3), "CERRAR", colors.red)
    return page_size, third
end

local function wrap_lines(contents, max_width)
    local result = {}
    for original in (contents .. "\n"):gmatch("(.-)\n") do
        if original == "" then
            result[#result + 1] = ""
        else
            while #original > max_width do
                result[#result + 1] = original:sub(1, max_width)
                original = original:sub(max_width + 1)
            end
            result[#result + 1] = original
        end
    end
    return result
end

local function open_preview(item)
    local file, err = fs.open(item.path, "r")
    if not file then
        message = "No se pudo abrir: " .. tostring(err)
        selected = nil
        return
    end
    local contents = file.readAll()
    file.close()
    selected = item
    preview_lines = wrap_lines(contents, math.max(1, width - 6))
    preview_offset = 1
end

local function draw_preview()
    graphics.clear(colors.black)
    draw_header(selected.name, shell.display(selected.path))
    local body_height = math.max(3, height - 9)
    local total = #preview_lines
    local last_offset = math.max(1, total - body_height + 1)
    preview_offset = math.max(1, math.min(preview_offset, last_offset))
    graphics.textArea(2, 4, width - 4, body_height,
        preview_lines, preview_offset, colors.white, colors.gray)
    graphics.text(2, height - 3,
        "Linea " .. preview_offset .. "-" ..
            math.min(total, preview_offset + body_height - 3) ..
            " de " .. total .. " | " .. message,
        colors.lightGray, colors.black, width - 2)
    local slots = selected.name:lower():match("%.app$") and 4 or 3
    local button_width = math.max(1, math.floor((width - 2) / slots))
    graphics.button(2, height, button_width, "ATRAS", colors.gray)
    graphics.button(2 + button_width, height, button_width, "EDITAR", colors.blue)
    if slots == 4 then
        graphics.button(2 + button_width * 2, height, button_width,
            "EJECUTAR", colors.green)
        graphics.button(2 + button_width * 3, height, width,
            "BORRAR", colors.red)
    else
        graphics.button(2 + button_width * 2, height, width,
            "BORRAR", colors.red)
    end
    return button_width
end

local function create_file()
    local name = input("Nombre del archivo", "nuevo.txt")
    if name == "" then
        message = "Nombre vacio; no se creo el archivo."
        return
    end
    local path = fs.combine(directory, name)
    if fs.exists(path) then
        message = "Ya existe ese nombre."
        return
    end
    local file, err = fs.open(path, "w")
    if not file then
        message = "No se pudo crear: " .. tostring(err)
        return
    end
    local text = input("Contenido inicial (opcional)")
    file.write(text)
    file.close()
    message = "Archivo creado: " .. name
    refresh()
end

local function create_folder()
    local name = input("Nombre de la carpeta")
    if name == "" then
        message = "Nombre vacio; no se creo la carpeta."
        return
    end
    local path = fs.combine(directory, name)
    if fs.exists(path) then
        message = "Ya existe ese nombre."
        return
    end
    fs.makeDir(path)
    message = "Carpeta creada: " .. name
    refresh()
end

local function edit_selected()
    local contents = table.concat(preview_lines, "\n")
    local lines = {}
    for line in (contents .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    while true do
        local line = input("Linea (SAVE para terminar)",
            lines[#lines] or "")
        if line == "SAVE" then
            break
        end
        lines[#lines + 1] = line
    end
    local file, err = fs.open(selected.path, "w")
    if not file then
        message = "No se pudo guardar: " .. tostring(err)
        return
    end
    file.write(table.concat(lines, "\n"))
    file.close()
    open_preview(selected)
    message = "Cambios guardados."
end

refresh()
while true do
    if selected then
        local button_width = draw_preview()
        local event, side, x, y = os.pullEvent()
        if event == "monitor_touch" and side == candOS.monitor_side then
            if y == height then
                if x < 2 + button_width then
                    selected = nil
                    refresh()
                elseif x < 2 + button_width * 2 then
                    edit_selected()
                elseif selected.name:lower():match("%.app$")
                    and x < 2 + button_width * 3 then
                    local ok, err = shell.start(selected.path, {})
                    if not ok then
                        message = "Error al ejecutar: " .. tostring(err)
                    end
                else
                    local answer = input("Escribe BORRAR para confirmar")
                    if answer == "BORRAR" then
                        fs.delete(selected.path)
                        message = "Archivo eliminado."
                        selected = nil
                        refresh()
                    else
                        message = "Eliminacion cancelada."
                    end
                end
            elseif y == 4 then
                preview_offset = math.max(1, preview_offset - 1)
            elseif y >= height - 4 then
                preview_offset = math.min(#preview_lines, preview_offset + 1)
            end
        end
    else
        local page_size, third = draw_home()
        local event, side, x, y = os.pullEvent()
        if event == "monitor_touch" and side == candOS.monitor_side then
            if y == 4 then
                if x < 2 + third then
                    directory = directory == shell.resolve("/") and directory
                        or fs.getDir(directory)
                    page = 1
                    refresh()
                elseif x < 2 + third * 2 then
                    directory = shell.resolve("/")
                    page = 1
                    refresh()
                elseif x < 2 + third * 3 then
                    create_file()
                else
                    create_folder()
                end
            elseif y == height then
                if x <= math.floor(width / 3) then
                    page = math.max(1, page - 1)
                elseif x <= math.floor(width * 2 / 3) then
                    page = math.min(math.max(1, math.ceil(#items / page_size)), page + 1)
                else
                    break
                end
            elseif y >= 5 and y < 5 + page_size then
                local index = (page - 1) * page_size + y - 4
                local name = items[index]
                if name then
                    local path = fs.combine(directory, name)
                    if fs.isDir(path) then
                        directory = path
                        page = 1
                        message = "Carpeta abierta: " .. name
                        refresh()
                    else
                        open_preview({name = name, path = path})
                    end
                end
            end
        end
    end
end
