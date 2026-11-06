local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local result = "Elige una conversion."
local conversions = {
    {name = "Celsius a Fahrenheit", convert = function(value) return value * 9 / 5 + 32 end, suffix = " F"},
    {name = "Fahrenheit a Celsius", convert = function(value) return (value - 32) * 5 / 9 end, suffix = " C"},
    {name = "Kilometros a millas", convert = function(value) return value * 0.621371 end, suffix = " mi"},
    {name = "Millas a kilometros", convert = function(value) return value / 0.621371 end, suffix = " km"},
    {name = "Metros a pies", convert = function(value) return value * 3.28084 end, suffix = " ft"},
    {name = "Kilogramos a libras", convert = function(value) return value * 2.20462 end, suffix = " lb"}
}

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "CONVERTIDOR", colors.white, colors.blue, width - 8)
    local first_y = 5
    for index, conversion in ipairs(conversions) do
        graphics.button(3, first_y + index * 3, width - 6,
            conversion.name, colors.gray)
    end
    graphics.panel(3, height - 7, width - 6, 3, nil, colors.white, colors.blue)
    graphics.text(4, height - 6, result, colors.white, colors.blue, width - 8)
    graphics.button(2, height, width - 2, "CERRAR", colors.red)

    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side then
        if y == height then
            break
        end
        local index = math.floor((y - first_y - 1) / 3)
        local conversion = conversions[index]
        if conversion then
            local value = tonumber(input("Valor para " .. conversion.name, "", "number"))
            if value then
                result = string.format("%.3f%s", conversion.convert(value), conversion.suffix)
            else
                result = "Escribe un valor numerico."
            end
        end
    end
end
