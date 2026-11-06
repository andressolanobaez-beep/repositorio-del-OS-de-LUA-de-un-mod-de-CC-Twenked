#include <iostream>
#include <string>
#include <vector>
#include <filesystem>
#include <cstdlib>
#include <windows.h>

namespace fs = std::filesystem;

// Declaración anticipada de funciones
void mostrar_wget_comandos(const std::string& branch);
bool publicar_repo();
bool obtener_repo();
bool archivo_existe(const std::string& path);

struct ResultadoComando {
    std::string resultado;
    int codigo_salida = -1;
};

// Ejecuta un comando y captura tanto stdout como stderr.
ResultadoComando ejecutar_comando(const std::string& comando) {
    ResultadoComando resultado;
    const std::string comando_con_errores = comando + " 2>&1";
    FILE* pipe = _popen(comando_con_errores.c_str(), "r");
    if (pipe) {
        char buffer[256];
        while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
            resultado.resultado += buffer;
        }
        resultado.codigo_salida = _pclose(pipe);
    }
    return resultado;
}

std::string quitar_espacios_externos(const std::string& texto) {
    const auto inicio = texto.find_first_not_of(" \t\r\n");
    if (inicio == std::string::npos) {
        return "";
    }
    const auto fin = texto.find_last_not_of(" \t\r\n");
    return texto.substr(inicio, fin - inicio + 1);
}

std::wstring obtener_variable_entorno(const wchar_t* nombre) {
    const DWORD longitud = GetEnvironmentVariableW(nombre, nullptr, 0);
    if (longitud == 0) {
        return L"";
    }

    std::wstring valor(longitud, L'\0');
    const DWORD caracteres = GetEnvironmentVariableW(nombre, valor.data(), longitud);
    if (caracteres == 0 || caracteres >= longitud) {
        return L"";
    }
    valor.resize(caracteres);
    return valor;
}

std::wstring citar_argumento_windows(const std::wstring& argumento) {
    std::wstring citado = L"\"";
    size_t barras = 0;
    for (wchar_t caracter : argumento) {
        if (caracter == L'\\') {
            ++barras;
        } else if (caracter == L'"') {
            citado.append(barras * 2 + 1, L'\\');
            citado += L'"';
            barras = 0;
        } else {
            citado.append(barras, L'\\');
            citado += caracter;
            barras = 0;
        }
    }
    citado.append(barras * 2, L'\\');
    citado += L'"';
    return citado;
}

