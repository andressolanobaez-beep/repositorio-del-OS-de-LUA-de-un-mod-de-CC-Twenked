local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local todos = {}
local message = "Toca AGREGAR para crear un recordatorio."
local page = 1

local function load_todos()
    local file = fs.open(shell.resolve("/.candOS/agenda.txt"), "r")
    if not file then
        return
    end
    local contents = file.readAll()
    file.close()
    for line in contents:gmatch("[^\r\n]+") do
        todos[#todos + 1] = line
    end
end

local function save_todos()
    local path = shell.resolve("/.candOS/agenda.txt")
    local parent = fs.getDir(path)
    if not fs.exists(parent) then
        fs.makeDir(parent)
    end
    local file, err = fs.open(path, "w")
    if not file then
        message = "No se pudo guardar: " .. tostring(err)
        return
    end
    file.write(table.concat(todos, "\n"))
    file.close()
    message = "Agenda guardada."
end

load_todos()
while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "CALENDARIO Y AGENDA", colors.white, colors.blue, width - 8)
    graphics.panel(3, 4, width - 6, 5, "Hoy",
        colors.white, colors.gray)
    graphics.centerText(6, os.date("%A, %d %B %Y"), colors.white, colors.gray)
    local page_size = math.max(1, height - 14)
    local first = (page - 1) * page_size + 1
    for index = first, math.min(first + page_size - 1, #todos) do
        graphics.text(3, 10 + index - first, "- " .. todos[index],
            colors.white, colors.black, width - 6)
    end
    if #todos == 0 then
        graphics.text(3, 11, "Todavia no tienes recordatorios.", colors.lightGray)
    end
    graphics.text(2, height - 3, message, colors.lightGray, colors.black, width - 2)
    local button_width = math.max(1, math.floor((width - 2) / 4))
    graphics.button(2, height, button_width, "AGREGAR", colors.green)
    graphics.button(2 + button_width, height, button_width, "BORRAR", colors.gray)
    graphics.button(2 + button_width * 2, height, button_width, "PAGINA", colors.blue)
    graphics.button(2 + button_width * 3, height, width, "CERRAR", colors.red)

    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height then
        if x < 2 + button_width then
            local item = input("Recordatorio nuevo")
            if item ~= "" then
                todos[#todos + 1] = item
                save_todos()
            end
        elseif x < 2 + button_width * 2 then
            if #todos > 0 then
                table.remove(todos)
                save_todos()
            else
                message = "No hay recordatorios para borrar."
            end
        elseif x < 2 + button_width * 3 then
            page = page % math.max(1, math.ceil(#todos / page_size)) + 1
        else
            break
        end
    end
end
