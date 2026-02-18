@echo off
chcp 65001 >nul
title MCP TeamDesk - Instalador para Claude Desktop

:: ============================================================
:: WRAPPER: Garante que o terminal NUNCA fecha sem o usuario ver
:: Mesmo se o script crashar, o pause no final mantem aberto
:: ============================================================
set "LOG_DIR=%USERPROFILE%\mcp-teamdesk"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG_FILE=%LOG_DIR%\install.log"

:: Limpar log anterior
echo [%date% %time%] Inicio da instalacao > "%LOG_FILE%"

:: Chamar a logica principal como sub-rotina
call :main
set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
    echo  Pressione qualquer tecla para fechar...
) else (
    echo  A instalacao encontrou erros. Verifique o log em:
    echo  %LOG_FILE%
    echo.
    echo  Pressione qualquer tecla para fechar...
)
pause >nul
exit /b %EXIT_CODE%


:: ============================================================
:: SUB-ROTINA PRINCIPAL
:: ============================================================
:main
setlocal enabledelayedexpansion

echo.
echo  ===============================================
echo   MCP TeamDesk - Instalador para Claude Desktop
echo   ForGreen Energia Solar
echo  ===============================================
echo.
call :log "==============================================="
call :log "Instalador MCP TeamDesk iniciado"
call :log "==============================================="

:: ============================================================
:: [1/7] VERIFICAR REQUISITOS
:: ============================================================
echo [1/7] Verificando requisitos...
call :log "[1/7] Verificando requisitos"
echo.

:: Verificar Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Python nao encontrado.
    echo         Instale Python 3.10+ em https://python.org
    echo         Marque "Add Python to PATH" durante a instalacao.
    call :log "[ERRO] Python nao encontrado"
    echo.
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
    call :log "[ERRO] Python %PY_VER% - versao insuficiente"
    exit /b 1
)
if %PY_MAJOR% EQU 3 if %PY_MINOR% LSS 10 (
    echo  [ERRO] Python 3.10+ necessario. Versao encontrada: %PY_VER%
    call :log "[ERRO] Python %PY_VER% - versao insuficiente"
    exit /b 1
)
echo  [OK] Python %PY_VER%
call :log "[OK] Python %PY_VER%"

:: Verificar pip
pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] pip nao encontrado. Reinstale Python com pip.
    call :log "[ERRO] pip nao encontrado"
    exit /b 1
)
echo  [OK] pip disponivel
call :log "[OK] pip disponivel"

:: Verificar conexao internet
python -c "import urllib.request; urllib.request.urlopen('https://www.google.com', timeout=5); print(' [OK] Conexao com internet')" 2>nul
if %errorlevel% neq 0 (
    echo  [ERRO] Sem conexao com a internet. Verifique sua rede.
    call :log "[ERRO] Sem conexao com internet"
    exit /b 1
)
call :log "[OK] Conexao com internet"
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
if "!CHAVE_MCP!"=="" (
    echo.
    echo  [ERRO] Chave MCP nao pode ser vazia.
    call :log "[ERRO] Chave MCP vazia"
    echo.
    goto :opcao_retry
)

:: Validar formato (sem espacos, via Python para evitar bugs do findstr)
python -c "import sys; k='!CHAVE_MCP!'; sys.exit(1) if ' ' in k else sys.exit(0)" >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERRO] Chave MCP nao pode conter espacos.
    call :log "[ERRO] Chave MCP com espacos: !CHAVE_MCP!"
    echo.
    goto :opcao_retry
)

echo  [OK] Chave recebida
call :log "[OK] Chave recebida: !CHAVE_MCP!"
echo.

echo [3/7] Validando chave no servidor ForGreen...
call :log "[3/7] Validando chave no servidor..."
echo.

python -c "
import urllib.request, urllib.error, json, sys
try:
    req = urllib.request.Request('!SETUP_URL!')
    req.add_header('X-API-Key', '!CHAVE_MCP!')
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        if data.get('valid'):
            print('TOKEN=' + data['token'])
            print('NAME=' + data.get('name', ''))
            print('DBID=' + data.get('database_id', '101885'))
            sys.exit(0)
        else:
            print('Resposta invalida do servidor', file=sys.stderr)
            sys.exit(1)
