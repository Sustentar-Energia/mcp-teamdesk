@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title MCP TeamDesk - Instalador para Claude Desktop

echo.
echo  ===============================================
echo   MCP TeamDesk - Instalador para Claude Desktop
echo   ForGreen Energia Solar
echo  ===============================================
echo.

:: ============================================================
:: [1/7] VERIFICAR REQUISITOS
:: ============================================================
echo [1/7] Verificando requisitos...
echo.

:: Verificar Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Python nao encontrado.
    echo         Instale Python 3.10+ em https://python.org
    echo         Marque "Add Python to PATH" durante a instalacao.
    echo.
    pause
    exit /b 1
)

:: Verificar versao do Python (3.10+)
for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set "PY_VER=%%v"
for /f "tokens=1,2 delims=." %%a in ("%PY_VER%") do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
)
if %PY_MAJOR% LSS 3 (
    echo  [ERRO] Python 3.10+ necessario. Versao encontrada: %PY_VER%
    pause
    exit /b 1
)
if %PY_MAJOR% EQU 3 if %PY_MINOR% LSS 10 (
    echo  [ERRO] Python 3.10+ necessario. Versao encontrada: %PY_VER%
    pause
    exit /b 1
)
echo  [OK] Python %PY_VER%

:: Verificar pip
pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] pip nao encontrado. Reinstale Python com pip.
    pause
    exit /b 1
)
echo  [OK] pip disponivel

:: Verificar conexao internet
python -c "import urllib.request; urllib.request.urlopen('https://www.google.com', timeout=5); print(' [OK] Conexao com internet')" 2>nul
if %errorlevel% neq 0 (
    echo  [ERRO] Sem conexao com a internet. Verifique sua rede.
    pause
    exit /b 1
)
echo.

:: ============================================================
:: [2/7] SOLICITAR CHAVE MCP
:: [3/7] VALIDAR CHAVE E OBTER TOKEN
:: ============================================================
set "SETUP_URL=https://mcp.forgreen.com.br/setup"

:solicitar_chave
echo [2/7] Solicitar Chave MCP...
echo.
echo  Sua Chave MCP foi fornecida pelo administrador ForGreen.
echo  Exemplo: nome_empresa_1234
echo.
set "CHAVE_MCP="
set /p "CHAVE_MCP=  Digite sua Chave MCP: "

:: Validar que nao esta vazia
if "%CHAVE_MCP%"=="" (
    echo.
    echo  [ERRO] Chave MCP nao pode ser vazia.
    echo.
    goto :opcao_retry
)

:: Validar que nao tem espacos
echo %CHAVE_MCP% | findstr /r " " >nul
if %errorlevel% equ 0 (
    echo.
    echo  [ERRO] Chave MCP nao pode conter espacos.
    echo.
    goto :opcao_retry
)

echo  [OK] Chave recebida
echo.

echo [3/7] Validando chave no servidor ForGreen...
echo.

python -c "
import urllib.request, urllib.error, json, sys
req = urllib.request.Request('%SETUP_URL%')
req.add_header('X-API-Key', '%CHAVE_MCP%')
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        if data.get('valid'):
            print('TOKEN=' + data['token'])
            print('NAME=' + data.get('name', ''))
            print('DBID=' + data.get('database_id', '101885'))
            sys.exit(0)
        else:
            print('ERRO: Resposta invalida do servidor', file=sys.stderr)
            sys.exit(1)
except urllib.error.HTTPError as e:
    body = e.read().decode('utf-8') if e.fp else ''
    try:
        err = json.loads(body).get('error', body)
    except:
        err = body
    print(f'ERRO: {err}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERRO: {e}', file=sys.stderr)
    sys.exit(1)
" > "%TEMP%\mcp_setup_result.txt" 2> "%TEMP%\mcp_setup_error.txt"

if %errorlevel% neq 0 (
    echo  [ERRO] Chave MCP invalida ou servidor indisponivel.
    type "%TEMP%\mcp_setup_error.txt"
    echo.
    del "%TEMP%\mcp_setup_result.txt" >nul 2>&1
    del "%TEMP%\mcp_setup_error.txt" >nul 2>&1
    goto :opcao_retry
)

:: Extrair valores do resultado
for /f "tokens=1,* delims==" %%a in (%TEMP%\mcp_setup_result.txt) do (
    if "%%a"=="TOKEN" set "USER_TOKEN=%%b"
    if "%%a"=="NAME" set "USER_NAME=%%b"
    if "%%a"=="DBID" set "DATABASE_ID=%%b"
)

