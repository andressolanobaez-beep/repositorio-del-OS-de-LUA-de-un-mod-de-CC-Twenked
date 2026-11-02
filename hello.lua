--[[
  Hola Mundo optimizado para CC: Tweaked
  Muestra texto en la pantalla externa con formateo
--]]

-- Configurar colores si hay monitor
if monitor then
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

cprint = function(...)
    local args = {...}
    local text = table.concat(args, " ")
    if monitor then
        monitor.write(text)
        monitor.setCursorPos(monitor.getCursorPosX() + #text, 1)
    end
    -- También imprimir en consola (será redirectado)
    term.write(text .. " ")
end

-- Programa principal
cprint("=== Hola Mundo desde CC: Tweaked ===")
cprint("Versión: 1.21.1 Fabric")
cprint("")
cprint("Bienvenido a tu sistema adaptado de MicroPython")
cprint("Tu ESPAndOS en el mundo de Minecraft!")
cprint("")
cprint("Presiona 'h' para ayuda o 'exit' para salir.")