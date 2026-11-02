--[[
  ESPAndOS-to-CC-Tweaked Terminal Bridge
  Adaptado para: CC: Tweaked 1.21.1 + Fabric
  Redirige la terminal completa a una pantalla externa
  
  Hardware esperado:
  - Monitor conectado arriba (peripheral "monitor")
  - 2 Disk Drives conectados a los lados (peripheral "disk_drive")
  - Speaker/Sensor atrás para buzzer (peripheral "speaker")
  
  Este archivo debe colocarse como startup.lua en el computador
--]]

-- Configuración de hardware
local MONITOR_POSITION = "top"
local SPEAKER_POSITION = "back"
local DISK_SIDES = {"left", "right"}

-- Función para encontrar y envolver periféricos
local function setup_peripheral(name, side)
    local perip = peripheral.find(name)
    if not perip and side then
        if peripheral.isPresent(side) then
            perip = peripheral.wrap(side)
        end
    end
    return perip
end

-- Inicializar monitor
local monitor = setup_peripheral("monitor", MONITOR_POSITION)
if not monitor then
    error("No se encontró monitor peripheral en posición: " .. tostring(MONITOR_POSITION))
end

-- Configurar monitor
monitor.setTextScale(1)
monitor.clear()
monitor.setCursorPos(1, 1)

-- Redirigir stdout/stderr a el monitor
-- En CC: Tweaked, term.redirect() redirige la terminal
local old_term = term.current()
term.redirect(monitor)

-- Inicializar speaker/buzzer
local speaker = setup_peripheral("speaker", SPEAKER_POSITION)
local buzzer_enabled = speaker ~= nil

-- Estado del buzzer
buzzer_state = {
    frequency = 440,
    duration = 0.1,
    active = false
}

-- Función para reproducir tono 8-bit
local function play_tone(freq, duration)
    if not buzzer_enabled then return end
    freq = freq or 440
    duration = duration or 0.1
    
    -- En CC: Tweaked, speaker.playTone(freq, duration)
    if speaker.playTone then
        speaker.playTone(freq, duration)
    else
        -- Fallback: parpadeo de monitor o simple delay
        monitor.setBackgroundColor(colors.gray)
        monitor.clear()
        os.sleep(duration)
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
    end
end

-- Función para reproducir escala 8-bit (tipo ESP32 buzzer)
local function play_scale()
    -- Notas 8-bit clásicas (C4 a C5): Do, Do#, Re, Re#, Mi, Fa, Fa#, Sol
    local notes = {262, 277, 294, 311, 330, 349, 370, 392, 415, 440, 466, 494, 523}
    for _, freq in ipairs(notes) do
        play_tone(freq, 0.05)
        os.sleep(0.02)
    end
end

-- Función para escribir en monitor (ya redirigido)
local function cprint(...)
    local args = {...}
    local text = table.concat(args, " ")
    monitor.write(text)
    -- También mantener sincronizado con la consola original si es necesario
    -- term.write(text) --esto causaría recursión, así que omitimos
end

-- Función para limpiar pantalla
local function clear_screen()
    monitor.clear()
    monitor.setCursorPos(1, 1)
    -- También limpiar la "consola" original redirectada
    term.clear()
    term.setCursorPos(1, 1)
end

-- Función para mostrar el "ESPAndOS" banner
local function show_banner()
    clear_screen()
    cprint("=== ESPAndOS Bridge for CC: Tweaked ===")
    cprint("=== Adaptado de MicroPython ESP32 ===")
    cprint("")
    cprint("Terminal redirigida a pantalla externa")
    cprint("Disqueteras: Lado izquierdo y derecho")
    cprint("Buzzer: Altavoz atrás")
    cprint("")
    cprint("Comandos disponibles:")
    cprint("  help    - Mostrar ayuda")
    cprint("  cls     - Limpiar pantalla")
    cprint("  tone    - Reproducir tono")
    cprint("  scale   - Reproducir escala 8-bit")
    cprint("  reboot  - Reiniciar sistema")
    cprint("  dir     - Listar disqueteras")
    cprint("  exit    - Salir")
    cprint("")
    cprint("Usa 'wget URL' para descargar programas como en MicroPython")
end

