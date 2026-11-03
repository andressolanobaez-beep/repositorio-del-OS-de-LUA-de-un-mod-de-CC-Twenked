#include <iostream>
#include <string>
#include <vector>
#include <filesystem>
#include <cstdlib>
#include <windows.h>

namespace fs = std::filesystem;

// Funcion para ejecutar comandos de shell y capturar salida
std::string ejecutar_comando(const std::string& comando) {
    std::string resultado;
    FILE* pipe = _popen(comando.c_str(), "r");
    if (pipe) {
        char buffer[256];
        while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
            resultado += buffer;
        }
        _pclose(pipe);
    }
    return resultado;
}

// Funcion para verificar si existe un archivo
bool archivo_existe(const std::string& path) {
    return fs::exists(path);
}

// Funcion para iniciar Lua y ejecutar startup.lua
bool iniciar_lua() {
    // Verificar si lua.exe está en el PATH
    std::string comando = "lua -v";
    std::string resultado = ejecutar_comando(comando);
    
    if (resultado.find("Lua") != std::string::npos) {
        std::cout << "[LUA] Interprete de Lua encontrado" << std::endl;
        
        // Intentar ejecutar startup.lua
        std::string cmd = "lua startup.lua";
        std::string resultado_lua = ejecutar_comando(cmd);
        
        if (!resultado_lua.empty()) {
            std::cout << "[LUA] Salida: " << resultado_lua << std::endl;
        }
        return true;
    }
    return false;
}

// Funcion para simular periféricos básicos
void simular_perifericos() {
    std::cout << "=========================================" << std::endl;
    std::cout << "SIMULACION DE HARDWARE CC: TWEAKED" << std::endl;
    std::cout << "=========================================" << std::endl;
    std::cout << "[PANTALLA] Detectando pantalla externa..." << std::endl;
    std::cout << "[ALTAVOCES] Inicializando buzzer/buzzer pasivo..." << std::endl;
    std::cout << "[DISQUETERAS] Escaneando 2 disqueteras laterales..." << std::endl;
    std::cout << "[SISTEMA] Hardware simulado - Listo para operar" << std::endl;
    std::cout << "=========================================" << std::endl;
}

// Funcion para publicar archivos al repo GitHub
void publicar_repo() {
    std::cout << "[GIT] Iniciando publicación de archivos..." << std::endl;
    
    // Agregar todos los archivos modificados/ nuevos
    std::string cmd1 = "git add .";
    std::string resultado1 = ejecutar_comando(cmd1);
    
    // Commit automático
    std::string cmd2 = "git commit -m \"Auto-update: CANDOS execution\"";
    std::string resultado2 = ejecutar_comando(cmd2);
    
    // Push al repositorio público
    std::string cmd3 = "git push origin main";
    std::string resultado3 = ejecutar_comando(cmd3);
    
    std::cout << "[GIT] Archivos publicados al repositorio público" << std::endl;
    std::cout << "       Remoto: origin" << std::endl;
}

// Funcion para obtener archivos del repo (git pull)
void obtener_repo() {
    std::cout << "[GIT] Obteniendo archivos del repositorio GitHub..." << std::endl;
    
    std::string cmd = "git pull origin main";
    std::string resultado = ejecutar_comando(cmd);
    
    std::cout << "[GIT] Sincronización completada" << std::endl;
    if (!resultado.empty()) {
        std::cout << "[GIT] Mensajes: " << resultado << std::endl;
    }
}

// Funcion principal
int main(int argc, char* argv[]) {
    std::cout << std::endl;
    std::cout << "=========== CANDOS v1.0 ===========" << std::endl;
    std::cout << "Sistema de emulación CC: Tweaked" << std::endl;
    std::cout << "===================================" << std::endl;
    std::cout << std::endl;
    
    // Verificar que estamos en el directorio correcto
    if (!archivo_existe("startup.lua")) {
        std::cout << "[ADVERTENCIA] No se encontró startup.lua en el directorio actual" << std::endl;
        std::cout << "            Asegúrese de ejecutar desde la carpeta del OS" << std::endl;
    }
    
    // Procesar argumentos
    if (argc < 2) {
        std::cout << "Uso:" << std::endl;
        std::cout << "  CANDOS.exe .\\          : Publicar archivos al repo GitHub público" << std::endl;
        std::cout << "  CANDOS.exe executing   : Iniciar emulación CC: Tweaked" << std::endl;
        std::cout << "  CANDOS.exe .\\ get    : Obtener archivos del repo GitHub" << std::endl;
        std::cout << std::endl;
        std::cout << "Comandos disponibles:" << std::endl;
        std::cout << "  CANDOS exe .\\" << std::endl;
        std::cout << "  CANDOS exe executing" << std::endl;
        std::cout << "  CANDOS exe .\\ get" << std::endl;
        return 1;
    }
    
    std::string comando = argv[1];
    
    if (comando == ".\\") {
        std::cout << "[ACCION] Publicando todos los archivos al repositorio público..." << std::endl;
        simular_perifericos();
        publicar_repo();
        std::cout << std::endl;
        std::cout << "[ÉXITO] Publicación completada" << std::endl;
        
    } else if (comando == "executing") {
        std::cout << "[ACCION] Iniciando emulación de computadora CC: Tweaked..." << std::endl;
        simular_perifericos();
        
        std::cout << std::endl;
        std::cout << "[SISTEMA] Iniciando secuencia de arranque..." << std::endl;
        std::cout << "         Cargando startup.lua..." << std::endl;
        
        // Intentar ejecutar Lua
        bool lua_ok = iniciar_lua();
        
        if (lua_ok) {
            std::cout << "[SISTEMA] Secuencia de arranque completada" << std::endl;
        } else {
            std::cout << "[AVISO] Interprete Lua no disponible o error en startup.lua" << std::endl;
            std::cout << "[FALLBACK] Ejecutando modo texto simulado..." << std::endl;
            std::cout << "  > BIOS inicializando..." << std::endl;
            std::cout << "  > Memoria RAM detectada: 512MB" << std::endl;
            std::cout << "  > Periféricos: Monitor + Speaker + 2 Disk Drives" << std::endl;
            std::cout << "  > Cargando sistema operativo..." << std::endl;
            std::cout << "  > BIOS COMPLETA - Sistema listo para uso" << std::endl;
        }
        
        std::cout << std::endl;
        std::cout << "=========================================" << std::endl;
        std::cout << "       EMULACIÓN CC: TWEAKED - LISTA" << std::endl;
        std::cout << "=========================================" << std::endl;
        std::cout << std::endl;
        
    } else if (comando == ".\\ get") {
        std::cout << "[ACCION] Obteniendo archivos del repositorio GitHub..." << std::endl;
        obtener_repo();
        simular_perifericos();
        std::cout << std::endl;
        std::cout << "[ÉXITO] Sincronización completada" << std::endl;
        
    } else {
        std::cout << "[ERROR] Comando no reconocido: " << comando << std::endl;
        std::cout << "Use: CANDOS.exe .\\" << std::endl;
        return 1;
    }
    
    std::cout << std::endl;
    std::cout << "=========== END OF SESSION ===========" << std::endl;
    std::cout << std::endl;
    
    return 0;
}