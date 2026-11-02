--[[
  Buzzer/Booster 8-bit para CC: Tweaked
  Reproduce ondas cuadradas similares al buzzer pasivo de ESP32
  
  Hardware: Speaker peripheral en la parte posterior del computador
  
  Comandos:
  - buzzer tone <frecuencia> : Tono simple
  - buzzer scale : Escala completa 8-bit
  - buzzer play <archivo> : Reproducir patrón de archivo
--]]

-- Verificar que hay speaker
local speaker = peripheral.find("speaker")
if not speaker then
    error("No se encontró peripheral 'speaker'. Conecta un altavoz al lado 'back' del computador.")
end

-- Notas musicales 8-bit (C4 a C5, 13 notas)
local NOTES_8BIT = {
    {name = "C-4", freq = 262},
    {name = "C#-4", freq = 277},
    {name = "D-4", freq = 294},
    {name = "D#-4", freq = 311},
    {name = "E-4", freq = 329},
    {name = "F-4", freq = 349},
    {name = "F#-4", freq = 370},
    {name = "G-4", freq = 392},
    {name = "G#-4", freq = 415},
    {name = "A-4", freq = 440}, -- La4
    {name = "A#-4", freq = 466},
    {name = "B-4", freq = 494},
    {name = "C-5", freq = 523}
}

-- Patrones de canción 8-bit simples
local SONGS = {
    -- "Happy Birthday" simplificado
    {
        name = "happy_birthday",
        notes = {8, 8, 8, 5, 5, 6, 5, -- Happy
                 4, 4, 3, 3, 2, -- You
                 2, 2, 1, 1, 2,  -- Are
                 1, 1, 2, 6},    -- Happy
        beats = {1, 1, 1, 1, 1, 2, 1, 
                 1, 1, 1, 1, 1, 
                 1, 1, 1, 1, 1, 
                 1, 1, 1, 2}
    },
    -- "Old MacDonald" simplificado
    {
        name = "old_macdonald",
        notes = {3, 3, 3, 2, 2, 3, 2, 1, -- Old MacDonald
                 3, 3, 3, 2, 2, 3, 2, 1, -- Farm
                 5, 5, 4, 4, 5, 5,  -- With
                 6, 6, 5, 5, 4}, -- A-
                         
        beats = {1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1}
    }
}

-- Reproducir un tono simple
local function play_simple_tone(freq, duration)
    -- Usar speaker.playTone si está disponible
    if speaker.playTone then
        speaker.playTone(freq, duration or 0.5)
    else
        -- Fallback: usar redstone
        redstone.setOutput("back", true)
        os.sleep(duration or 0.5)
        redstone.setOutput("back", false)
    end
end

-- Reproducir escala completa
local function play_scale()
    cprint "Reproduciendo escala 8-bit..."
    for _, note in ipairs(NOTES_8BIT) do
        play_simple_tone(note.freq, 0.1)
        os.sleep(0.05)
    end
    cprint "Termo escala completada"
end

-- Reproducir una canción por nombre
local function play_song(song_name)
    local song = nil
    for _, s in ipairs(SONGS) do
        if s.name == song_name then
            song = s
            break
        end
    end
    
    if not song then
        cprint "Canción no encontrada. Disponibles: happy_birthday, old_macdonald"
        return
    end
    
    cprint "Reproduciendo: " .. song.name
    
    local notes = song.notes
    local beats = song.beats
    
    for i, note_idx in ipairs(notes) do
        if note_idx >= 1 and note_idx <= #NOTES_8BIT then
            local freq = NOTES_8BIT[note_idx].freq
            local beat = beats[i] or 1
            local duration = beat * 0.5
            
            play_simple_tone(freq, duration)
            os.sleep(0.1) -- pausa entre notas
        end
    end
    
    cprint "Canción terminada"
end

-- Modo interactivo: escribir frecuencias
local function interactive_mode()
    cprint "=== Modo Buzzer Interactivo ==="
    cprint "Comandos:"
    cprint "  scale - Reproducir escala completa"
    cprint "  song <nombre> - Reproducir canción (happy_birthday, old_macdonald)"
    cprint "  freq <frecuencia> - Tono personalizado"
    cprint "  exit - Volver al menú principal"
    
    while true do
        cprint ">> "
        local cmd = read():gsub("^%s*(.-)%s*$", "%1")
        
        if cmd == "scale" then
            play_scale()
        elseif cmd:sub(1, 4) == "song" then
            local name = cmd:sub(6):gsub("^%s*(.-)%s*$", "%1")
            play_song(name)
        elseif cmd:sub(1, 3) == "freq" then
            local freq = tonumber(cmd:sub(5):gsub("^%s*(.-)%s*$", "%1"))
            if freq then
                play_simple_tone(freq, 0.3)
                cprint "Tono reproducido: " .. freq .. "Hz"
            else
                cprint "Frecuencia inválida"
            end
        elseif cmd == "exit" then
            break
        else
            cprint "Comando no reconocido. Escribe 'help' para ver comandos."
        end
    end
end

-- Programa principal
cprint "=== Buzzer 8-bit para CC: Tweaked ==="
cprint "Altavoz conectado al lado 'back' del computador"
cprint ""

-- Verificar si hay speaker
if peripheral.isPresent("back") then
    local back = peripheral.wrap("back")
    if back then
        cprint "Speaker detectado en lado 'back'"
    end
end

-- Menú principal
while true do
    cprint ""
    cprint "--- Menú Principal ---"
    cprint "  scale - Reproducir escala 8-bit completa"
    cprint "  song <nombre> - Reproducir canción"
    cprint "  freq <n> - Tono personalizado (frecuencia en Hz)"
    cprint "  exit - Volver al menú anterior"
    cprint ""
    
    local cmd = read():gsub("^%s*(.-)%s*$", "%1")
    
    if cmd == "scale" then
        play_scale()
    elseif cmd:sub(1, 3) == "song" then
        local name = cmd:sub(5):gsub("^%s*(.-)%s*$", "%1")
        play_song(name)
    elseif cmd:sub(1, 3) == "freq" then
        local freq = tonumber(cmd:sub(5):gsub("^%s*(.-)%s*$", "%1"))
        if freq then
            play_simple_tone(freq, 0.3)
            cprint "Tono: " .. freq .. "Hz reproducido"
        else
            cprint "Frecuencia inválida"
        end
    elseif cmd == "exit" then
        break
    else
        cprint "Comando no reconocido. Escribe 'help' para ayuda."
    end
end