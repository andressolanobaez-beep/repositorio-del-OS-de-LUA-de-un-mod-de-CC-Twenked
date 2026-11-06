local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local words = {"TECLADO", "PANTALLA", "SISTEMA", "CARPETA", "VENTANA",
    "ARCHIVO", "MODULAR", "PROGRAMA"}
local word = words[math.random(1, #words)]
local letters = {}
for index = 1, #word do letters[index] = word:sub(index, index) end
for index = #letters, 2, -1 do
    local other = math.random(1, index)
    letters[index], letters[other] = letters[other], letters[index]
end
local scrambled = table.concat(letters)
local message, points = "Ordena las letras escribiendo la palabra.", 0

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "PALABRA REVUELTA", colors.white, colors.blue, width - 8)
    graphics.panel(4, 6, width - 8, 8, "Letras", colors.white, colors.gray)
    graphics.centerText(10, scrambled, colors.yellow, colors.gray)
    graphics.text(3, 17, message, colors.lightGray, colors.black, width - 6)
    graphics.text(3, 19, "Resueltas: " .. points, colors.white)
    graphics.button(4, height - 3, 20, "RESPONDER", colors.green)
    graphics.button(width - 21, height - 3, 18, "NUEVA", colors.blue)
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height - 3 then
        if x < width / 2 then
            local guess = input("Escribe la palabra", "", "text"):upper()
            if guess == word then
                points = points + 1
                message = "Correcto! Era " .. word .. "."
            else
                message = "Intentalo de nuevo."
            end
        else
            word = words[math.random(1, #words)]
            letters = {}
            for index = 1, #word do letters[index] = word:sub(index, index) end
            for index = #letters, 2, -1 do
                local other = math.random(1, index)
                letters[index], letters[other] = letters[other], letters[index]
            end
            scrambled = table.concat(letters)
            message = "Ordena las letras escribiendo la palabra."
        end
    end
end
