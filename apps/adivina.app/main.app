local graphics = candOS.graphics
local monitor = candOS.monitor
local width, height = monitor.getSize()
local target = math.random(1, 100)
local attempts = 0
local message = "Estoy pensando en un numero del 1 al 100."

while true do
    graphics.clear(colors.black)
    graphics.text(2, 1, "ADIVINA EL NUMERO", colors.white, colors.blue, width - 8)
    graphics.panel(3, 4, width - 6, 9, "Juego", colors.white, colors.gray)
    graphics.centerText(7, message, colors.white, colors.gray)
    graphics.centerText(9, "Intentos: " .. attempts, colors.lightGray, colors.gray)
    graphics.button(5, 16, 20, "PROBAR NUMERO", colors.green)
    graphics.button(29, 16, 16, "NUEVO", colors.blue)
    graphics.text(3, height - 2, "Usa el teclado grafico.", colors.lightGray)

    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == 16 then
        if x >= 5 and x < 25 then
            local guess = tonumber(input("Tu numero", "", "number"))
            if guess then
                attempts = attempts + 1
                if guess == target then
                    message = "Correcto! Era " .. target .. "."
                elseif guess < target then
                    message = "Prueba con un numero mas alto."
                else
                    message = "Prueba con un numero mas bajo."
                end
            else
                message = "Escribe un numero valido."
            end
        elseif x >= 29 and x <= 45 then
            target = math.random(1, 100)
            attempts = 0
            message = "Nuevo numero. Adivinalo!"
        end
    end
end
