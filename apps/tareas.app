local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()

while true do
    local tasks = candOS.getTasks()
    graphics.clear(colors.black)
    graphics.text(2, 2, "TAREAS Y VENTANAS", colors.white, colors.blue, width - 8)
    graphics.text(2, 3, #tasks .. " aplicacion(es) en memoria", colors.lightGray)
    local row = 5
    for _, task in ipairs(tasks) do
        if row >= height - 3 then
            break
        end
        local status = task.status == "minimized" and "PAUSADA" or "ACTIVA"
        graphics.panel(2, row, width - 4, 2, nil, colors.white,
            task.status == "minimized" and colors.gray or colors.blue)
        graphics.text(4, row, task.name .. " | " .. status,
            colors.white, task.status == "minimized" and colors.gray or colors.blue,
            width - 8)
        row = row + 3
    end
    if #tasks == 0 then
        graphics.panel(4, 7, width - 8, 5, "Sin tareas",
            colors.white, colors.gray)
        graphics.centerText(9, "Abre una aplicacion para empezar.", colors.lightGray, colors.gray)
    end
    graphics.button(2, height, width - 2, "VOLVER", colors.red)
    local event, side, _, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height then
        break
    end
end