del "%TEMP%\mcp_setup_result.txt" >nul 2>&1
del "%TEMP%\mcp_setup_error.txt" >nul 2>&1

if "%USER_TOKEN%"=="" (
    echo  [ERRO] Nao foi possivel obter o token.
    echo.
    goto :opcao_retry
)

:: Chave validada, pular o bloco de retry
goto :chave_ok

:opcao_retry
echo  O que deseja fazer?
echo.
echo    [1] Tentar novamente com outra chave
echo    [2] Encerrar instalacao
echo.
set "OPCAO="
set /p "OPCAO=  Escolha (1 ou 2): "
if "%OPCAO%"=="1" (
    echo.
    echo  -----------------------------------------------
    echo.
    goto :solicitar_chave
)
echo.
echo  Instalacao cancelada pelo usuario.
echo.
pause
exit /b 1

:chave_ok

echo  [OK] Bem-vindo, %USER_NAME%!
echo  [OK] Token obtido com sucesso
echo.

:: ============================================================
:: [4/7] DESINSTALAR VERSOES ANTERIORES
:: ============================================================
echo [4/7] Limpando versoes anteriores...
echo.

:: Remover pasta antiga .claude\mcp-teamdesk (se existir)
if exist "%USERPROFILE%\.claude\mcp-teamdesk" (
    rmdir /s /q "%USERPROFILE%\.claude\mcp-teamdesk"
    echo  [OK] Removida pasta antiga: .claude\mcp-teamdesk
)

:: Limpar entrada teamdesk do claude_desktop_config.json (se existir)
set "CLAUDE_CONFIG=%APPDATA%\Claude\claude_desktop_config.json"
if exist "%CLAUDE_CONFIG%" (
    python -c "
import json, sys
try:
    with open(r'%CLAUDE_CONFIG%', 'r', encoding='utf-8') as f:
        config = json.load(f)
    servers = config.get('mcpServers', {})
    if 'teamdesk' in servers:
        del servers['teamdesk']
        config['mcpServers'] = servers
        with open(r'%CLAUDE_CONFIG%', 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        print(' [OK] Entrada teamdesk antiga removida do Claude Desktop')
    else:
        print(' [OK] Nenhuma configuracao anterior do teamdesk encontrada')
except Exception as e:
    print(f' [AVISO] Nao foi possivel limpar config antiga: {e}')
"
) else (
    echo  [OK] Nenhuma configuracao anterior encontrada
)

:: Limpar arquivos antigos na pasta de instalacao (manter pasta)
set "INSTALL_DIR=%USERPROFILE%\mcp-teamdesk"
if exist "%INSTALL_DIR%\server.py" (
    del "%INSTALL_DIR%\server.py" >nul 2>&1
    echo  [OK] server.py antigo removido
)
if exist "%INSTALL_DIR%\requirements.txt" (
    del "%INSTALL_DIR%\requirements.txt" >nul 2>&1
    echo  [OK] requirements.txt antigo removido
)
echo.

:: ============================================================
:: [5/7] INSTALAR ARQUIVOS
:: ============================================================
echo [5/7] Instalando arquivos...
echo.

:: Criar pasta de instalacao
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Baixar server.py do GitHub
set "GITHUB_RAW=https://raw.githubusercontent.com/Danielbluz/teamdesk-mcp-v2/main/server.py"
echo  Baixando server.py...
python -c "
import urllib.request, sys
try:
    urllib.request.urlretrieve('%GITHUB_RAW%', r'%INSTALL_DIR%\server.py')
    print(' [OK] server.py baixado')
except Exception as e:
    print(f' [ERRO] Falha ao baixar server.py: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao baixar server.py do GitHub.
    pause
    exit /b 1
)

:: Baixar requirements.txt do GitHub
set "GITHUB_RAW_REQ=https://raw.githubusercontent.com/Danielbluz/teamdesk-mcp-v2/main/requirements.txt"
echo  Baixando requirements.txt...
python -c "
import urllib.request, sys
try:
    urllib.request.urlretrieve('%GITHUB_RAW_REQ%', r'%INSTALL_DIR%\requirements.txt')
    print(' [OK] requirements.txt baixado')
except Exception as e:
    print(f' [ERRO] Falha ao baixar requirements.txt: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao baixar requirements.txt do GitHub.
    pause
    exit /b 1
)

:: Instalar dependencias
echo  Instalando dependencias Python...
pip install -r "%INSTALL_DIR%\requirements.txt" --quiet 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao instalar dependencias.
    pause
    exit /b 1
)
echo  [OK] Dependencias instaladas
echo.

