local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local rows = {
    "Monitor: " .. width .. "x" .. height,
    "Computador: " .. (os.getComputerLabel() or tostring(os.getComputerID())),
    "Altavoz: " .. (peripheral.getType("back") == "speaker" and "conectado" or "no conectado")
}

for _, side in ipairs({"left", "right"}) do
    if peripheral.getType(side) == "drive" then
        local mount = peripheral.wrap(side).getMountPath()
        rows[#rows + 1] = side .. ": " ..
            (mount and ("disco en /" .. mount) or "sin disco")
    else
        rows[#rows + 1] = side .. ": sin lectora"
    end
end

graphics.clear(colors.black)
graphics.text(2, 1, "DISPOSITIVOS", colors.white, colors.blue, width - 8)
graphics.panel(2, 4, width - 4, height - 12, "Estado del sistema",
    colors.white, colors.gray)
for index, text in ipairs(rows) do
    graphics.text(4, 6 + index, text, colors.white, colors.gray, width - 8)
end
graphics.button(math.floor((width - 14) / 2), height - 3, 14,
    "VOLVER", colors.blue)

while true do
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side
        and y == height - 3 then
        break
    end
end