except urllib.error.HTTPError as e:
    if e.code == 401:
        print('Chave MCP nao reconhecida pelo servidor.', file=sys.stderr)
    elif e.code == 403:
        print('Chave MCP desativada. Contate o administrador.', file=sys.stderr)
    else:
        print('Erro HTTP ' + str(e.code), file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print('Falha na conexao: ' + str(e), file=sys.stderr)
    sys.exit(1)
" > "%TEMP%\mcp_setup_result.txt" 2> "%TEMP%\mcp_setup_error.txt"

if %errorlevel% neq 0 (
    echo  [ERRO] Chave MCP invalida ou servidor indisponivel.
    call :log "[ERRO] Validacao falhou para chave: !CHAVE_MCP!"
    if exist "%TEMP%\mcp_setup_error.txt" (
        echo.
        for /f "usebackq delims=" %%e in ("%TEMP%\mcp_setup_error.txt") do (
            echo         %%e
            call :log "  Detalhe: %%e"
        )
    )
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

if "!USER_TOKEN!"=="" (
    echo  [ERRO] Nao foi possivel obter o token.
    call :log "[ERRO] Token vazio apos validacao"
    echo.
    goto :opcao_retry
)

:: Chave validada, pular o bloco de retry
goto :chave_ok

:opcao_retry
echo  -----------------------------------------------
echo  O que deseja fazer?
echo.
echo    [1] Tentar novamente com outra chave
echo    [2] Encerrar instalacao
echo.
set "OPCAO="
set /p "OPCAO=  Escolha (1 ou 2): "
call :log "Opcao escolhida: !OPCAO!"
if "!OPCAO!"=="1" (
    echo.
    echo  -----------------------------------------------
    echo.
    goto :solicitar_chave
)
echo.
echo  Instalacao cancelada pelo usuario.
call :log "Instalacao cancelada pelo usuario"
echo.
exit /b 1

:chave_ok

echo  [OK] Bem-vindo, !USER_NAME!!
echo  [OK] Token obtido com sucesso
call :log "[OK] Bem-vindo, !USER_NAME! - Token obtido"
echo.

:: ============================================================
:: [4/7] DESINSTALAR VERSOES ANTERIORES
:: ============================================================
echo [4/7] Limpando versoes anteriores...
call :log "[4/7] Limpando versoes anteriores"
echo.

:: Remover pasta antiga .claude\mcp-teamdesk (se existir)
if exist "%USERPROFILE%\.claude\mcp-teamdesk" (
    rmdir /s /q "%USERPROFILE%\.claude\mcp-teamdesk"
    echo  [OK] Removida pasta antiga: .claude\mcp-teamdesk
    call :log "[OK] Removida .claude\mcp-teamdesk"
)

:: Limpar entrada teamdesk do claude_desktop_config.json (se existir)
set "CLAUDE_CONFIG=%APPDATA%\Claude\claude_desktop_config.json"
if exist "!CLAUDE_CONFIG!" (
    python -c "import json, sys; f=open(r'!CLAUDE_CONFIG!','r',encoding='utf-8'); config=json.load(f); f.close(); servers=config.get('mcpServers',{}); removed='teamdesk' in servers; servers.pop('teamdesk',None); config['mcpServers']=servers; f=open(r'!CLAUDE_CONFIG!','w',encoding='utf-8'); json.dump(config,f,indent=2,ensure_ascii=False); f.close(); print(' [OK] Entrada teamdesk antiga removida' if removed else ' [OK] Nenhuma config anterior do teamdesk')" 2>&1
    call :log "[OK] Config Claude Desktop limpa"
) else (
    echo  [OK] Nenhuma configuracao anterior encontrada
    call :log "[OK] Sem config anterior"
)

:: Limpar arquivos antigos na pasta de instalacao (manter pasta)
set "INSTALL_DIR=%USERPROFILE%\mcp-teamdesk"
if exist "!INSTALL_DIR!\server.py" (
    del "!INSTALL_DIR!\server.py" >nul 2>&1
    echo  [OK] server.py antigo removido
)
if exist "!INSTALL_DIR!\requirements.txt" (
    del "!INSTALL_DIR!\requirements.txt" >nul 2>&1
    echo  [OK] requirements.txt antigo removido
)
echo.

:: ============================================================
:: [5/7] INSTALAR ARQUIVOS
:: ============================================================
echo [5/7] Instalando arquivos...
call :log "[5/7] Instalando arquivos"
echo.

:: Criar pasta de instalacao
if not exist "!INSTALL_DIR!" mkdir "!INSTALL_DIR!"

:: Baixar server.py do GitHub
set "GITHUB_RAW=https://raw.githubusercontent.com/Danielbluz/teamdesk-mcp-v2/main/server.py"
echo  Baixando server.py...
python -c "import urllib.request, sys; urllib.request.urlretrieve('!GITHUB_RAW!', r'!INSTALL_DIR!\server.py'); print(' [OK] server.py baixado')" 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao baixar server.py do GitHub.
    call :log "[ERRO] Falha download server.py"
    exit /b 1
)
call :log "[OK] server.py baixado"

:: Baixar requirements.txt do GitHub
set "GITHUB_RAW_REQ=https://raw.githubusercontent.com/Danielbluz/teamdesk-mcp-v2/main/requirements.txt"
echo  Baixando requirements.txt...
python -c "import urllib.request, sys; urllib.request.urlretrieve('!GITHUB_RAW_REQ!', r'!INSTALL_DIR!\requirements.txt'); print(' [OK] requirements.txt baixado')" 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao baixar requirements.txt do GitHub.
    call :log "[ERRO] Falha download requirements.txt"
    exit /b 1
)
call :log "[OK] requirements.txt baixado"

