print("CANDOS Terminal")
print("Usa shell.run para los comandos CANDOS y shell.cc para los de CC:Tweaked.")
print("Ejemplos: echo \"hola mundo\", path, where main.app, cc help, exit")

while true do
    write(shell.dir() .. "> ")
    local line = read()
    if line == "exit" then
        break
    elseif line:match("^cc%s+") then
        shell.cc(line:gsub("^cc%s+", "", 1))
    else
        local _, result = shell.run(line)
        if result == "exit" then
            break
        end
    end
end