-- Función principal de ayuda
local function show_help()
    clear_screen()
    cprint("=== AYUDA - ESPAndOS Bridge ===")
    cprint("")
    cprint("Comandos del sistema:")
    cprint("  help    - Esta ayuda")
    cprint("  cls     - Limpiar pantalla")
    cprint("  clear   - Igual que cls")
    cprint("")
    cprint("Comandos de audio:")
    cprint("  tone    - Reproducir tono simple")
    cprint("  scale   - Reproducir escala completa 8-bit")
    cprint("")
    cprint("Comandos de archivos:")
    cprint("  dir     - Mostrar contenido de disqueteras")
    cprint("  load    - Cargar programa desde disco")
    cprint("")
    cprint("Comandos del sistema:")
    cprint("  reboot  - Reiniciar el computador")
    cprint("  exit    - Cerrar terminal")
    cprint("")
    cprint("Nota: Todo output va a la pantalla externa")
    cprint("Usa 'wget URL' para descargar programas")
end

-- Función para listar disqueteras
local function list_disks()
    clear_screen()
    cprint("=== Disc Drives ===")
    local found = 0
    for _, side in ipairs(DISK_SIDES) do
        if peripheral.isPresent(side) then
            local disk = peripheral.wrap(side)
            local label = disk.getLabel() or "Sin nombre"
            cprint("  [" .. found .. "] " .. side .. ": " .. label)
            found = found + 1
        else
            cprint("  [" .. found .. "] " .. side .. ": No hay disco")
            found = found + 1
        end
    end
    cprint("")
    cprint("Presiona cualquier tecla para continuar...")
    -- Esperar tecla - en CC: Tweaked usamos os.pullEvent
    local event = os.pullEvent("key")
end

-- Función de carga de programa
local function load_program()
    list_disks()
    cprint("Nombre del archivo a cargar: ")
    local filename = read():gsub("^%s*(.-)%s*$", "%1")
    if filename == "" then
        cprint("Nombre de archivo inválido")
        os.sleep(1)
        return
    end
    
    -- Intentar en ambas disqueteras
    for _, side in ipairs(DISK_SIDES) do
        if peripheral.isPresent(side) then
            local disk = peripheral.wrap(side)
            if disk.exists(filename) then
                local content = disk.read(filename)
                -- Ejecutar el programa cargado
                local func, err = load(content, filename, "t", _G)
                if func then
                    setfenv(func, _G)
                    -- Ejecutar en paralelo para no bloquear
                    local ok, err2 = pcall(func)
                    if ok then
                        cprint("Programa ejecutado desde " .. side)
                    else
                        cprint("Error al ejecutar: " .. tostring(err2))
                    end
                else
                    cprint("Error al cargar: " .. tostring(err))
                end
                return
            end
        end
    end
    cprint("Archivo no encontrado en ninguna disquetera")
    os.sleep(1)
end

-- Función de reinicio
local function system_reboot()
    cprint("Reiniciando ESPAndOS...")
    os.sleep(1)
    -- En CC: Tweaked, reiniciar se hace con os.reboot()
    os.reboot()
end

-- Función principal de eventos
local function handle_events()
    while true do
        local event = os.pullEvent()
        
        if event == "key" then
            local key = param1
            local char = string.char(key)
            
            if key == 28 then -- Enter
                cprint("\n")
            elseif key == 14 then -- Backspace
                local cx, cy = monitor.getCursorPos()
                if cx > 1 then
                    monitor.setCursorPos(cx - 1, cy)
                    monitor.write(" ")
                    monitor.setCursorPos(cx - 1, cy)
                end
            elseif char == "h" or char == "H" then
                show_help()
            elseif char == "c" or char == "C" then
                clear_screen()
            elseif char == "t" or char == "T" then
                play_tone()
            elseif char == "s" or char == "S" then
                play_scale()
            elseif char == "d" or char == "D" then
                list_disks()
            elseif char == "l" or char == "L" then
                load_program()
            elseif char == "r" or char == "R" then
                system_reboot()
            elseif char == "e" or char == "E" then
                cprint("Saliendo...")
                os.sleep(1)
                term.redirect(old_term)
                monitor.clear()
                monitor.setVisible(false)
                error("Sistema detenido por usuario")
            end
        end
    end
end

-- Programa principal
cprint("=== ESPAndOS Bridge Iniciando ===")
cprint("Redirigiendo terminal a pantalla externa...")

-- Mostrar banner inicial
show_banner()

-- Iniciar manejador de eventos en background usando parallel
-- En CC: Tweaked, usamos paralelo
parallel.waitForAll(handle_events)