:: Instalar dependencias
echo  Instalando dependencias Python...
pip install -r "!INSTALL_DIR!\requirements.txt" --quiet 2>&1
if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao instalar dependencias.
    call :log "[ERRO] Falha pip install"
    exit /b 1
)
echo  [OK] Dependencias instaladas
call :log "[OK] Dependencias instaladas"
echo.

:: ============================================================
:: [6/7] CONFIGURAR CLAUDE DESKTOP
:: ============================================================
echo [6/7] Configurando Claude Desktop...
call :log "[6/7] Configurando Claude Desktop"
echo.

set "CLAUDE_CONFIG_DIR=%APPDATA%\Claude"
set "CLAUDE_CONFIG=!CLAUDE_CONFIG_DIR!\claude_desktop_config.json"

:: Criar pasta de config se nao existir
if not exist "!CLAUDE_CONFIG_DIR!" mkdir "!CLAUDE_CONFIG_DIR!"

:: Detectar caminho do Python
for /f "delims=" %%i in ('where python') do (
    set "PYTHON_PATH=%%i"
    goto :got_python
)
:got_python
call :log "Python path: !PYTHON_PATH!"

:: Usar Python para fazer merge JSON (preservar outros MCPs)
python -c "import json, os, sys; config_path=r'!CLAUDE_CONFIG!'; python_path=r'!PYTHON_PATH!'; server_path=r'!INSTALL_DIR!\server.py'; token='!USER_TOKEN!'; db_id='!DATABASE_ID!'; config={}; exec('try:\n with open(config_path,\"r\",encoding=\"utf-8\") as f: config=json.load(f)\nexcept: pass') if os.path.exists(config_path) else None; config.setdefault('mcpServers',{}); config['mcpServers']['teamdesk']={'command':python_path,'args':[server_path],'env':{'TEAMDESK_API_TOKEN':token,'TEAMDESK_DATABASE_ID':db_id}}; f=open(config_path,'w',encoding='utf-8'); json.dump(config,f,indent=2,ensure_ascii=False); f.close(); print(' [OK] Claude Desktop configurado'); print(f'      Arquivo: {config_path}')" 2>&1

if %errorlevel% neq 0 (
    echo  [ERRO] Falha ao configurar Claude Desktop.
    call :log "[ERRO] Falha config Claude Desktop"
    exit /b 1
)
call :log "[OK] Claude Desktop configurado"
echo.

:: ============================================================
:: [7/7] TESTAR INSTALACAO
:: ============================================================
echo [7/7] Testando instalacao...
call :log "[7/7] Testando instalacao"
echo.

:: Testar se o server.py inicia sem erros (importacao + config)
python -c "import os, sys; os.environ['TEAMDESK_API_TOKEN']='!USER_TOKEN!'; os.environ['TEAMDESK_DATABASE_ID']='!DATABASE_ID!'; compile(open(r'!INSTALL_DIR!\server.py',encoding='utf-8').read(),'server.py','exec'); print(' [OK] server.py valido (sem erros de sintaxe)'); import mcp; print(' [OK] Pacote mcp instalado'); print(' [OK] Teste concluido com sucesso')" 2>&1

if %errorlevel% neq 0 (
    echo.
    echo  [AVISO] Teste falhou, mas a instalacao pode funcionar.
    echo          Abra o Claude Desktop e verifique manualmente.
    call :log "[AVISO] Teste falhou"
)
call :log "[OK] Teste concluido"
echo.

:: ============================================================
:: RESULTADO FINAL
:: ============================================================
echo  ===============================================
echo   Instalacao concluida com sucesso!
echo  ===============================================
echo.
echo  Usuario:     !USER_NAME!
echo  Pasta:       !INSTALL_DIR!
echo  Config:      !CLAUDE_CONFIG!
echo  Log:         %LOG_FILE%
echo.
echo  Proximos passos:
echo    1. Feche o Claude Desktop completamente (bandeja do sistema)
echo    2. Abra o Claude Desktop novamente
echo    3. Clique no icone de ferramentas (martelo)
echo    4. Verifique se "teamdesk" aparece na lista de MCPs
echo    5. Teste: pergunte "Liste as tabelas do TeamDesk"
echo.
echo  Em caso de problemas:
echo    - Verifique o log: %LOG_FILE%
echo    - Verifique se o Claude Desktop esta atualizado
echo    - Confira o arquivo: !CLAUDE_CONFIG!
echo    - Contate o administrador ForGreen
echo.
call :log "Instalacao concluida com sucesso para !USER_NAME!"

endlocal
exit /b 0


:: ============================================================
:: FUNCAO DE LOG
:: ============================================================
:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
exit /b 0
