local arguments = {...}
print("Hola desde una app Lua de CANDOS.")
if #arguments > 0 then
    print("Argumentos recibidos:")
    for index, value in ipairs(arguments) do
        print(index .. ": " .. value)
    end
else
    print("Prueba: start hola.app hola mundo")
end
print("Toca cualquier tecla para volver.")
os.pullEvent("key")