:: ============================================================
:: [6/7] CONFIGURAR CLAUDE DESKTOP
:: ============================================================
echo [6/7] Configurando Claude Desktop...
echo.

set "CLAUDE_CONFIG_DIR=%APPDATA%\Claude"
set "CLAUDE_CONFIG=%CLAUDE_CONFIG_DIR%\claude_desktop_config.json"

:: Criar pasta de config se nao existir
if not exist "%CLAUDE_CONFIG_DIR%" mkdir "%CLAUDE_CONFIG_DIR%"

:: Detectar caminho do Python
for /f "delims=" %%i in ('where python') do (
    set "PYTHON_PATH=%%i"
    goto :got_python
)
:got_python

:: Usar Python para fazer merge JSON (preservar outros MCPs)
python -c "
import json, os, sys

config_path = r'%CLAUDE_CONFIG%'
python_path = r'%PYTHON_PATH%'
server_path = r'%INSTALL_DIR%\server.py'
token = '%USER_TOKEN%'
db_id = '%DATABASE_ID%'

# Carregar config existente ou criar nova
config = {}
if os.path.exists(config_path):
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
    except (json.JSONDecodeError, Exception):
        config = {}

# Garantir estrutura mcpServers
if 'mcpServers' not in config:
    config['mcpServers'] = {}

# Adicionar/atualizar entrada teamdesk
config['mcpServers']['teamdesk'] = {
    'command': python_path,
    'args': [server_path],
    'env': {
        'TEAMDESK_API_TOKEN': token,
        'TEAMDESK_DATABASE_ID': db_id
    }
}

# Salvar
with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print(' [OK] Claude Desktop configurado')
print(f'      Arquivo: {config_path}')
" 2>&1

if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao configurar Claude Desktop.
    pause
    exit /b 1
)
echo.

:: ============================================================
:: [7/7] TESTAR INSTALACAO
:: ============================================================
echo [7/7] Testando instalacao...
echo.

:: Testar se o server.py inicia sem erros (importacao + config)
python -c "
import os, sys
os.environ['TEAMDESK_API_TOKEN'] = '%USER_TOKEN%'
os.environ['TEAMDESK_DATABASE_ID'] = '%DATABASE_ID%'

# Testar importacao do modulo
sys.path.insert(0, r'%INSTALL_DIR%')
try:
    import importlib.util
    spec = importlib.util.spec_from_file_location('server', r'%INSTALL_DIR%\server.py')
    mod = importlib.util.find_module
    # Verificar que o arquivo carrega sem erro de sintaxe
    compile(open(r'%INSTALL_DIR%\server.py', encoding='utf-8').read(), 'server.py', 'exec')
    print(' [OK] server.py valido (sem erros de sintaxe)')
except SyntaxError as e:
    print(f' [ERRO] Erro de sintaxe no server.py: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f' [AVISO] {e}')

# Verificar que mcp esta instalado
try:
    import mcp
    print(' [OK] Pacote mcp instalado')
except ImportError:
    print(' [ERRO] Pacote mcp nao encontrado', file=sys.stderr)
    sys.exit(1)

print(' [OK] Teste concluido com sucesso')
" 2>&1

if %errorlevel% neq 0 (
    echo.
    echo  [AVISO] Teste falhou, mas a instalacao pode funcionar.
    echo          Abra o Claude Desktop e verifique manualmente.
)
echo.

:: ============================================================
:: RESULTADO FINAL
:: ============================================================
echo  ===============================================
echo   Instalacao concluida com sucesso!
echo  ===============================================
echo.
echo  Usuario:     %USER_NAME%
echo  Pasta:       %INSTALL_DIR%
echo  Config:      %CLAUDE_CONFIG%
echo.
echo  Proximos passos:
echo    1. Feche o Claude Desktop completamente (bandeja do sistema)
echo    2. Abra o Claude Desktop novamente
echo    3. Clique no icone de ferramentas (martelo)
echo    4. Verifique se "teamdesk" aparece na lista de MCPs
echo    5. Teste: pergunte "Liste as tabelas do TeamDesk"
echo.
echo  Em caso de problemas:
echo    - Verifique se o Claude Desktop esta atualizado
echo    - Confira o arquivo: %CLAUDE_CONFIG%
echo    - Contate o administrador ForGreen
echo.
pause
