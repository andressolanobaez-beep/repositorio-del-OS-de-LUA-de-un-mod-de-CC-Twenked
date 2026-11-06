-- Audio para el peripheral speaker de CC: Tweaked.
-- El speaker reproduce notas musicales; no genera tonos de frecuencia arbitraria.

local speaker = peripheral.wrap("back")
if peripheral.getType("back") ~= "speaker" then
    speaker = peripheral.find("speaker")
end

if not speaker then
    print("No se detecto un speaker. Conecta el altavoz al computador.")
    return
end

local A4 = 440
local MIN_FREQUENCY = A4 * 2 ^ (-15 / 12)
local MAX_FREQUENCY = A4 * 2 ^ (9 / 12)

local NOTES = {
    {name = "C4", frequency = 262},
    {name = "C#4", frequency = 277},
    {name = "D4", frequency = 294},
    {name = "D#4", frequency = 311},
    {name = "E4", frequency = 330},
    {name = "F4", frequency = 349},
    {name = "F#4", frequency = 370},
    {name = "G4", frequency = 392},
    {name = "G#4", frequency = 415},
    {name = "A4", frequency = 440},
    {name = "A#4", frequency = 466},
    {name = "B4", frequency = 494},
    {name = "C5", frequency = 523}
}

local SONGS = {
    happy_birthday = {
        notes = {8, 8, 8, 5, 5, 6, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 2, 1, 1, 2, 6},
        beats = {1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2}
    },
    old_macdonald = {
        notes = {3, 3, 3, 2, 2, 3, 2, 1, 3, 3, 3, 2, 2, 3, 2, 1, 5, 5, 4, 4, 5, 5, 6, 6, 5, 5, 4},
        beats = {1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
    }
}

local function play_frequency(frequency, duration)
    frequency = tonumber(frequency)
    if not frequency or frequency < MIN_FREQUENCY or frequency > MAX_FREQUENCY then
        print(string.format("Frecuencia fuera del rango del speaker (%.0f-%.0f Hz).",
            MIN_FREQUENCY, MAX_FREQUENCY))
        return false
    end

    local semitones = 12 * (math.log(frequency / A4) / math.log(2))
    local pitch = 15 + semitones
    local accepted = speaker.playNote("harp", 1, pitch)
    if not accepted then
        print("El speaker tiene la cola de audio llena; espera un momento.")
        return false
    end
    os.sleep(duration or 0.3)
    return true
end

local function play_scale()
    for _, note in ipairs(NOTES) do
        if not play_frequency(note.frequency, 0.25) then
            return
        end
    end
    print("Escala C4-C5 completada.")
end

local function play_song(name)
    local song = SONGS[name]
    if not song then
        print("Canciones disponibles: happy_birthday, old_macdonald")
        return
    end

    for index, note_number in ipairs(song.notes) do
        local note = NOTES[note_number]
        if note and not play_frequency(note.frequency, (song.beats[index] or 1) * 0.25) then
            return
        end
        os.sleep(0.05)
    end
    print("Cancion terminada: " .. name)
end

local function run(action, value)
    if action == "scale" then
        play_scale()
    elseif action == "tone" then
        play_frequency(value)
    elseif action == "song" then
        play_song(value or "")
    else
        print("Uso: buzzer.lua scale | tone <Hz> | song <nombre>")
        print("Rango aproximado: " .. string.format("%.0f-%.0f Hz", MIN_FREQUENCY, MAX_FREQUENCY))
    end
end

local action, value = ...
if action then
    run(action:lower(), value)
else
    print("Comandos: scale, tone <Hz>, song <nombre>, exit")
    while true do
        write("buzzer> ")
        local words = {}
        for word in read():gmatch("%S+") do
            words[#words + 1] = word
        end
        if words[1] == "exit" then
            break
        end
        run((words[1] or ""):lower(), words[2])
    end
end