bool iniciar_standalone_cc() {
    const std::wstring standalone_home_env = obtener_variable_entorno(L"CC_TWEAKED_HOME");
    const std::wstring java_home_env = obtener_variable_entorno(L"JAVA_HOME");
    if (standalone_home_env.empty()) {
        std::cerr << "[ERROR] Define CC_TWEAKED_HOME con la carpeta de un checkout "
                     "oficial de CC:Tweaked (rama mc-1.21.x)."
                  << std::endl;
        return false;
    }
    if (java_home_env.empty()) {
        std::cerr << "[ERROR] Define JAVA_HOME con un JDK 21 o posterior. "
                     "El Java disponible en PATH no sustituye este requisito."
                  << std::endl;
        return false;
    }

    const fs::path standalone_home(standalone_home_env);
    const fs::path java_executable = fs::path(java_home_env) / "bin" / "java.exe";
    const fs::path wrapper_jar =
        standalone_home / "gradle" / "wrapper" / "gradle-wrapper.jar";
    const fs::path resources =
        standalone_home / "projects" / "core" / "src" / "main" / "resources";
    const fs::path computer_root = fs::current_path();

    if (!fs::exists(standalone_home / "gradlew.bat") ||
        !fs::exists(wrapper_jar) ||
        !fs::exists(resources) ||
        !fs::is_directory(resources)) {
        std::cerr << "[ERROR] CC_TWEAKED_HOME no parece ser la raiz del "
                     "repositorio oficial CC:Tweaked: "
                  << standalone_home.string() << std::endl;
        return false;
    }
    if (!fs::exists(java_executable)) {
        std::cerr << "[ERROR] No se encontro java.exe dentro de JAVA_HOME: "
                  << fs::path(java_home_env).string() << std::endl;
        return false;
    }
    if (!archivo_existe("startup.lua") || !archivo_existe("shell.py")) {
        std::cerr << "[ERROR] Ejecuta CANDOS desde la carpeta que contiene "
                     "startup.lua y shell.py."
                  << std::endl;
        return false;
    }

    const std::wstring application_args =
        L"--resources " + citar_argumento_windows(resources.wstring()) +
        L" --computer " + citar_argumento_windows(computer_root.wstring()) +
        L" --term-size 80x40";
    const std::vector<std::wstring> argumentos = {
        java_executable.wstring(),
        L"-classpath",
        wrapper_jar.wstring(),
        L"org.gradle.wrapper.GradleWrapperMain",
        L":projects:standalone:run",
        L"--args",
        application_args
    };

    std::wstring linea_comandos;
    for (const std::wstring& argumento : argumentos) {
        if (!linea_comandos.empty()) {
            linea_comandos += L' ';
        }
        linea_comandos += citar_argumento_windows(argumento);
    }

    STARTUPINFOW inicio{};
    inicio.cb = sizeof(inicio);
    inicio.dwFlags = STARTF_USESTDHANDLES;
    inicio.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    inicio.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    inicio.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    PROCESS_INFORMATION proceso{};
    std::vector<wchar_t> linea_mutable(linea_comandos.begin(), linea_comandos.end());
    linea_mutable.push_back(L'\0');

    if (!CreateProcessW(
            java_executable.c_str(),
            linea_mutable.data(),
            nullptr,
            nullptr,
            TRUE,
            0,
            nullptr,
            standalone_home.c_str(),
            &inicio,
            &proceso)) {
        std::cerr << "[ERROR] No se pudo iniciar el Standalone oficial. "
                     "Verifica JAVA_HOME, CC_TWEAKED_HOME y JDK 21."
                  << std::endl;
        return false;
    }

    std::cout << "[CC:TWEAKED] Iniciando el proyecto oficial Standalone." << std::endl;
    std::cout << "[CC:TWEAKED] La raiz del computador virtual es: "
              << computer_root.string() << std::endl;
    std::cout << "[CC:TWEAKED] El computador virtual no tiene los perifericos "
                 "fisicos del mundo de Minecraft."
              << std::endl;

    CloseHandle(proceso.hThread);
    const DWORD espera = WaitForSingleObject(proceso.hProcess, INFINITE);
    DWORD codigo_salida = 1;
    const bool obtuvo_codigo =
        espera == WAIT_OBJECT_0 && GetExitCodeProcess(proceso.hProcess, &codigo_salida);
    CloseHandle(proceso.hProcess);

    if (!obtuvo_codigo || codigo_salida != 0) {
        std::cerr << "[CC:TWEAKED] El Standalone termino con error.";
        if (obtuvo_codigo) {
            std::cerr << " Codigo: " << codigo_salida;
        }
        std::cerr << std::endl;
        return false;
    }

    return true;
}

bool obtener_rama_actual(std::string& branch) {
    const ResultadoComando resultado = ejecutar_comando("git branch --show-current");
    branch = quitar_espacios_externos(resultado.resultado);
    if (resultado.codigo_salida != 0 || branch.empty()) {
        std::cerr << "[GIT] No se pudo determinar la rama actual.";
        if (!resultado.resultado.empty()) {
            std::cerr << "\n" << resultado.resultado;
        }
        std::cerr << std::endl;
        return false;
    }
    return true;
}

// Funcion para verificar si existe un archivo
bool archivo_existe(const std::string& path) {
    return fs::exists(path);
}

// Publica en la rama actual y solo informa éxito si Git termina correctamente.
bool publicar_repo() {
    std::cout << "[GIT] Iniciando publicación de archivos..." << std::endl;

    const ResultadoComando check_repo = ejecutar_comando("git rev-parse --is-inside-work-tree");
    if (check_repo.codigo_salida != 0) {
        std::cerr << "[GIT] Esta carpeta no es un repositorio Git.\n"
                  << check_repo.resultado;
        return false;
    }

    std::string branch;
    if (!obtener_rama_actual(branch)) {
        return false;
    }

    const ResultadoComando status = ejecutar_comando("git status --porcelain");
    if (status.codigo_salida != 0) {
        std::cerr << "[GIT] No se pudo revisar el estado del repositorio.\n"
                  << status.resultado;
        return false;
    }

    if (!quitar_espacios_externos(status.resultado).empty()) {
        const ResultadoComando add = ejecutar_comando("git add -A");
        if (add.codigo_salida != 0) {
            std::cerr << "[GIT] Falló git add -A.\n" << add.resultado;
            return false;
        }

        const ResultadoComando commit =
            ejecutar_comando("git commit -m \"Auto-update: CANDOS\"");
        if (commit.codigo_salida != 0) {
            std::cerr << "[GIT] No se pudo crear el commit.\n" << commit.resultado;
            return false;
        }
        std::cout << commit.resultado;
    } else {
        std::cout << "[GIT] No hay cambios locales nuevos para guardar." << std::endl;
    }

    const ResultadoComando push = ejecutar_comando("git push -u origin HEAD");
    if (push.codigo_salida != 0) {
        std::cerr << "[GIT] Falló la publicación a origin/" << branch << ".\n"
                  << push.resultado;
        return false;
    }

    std::cout << push.resultado;
    std::cout << "[GIT] Publicación completada en origin/" << branch << std::endl;
    mostrar_wget_comandos(branch);
    return true;
}

