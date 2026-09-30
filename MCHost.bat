@echo off

pushd "%~dp0"

if /i "%~1"=="-h" call :help & goto :quit
if /i "%~1"=="-b" call :boot & goto :quit
if /i "%~1"=="-s" call :stop & goto :quit

call :workdir || goto :quit
call :load_vars
if /i "%~1"=="-d" call :dash & goto :quit
if /i "%~1"=="-f" start "" explorer.exe "%workdir%" & goto :quit

call :stop
if /i "%~1"=="-w" call :wipe & goto :quit
if /i "%~1"=="-u" call :update

call :install
call :start

:quit
popd
exit /b 0




:: Subroutines

:help
echo.
echo MCHost is a batch script to quickly deploy Minecraft Servers.
echo It uses "VoxelDash-One CLI (https://voxeldash.dev/)".
echo.
echo Remote administration: "Zerotier (https://www.zerotier.com/one/)" recommended.
echo.
echo Launch Parameters:
echo.
echo    -h  Show all launch parameters.
echo    -d  Open all web dashboards.
echo    -f  Open MCHost folder.
echo    -b  Launch after boot.
echo    -s  Stop all tasks.
echo    -u  Force update.
echo    -w  Wipe Wipe all MCHost files.
echo.
goto :eof

:boot
set "startup=%appdata%\Microsoft\Windows\Start Menu\Programs\Startup\MCHost-Shortcut.bat"

if exist "%startup%" (
	del /f /q "%startup%" >nul 2>&1
	echo.
	echo Auto-start disabled.
) else (
	(
		echo @echo off
		echo start "" "%~f0" ^>nul 2^>^&1
		echo exit /b 0
	)>"%startup%"
	echo.
	echo Auto-start enabled.
)
goto :eof

:workdir
set "workdir=%systemdrive%\MCHost"
echo %~n0 | findstr /i "portable" >nul 2>&1 && set "workdir=%~dp0MCHost"

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
taskkill /t /f /im "voxeldash-one.exe" >nul 2>&1
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

:update
echo.
echo Starting update process...

rd /s /q "ui\" >nul 2>&1
del /f /q "voxeldash-one.exe" >nul 2>&1
goto :eof

:install
if not exist "voxeldash-one.exe" (
	echo.
	echo Downloading VoxelDash...
	call :gh_last "gnmyt" "VoxelDash" "voxeldash-one-*-windows-x64.zip" "voxeldash.zip"
	call :ps_decomp "voxeldash.zip" "."
	del /f /q "voxeldash.zip" >nul 2>&1
	
	for /d %%a in ("voxeldash-one-*-windows-x64") do (
		xcopy "%%a" "." /s /e /q /y >nul 2>&1
		rd /s /q "%%a" >nul 2>&1
	)
)

if not exist "MCHost.ini" (
	(
		echo ; MCHost configuration
		echo PORT=7867
		echo VOXELDASH_HOME=data
		echo VOXELDASH_UI=ui/dist
		echo MASTER_HOST=127.0.0.1
	)> "MCHost.ini"
)
goto :eof

:load_vars
if exist "MCHost.ini" (
	call :in_var PORT "MCHost.ini"
	call :in_var VOXELDASH_HOME "MCHost.ini"
	call :in_var VOXELDASH_UI "MCHost.ini"
	call :in_var MASTER_HOST "MCHost.ini"
)
goto :eof

:dash
if exist "MCHost.ini" (
	start "" "https://playit.gg/login"
	start "" "http://127.0.0.1:%PORT%/login"
) else (
	echo.
	echo MCHost.ini not found.
)
goto :eof

:start
if exist "voxeldash-one.exe" (
	start "VoxelDash" /min "voxeldash-one.exe"
)
goto :eof




:: Tools

:in_var key path
for /f "tokens=2 delims=;=" %%a in ('findstr /b /i /c:"%~1=" "%~2" 2^>nul') do set "%~1=%%a"
goto :eof

:gh_last user repo pattern output
md "%~dp4" >nul 2>&1
powershell -noprofile -command "$progresspreference = 'silentlycontinue'; iwr ((irm 'https://api.github.com/repos/%~1/%~2/releases/latest').assets | where-object {$_.browser_download_url -like '*%~3*'} | select-object -first 1).browser_download_url -outfile '%~4' -usebasicparsing"
goto :eof

:ps_decomp file output
setlocal enabledelayedexpansion
if "%~2"=="" (set "output=%~dpn1") else (set "output=%~2")
md "!output!" >nul 2>&1
powershell -noprofile -command "$progresspreference = 'silentlycontinue'; expand-archive -path '%~1' -destinationpath '%output%' -force" >nul 2>&1
endlocal
goto :eof

