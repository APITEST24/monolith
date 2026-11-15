@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title Monolith

set "PY="
where python >nul 2>&1 && set "PY=python"
if not defined PY (
  where py >nul 2>&1 && set "PY=py -3"
)
if not defined PY (
  echo Установите Python 3.11 или новее с https://www.python.org/downloads/windows/
  echo На первом экране включите Add python.exe to PATH.
  pause
  exit /b 1
)

if not exist "server\.venv\Scripts\python.exe" (
  %PY% -m venv server\.venv
  if errorlevel 1 goto :fail
)

set "VENV=server\.venv\Scripts\python.exe"
"%VENV%" -m pip install --upgrade pip
if errorlevel 1 goto :fail
"%VENV%" -m pip install -r server\requirements.txt
if errorlevel 1 goto :fail

if not exist "server\.env" (
  "%VENV%" -c "import secrets; from pathlib import Path; p=Path(r'server/.env'); ios=secrets.token_hex(32); bot=secrets.token_hex(32); p.write_text('DISCIPLINA_IOS_API_KEY='+ios+'\nDISCIPLINA_BOT_API_KEY='+bot+'\nDISCIPLINA_DB_PATH=./data/disciplina.db\nDISCIPLINA_HOST=127.0.0.1\nDISCIPLINA_PORT=8741\n', encoding='utf-8'); print(''); print('Ключ телефона, его нужно вставить в Monolith на айфоне:'); print(ios); print(''); print('Ключ бота:'); print(bot); print('')"
  if errorlevel 1 goto :fail
) else (
  echo Файл server\.env уже есть. Ключ телефона лежит в нём, строка DISCIPLINA_IOS_API_KEY.
)

if not exist "web\dist\index.html" (
  echo Не найден web\dist. Скачайте архив monolith-windows из GitHub Actions или соберите сайт командой npm run build в папке web.
  pause
  exit /b 1
)

cd server
echo.
echo Monolith открыт на http://127.0.0.1:8741/
echo Окно не закрывайте. Остановка: Ctrl+C
echo.
".venv\Scripts\python.exe" -m app
echo.
echo Сервер остановлен.
pause
exit /b 0

:fail
echo.
echo Не удалось запустить Monolith.
pause
exit /b 1