// Funcion para mostrar comandos wget de descarga
void mostrar_wget_comandos(const std::string& branch) {
    const std::string raw_base =
        "https://raw.githubusercontent.com/andressolanobaez-beep/"
        "repositorio-del-OS-de-LUA-de-un-mod-de-CC-Twenked/" + branch + "/";
    const std::vector<std::string> archivos = {
        "startup.lua",
        "hello.lua",
        "disk_manager.lua",
        "buzzer.lua",
        "utils.lua",
        "shell.py",
        "importing.txt",
        "apps/terminal.app",
        "apps/archivador.app",
        "apps/notas.app",
        "apps/hardware.app",
        "apps/hola.app"
    };

    std::cout << std::endl;
    std::cout << "=========================================" << std::endl;
    std::cout << "COMANDOS WGET PARA CC: TWEAKED" << std::endl;
    std::cout << "=========================================" << std::endl;
    std::cout << "Rama: " << branch << std::endl;
    std::cout << "Ejecuta estos comandos dentro del computador CC:Tweaked." << std::endl;
    std::cout << "Descargas individuales:" << std::endl;
    for (const std::string& archivo : archivos) {
        std::cout << "wget " << raw_base << archivo << " " << archivo << std::endl;
    }
    std::cout << "=========================================" << std::endl;
    std::cout << "Instrucciones para CC: Tweaked:" << std::endl;
    std::cout << "1. Crea la carpeta apps con: mkdir apps" << std::endl;
    std::cout << "2. Ejecuta cada wget; las apps se guardan en apps/." << std::endl;
    std::cout << "3. Reinicia el computador CC:Tweaked para iniciar el OS." << std::endl;
    std::cout << "=========================================" << std::endl;
    std::cout << std::endl;
}

// Funcion para obtener archivos del repo (git pull)
bool obtener_repo() {
    std::cout << "[GIT] Obteniendo archivos del repositorio GitHub..." << std::endl;

    std::string branch;
    if (!obtener_rama_actual(branch)) {
        return false;
    }

    const ResultadoComando pull =
        ejecutar_comando("git pull --ff-only origin \"" + branch + "\"");
    std::cout << pull.resultado;
    if (pull.codigo_salida != 0) {
        std::cerr << "[GIT] No se pudo sincronizar origin/" << branch << "."
                  << std::endl;
        return false;
    }

    std::cout << "[GIT] Sincronización completada desde origin/" << branch << std::endl;
    return true;
}

// Funcion principal
int main(int argc, char* argv[]) {
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);

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
        std::cout << "  CANDOS.exe publish   : Publicar cambios a la rama actual de origin" << std::endl;
        std::cout << "  CANDOS.exe get       : Obtener cambios de la rama actual de origin" << std::endl;
        std::cout << "  CANDOS.exe executing : Abrir el Standalone oficial de CC:Tweaked" << std::endl;
        std::cout << "  CANDOS.exe .\\        : Alias de publish" << std::endl;
        std::cout << "  Requiere JAVA_HOME (JDK 21+) y CC_TWEAKED_HOME (checkout oficial)." << std::endl;
        return 1;
    }

    std::string comando = argv[1];
    const bool legacy_get = (comando == "." || comando == ".\\") &&
                            argc >= 3 && std::string(argv[2]) == "get";

    if (!legacy_get && (comando == "publish" || comando == "push" ||
                        comando == "." || comando == ".\\")) {
        std::cout << "[ACCION] Publicando cambios a la rama local actual..." << std::endl;
        return publicar_repo() ? 0 : 1;

    } else if (comando == "get" || legacy_get) {
        std::cout << "[ACCION] Obteniendo cambios de la rama local actual..." << std::endl;
        return obtener_repo() ? 0 : 1;

    } else if (comando == "executing") {
        std::cout << "[ACCION] Iniciando el computador Standalone oficial..." << std::endl;
        return iniciar_standalone_cc() ? 0 : 1;

    } else {
        std::cout << "[ERROR] Comando no reconocido: " << comando << std::endl;
        std::cout << "Usa: CANDOS.exe publish | get | executing" << std::endl;
        return 1;
    }
}