local graphics, monitor = candOS.graphics, candOS.monitor
local width, height = monitor.getSize()
local questions = {
    {q = "Cuantos bits tiene un byte?", a = {"4", "8", "16", "32"}, correct = 2},
    {q = "Que planeta es conocido como rojo?", a = {"Venus", "Marte", "Jupiter", "Mercurio"}, correct = 2},
    {q = "Cuanto es 9 x 7?", a = {"56", "63", "72", "81"}, correct = 2},
    {q = "Cual es el oceano mas grande?", a = {"Atlantico", "Indico", "Pacifico", "Artico"}, correct = 3},
    {q = "Que lenguaje usa este sistema?", a = {"Lua", "Ruby", "Swift", "Go"}, correct = 1}
}
local order, question_index, score = {}, 1, 0
for index = 1, #questions do order[index] = index end
for index = #order, 2, -1 do
    local other = math.random(1, index)
    order[index], order[other] = order[other], order[index]
end
local message = "Selecciona la respuesta correcta."
local finished = false

while true do
    graphics.clear(colors.black)
    graphics.text(2, 2, "TRIVIA RAPIDA", colors.white, colors.blue, width - 8)
    graphics.text(3, 4, "Puntos: " .. score .. " | Pregunta: " ..
        math.min(question_index, #questions) .. "/" .. #questions, colors.lightGray)
    if not finished then
        local item = questions[order[question_index]]
        graphics.panel(3, 6, width - 6, 4, "Pregunta", colors.white, colors.gray)
        graphics.text(5, 8, item.q, colors.white, colors.gray, width - 10)
        for index, answer in ipairs(item.a) do
            graphics.button(4, 11 + (index - 1) * 2, width - 8,
                index .. ". " .. answer, colors.blue)
        end
    else
        graphics.panel(4, 8, width - 8, 8, "Fin de la trivia",
            colors.white, colors.gray)
        graphics.centerText(12, "Puntuacion: " .. score .. "/" .. #questions,
            colors.yellow, colors.gray)
    end
    graphics.text(3, height - 2, message, colors.lightGray, colors.black, width - 6)
    graphics.button(width - 13, height, 12, "CERRAR", colors.red)
    local event, side, x, y = os.pullEvent()
    if event == "monitor_touch" and side == candOS.monitor_side and y == height then
        break
    elseif event == "monitor_touch" and side == candOS.monitor_side and y >= 11 and y <= 17 and not finished then
        local answer = math.floor((y - 11) / 2) + 1
        local item = questions[order[question_index]]
        if answer == item.correct then
            score = score + 1
            message = "Correcto."
        else
            message = "La respuesta era " .. item.a[item.correct] .. "."
        end
        question_index = question_index + 1
        if question_index > #questions then finished = true end
    elseif event == "monitor_touch" and side == candOS.monitor_side and y == height then
        break
    end
end
