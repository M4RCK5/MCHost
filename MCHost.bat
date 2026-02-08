@echo off

set "old_workdir=%cd%"
cd /d "%~dp0"

if /i "%~1"=="-h" call :help & goto :quit
if /i "%~1"=="-d" call :dash & goto :quit
if /i "%~1"=="-s" call :stop & goto :quit

call :workdir || goto :quit
if /i "%~1"=="-f" start "" "%workdir%" & goto :quit

call :stop
if /i "%~1"=="-w" call :wipe & goto :quit
if /i "%~1"=="-r" call :reset & goto :quit

if /i "%~1"=="-u" call :update
call :install

if /i "%~1"=="-p" call :playit & goto :quit
if /i "%~1"=="-c" call :crafty & goto :quit
call :playit
call :crafty

:quit
cd /d "%old_workdir%"
exit /b 0




:: Subroutines

:help
echo.
echo MCHost is a batch script to quickly deploy Minecraft Servers.
echo It uses "playit.gg (cli) + Java (isolated) + Crafty Controller".
echo.
echo Custom workdir: unquoted path in "MCHost.txt" next to the script.
echo Remote administration: "Zerotier" recommended.
echo.
echo Launch Parameters:
echo.
echo    -h  Show all launch parameters.
echo    -d  Open all web dashboards.
echo    -f  Open MCHost folder.
echo    -s  Stop all tasks.
echo    -r  Reset playit.gg proxy settings.
echo    -u  Update tools and start all tasks.
echo    -w  Wipe all MCHost files.
echo    -p  Start only playit.gg.
echo    -c  Start only Crafty Controller.
echo.
goto :eof

:dash
start "" "https://playit.gg/login"
start "" "https://127.0.0.1:8443/"
goto :eof

:workdir
set "custom_workdir="
set "workdir=%systemdrive%\MCHost"
if exist "MCHost.txt" set /p custom_workdir=<MCHost.txt
if exist "%custom_workdir%" if exist "%custom_workdir%\" set "workdir=%custom_workdir%\MCHost"

md "%workdir%" >nul 2>&1
cd /d "%workdir%" >nul 2>&1
if not "%cd%"=="%workdir%" (
	echo.
	echo Error: Please verify workdir.
	timeout /t 5
	exit /b 1
)
goto :eof

:stop
taskkill /t /f /im "crafty.exe" /im "playit.exe" >nul 2>&1
timeout /t 2 >nul 2>&1
goto :eof

:wipe
ver>nul
echo.
choice /c yn /n /t 5 /d n /m "You have 5s. to confirm MCHost uninstall (y/n)... "
if %errorlevel% equ 2 (
	echo.
	echo Uninstall skipped.
) else (
	if exist "%workdir%" rd "%workdir%" /s /q >nul 2>&1
	echo.
	echo MCHost uninstalled.
)
timeout /t 5
goto :eof

:reset
echo.
echo playit.gg agent reset.
if exist "playit.exe" start "playit.gg" /b "playit.exe" --secret_path ".\playit.toml" reset >nul 2>&1
timeout /t 5
goto :eof

:update
echo.
echo Starting update process...
for /f "delims=" %%a in ('dir /b') do (
	if exist "%%a\" (
		if not "%%a"=="servers" rd /s /q "%%a" >nul 2>&1
	) else (
		if not "%%a"=="playit.toml" del /f /q "%%a" >nul 2>&1
	)
)
goto :eof

:install
if not exist "java\jre\bin\java.exe" (
	echo.
	echo Downloading JRE...
	call :dl_java "jre_x64_windows" "java\java.zip"
	call :ps_decomp "java\java.zip" "java"
	del /f /q "java\java.zip" >nul 2>&1
	for /d %%a in ("java\*") do ren "%%a" "jre" >nul 2>&1
)

if not exist "playit.exe" (
	echo.
	echo Downloading playit.gg agent...
	call :dl "https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-windows-x86_64-signed.exe" "playit.exe"
)

if not exist "crafty.exe" (
	echo.
	echo Downloading Crafty Controller...
	call :gl_last "crafty-controller" "crafty-4" "Windows Package" "crafty.zip"
	call :ps_decomp "crafty.zip" "."
	del /f /q "crafty.zip" >nul 2>&1
)

md "app\config" >nul 2>&1
(
	echo {
	echo     "username": "admin",
	echo     "password": "12345678"
	echo }
)>"app\config\default.json"
goto :eof

:playit
if exist "playit.exe" (
	start "playit.gg" /min "playit.exe" --secret_path ".\playit.toml" start
)
goto :eof

:crafty
if exist "crafty.exe" (
	if exist "java\jre\bin\java.exe" set "Path=%workdir%\java\jre\bin;%Path%"
	start "Crafty Controller" /min "crafty.exe"
)
goto :eof




:: Tools

:dl url output
md "%~dp2" >nul 2>&1
powershell -noprofile -command "$progresspreference = 'silentlycontinue'; invoke-webrequest -uri '%~1' -outfile '%~2'" >nul 2>&1
goto :eof

:dl_java pattern output
setlocal enabledelayedexpansion
set "api_url=https://api.adoptium.net/v3"
md "%~dp2" >nul 2>&1
for /f "delims=" %%a in ('powershell -noprofile -command "(invoke-restmethod '%api_url%/info/available_releases').most_recent_lts"') do set "latest=%%a"
for /f "delims=" %%a in ('powershell -noprofile -command "(invoke-restmethod '%api_url%/assets/latest/%latest%/hotspot').binary.package.link" ^| findstr "%~1"') do set "package_link=%%a"
powershell -noprofile -command "$progresspreference = 'silentlycontinue'; invoke-webrequest -uri '%package_link%' -outfile '%~2'" >nul 2>&1
endlocal
goto :eof

:gl_last user repo pattern output
powershell -noprofile -command "$progresspreference = 'silentlycontinue'; iwr ((irm 'https://gitlab.com/api/v4/projects/%~1%%2F%~2/releases?per_page=1')[0].assets.links | where name -eq '%~3' | select -expand url) -outfile '%~4'"
goto :eof

:ps_decomp file output
setlocal enabledelayedexpansion
if "%~2"=="" (set "output=%~dpn1") else (set "output=%~2")
md "!output!" >nul 2>&1
powershell -noprofile -command "$progresspreference = 'silentlycontinue'; expand-archive -path '%~1' -destinationpath '%output%' -force"
endlocal
goto :eof

