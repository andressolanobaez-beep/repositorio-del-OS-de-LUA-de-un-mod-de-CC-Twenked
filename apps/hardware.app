print("=== Estado del hardware ===")
if candOS.monitor then
    local width, height = candOS.monitor.getSize()
    print("Monitor superior: " .. width .. "x" .. height .. " caracteres")
else
    print("Monitor: no detectado")
end

for _, side in ipairs({"left", "right"}) do
    if peripheral.getType(side) == "drive" then
        local drive = peripheral.wrap(side)
        local mount = drive.getMountPath()
        print(side .. ": lectora conectada; " ..
            (mount and ("disco montado en " .. mount) or "sin disco"))
    else
        print(side .. ": lectora no detectada")
    end
end

print("Altavoz trasero: " ..
    (peripheral.getType("back") == "speaker" and "conectado" or "no detectado"))
print("Computador: " .. (os.getComputerLabel() or tostring(os.getComputerID())))
print("Toca cualquier tecla para volver.")
os.pullEvent("key")
