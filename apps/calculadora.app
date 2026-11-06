local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local result = "Toca CALCULAR para empezar"
local message = ""

local function draw()
    graphics.clear(colors.black)
    graphics.text(2, 1, "CALCULADORA", colors.white, colors.blue, width - 8)
    graphics.panel(2, 4, width - 4, 8, "Operacion", colors.white, colors.gray)
    graphics.text(4, 6, result, colors.white, colors.gray, width - 8)
    graphics.text(4, 8, message, colors.lightGray, colors.gray, width - 8)
    graphics.button(3, 14, 18, "CALCULAR", colors.green)
    graphics.button(23, 14, 14, "LIMPIAR", colors.gray)
    graphics.text(3, height - 2, "Ejemplo: 12.5 * 4", colors.lightGray)
end

local function calculate(expression)
    local left, operator, right = expression:match("^%s*(%-?[%d%.]+)%s*([%+%-%*/])%s*(%-?[%d%.]+)%s*$")
    left, right = tonumber(left), tonumber(right)
    if not left or not right then
        return nil, "Usa dos numeros y +, -, * o /."
    end
    if operator == "+" then
        return left + right
    elseif operator == "-" then
        return left - right
    elseif operator == "*" then
        return left * right
    elseif operator == "/" then
        if right == 0 then
            return nil, "No se puede dividir entre cero."
        end
        return left / right
    end
end

while true do
    draw()
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == 14 then
        if x >= 3 and x <= 20 then
            local expression = input("Escribe una operacion")
            local value, error_message = calculate(expression)
            if value then
                result = expression .. " = " .. tostring(value)
                message = ""
            else
                result = expression
                message = error_message
            end
        elseif x >= 23 and x <= 36 then
            result = "Toca CALCULAR para empezar"
            message = ""
        end
    end
end
