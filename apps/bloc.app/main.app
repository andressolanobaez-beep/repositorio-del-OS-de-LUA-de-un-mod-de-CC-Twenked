local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local lines = {}
local message = "Crea una nota y guarda cada linea."

local function draw()
    graphics.clear(colors.black)
    graphics.text(2, 1, "BLOC DE NOTAS", colors.white, colors.blue, width - 8)
    graphics.panel(2, 4, width - 4, height - 12, "Nota", colors.white, colors.gray)
    local visible_lines = math.max(1, height - 16)
    local first = math.max(1, #lines - visible_lines + 1)
    for index = first, #lines do
        graphics.text(4, 6 + index - first, lines[index], colors.white, colors.gray, width - 8)
    end
    graphics.text(3, height - 6, message, colors.lightGray, colors.black, width - 6)
    graphics.button(3, height - 3, 16, "AGREGAR LINEA", colors.green)
    graphics.button(22, height - 3, 12, "GUARDAR", colors.blue)
    graphics.button(37, height - 3, 10, "BORRAR", colors.gray)
end

while true do
    draw()
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height - 3 then
        if x >= 3 and x <= 19 then
            lines[#lines + 1] = input("Escribe una linea")
        elseif x >= 22 and x <= 34 then
            local name = input("Nombre del archivo", "nota.txt")
            local path = shell.resolve(name)
            local file, err = fs.open(path, "w")
            if file then
                file.write(table.concat(lines, "\n"))
                file.close()
                message = "Guardado en " .. shell.display(path)
            else
                message = "No se pudo guardar: " .. tostring(err)
            end
        elseif x >= 37 and x <= 47 then
            lines = {}
            message = "Nota vacia."
        end
    end
end
