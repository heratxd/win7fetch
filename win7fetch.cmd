@echo off
setlocal enabledelayedexpansion

:: Parse Command Line Arguments
if "%~1"=="--help" goto :show_help
if "%~1"=="-h" goto :show_help
if "%~1"=="-?" goto :show_help
if "%~1"=="--install" goto :install_cmd
if "%~1"=="-i" goto :install_cmd
if "%~1"=="--uninstall" goto :uninstall_cmd
if "%~1"=="-u" goto :uninstall_cmd

:: Set Fallbacks
set "OS_NAME=Windows"
set "OS_ARCH=x86"
set "KERNEL=Unknown"
set "HOST=Generic PC"
set "CPU=Unknown"
set "SHELL=cmd.exe"
set "MEM_TOTAL=Unknown"
set "MEM_USED=Unknown"
set "GPU=Unknown"
set "RESOLUTION=Unknown"
set "UPTIME=Unknown"

:: 1. Gather Static Info via Registry (Extremely Fast, Near-Zero RAM)
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "OS_NAME=%%B"
set "OS_NAME=%OS_NAME:Microsoft Windows=Windows%"

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set "OS_ARCH=x64") else (
    if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (set "OS_ARCH=x64") else (set "OS_ARCH=x86")
)

set "win_ver="
set "win_build="
set "win_sp="
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentVersion 2^>nul') do set "win_ver=%%B"
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul') do set "win_build=%%B"
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CSDVersion 2^>nul') do set "win_sp= %%B"
set "KERNEL=%win_ver%.%win_build%%win_sp%"

set "host_man="
set "host_model="
for /f "tokens=2*" %%A in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v SystemManufacturer 2^>nul') do set "host_man=%%B"
for /f "tokens=2*" %%A in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\BIOS" /v SystemProductName 2^>nul') do set "host_model=%%B"
:: Remove trailing spaces and clean up host string
set "HOST=%host_man% %host_model%"
for /l %%p in (1,1,4) do (
    if "!HOST:~-1!"==" " set "HOST=!HOST:~0,-1!"
)
if "%HOST%"==" " set "HOST=Generic PC"

for /f "tokens=2*" %%A in ('reg query "HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0" /v ProcessorNameString 2^>nul') do set "CPU=%%B"
:: Clean up CPU String
set "CPU=%CPU:Intel(R) Core(TM)=Intel Core%"
set "CPU=%CPU:AMD =AMD %"
set "CPU=%CPU: CPU @ = @ %"
set "CPU=%CPU: @ = @%"
:clean_cpu_spaces
set "temp_cpu=%CPU:  = %"
if not "%temp_cpu%"=="%CPU%" (
    set "CPU=%temp_cpu%"
    goto :clean_cpu_spaces
)
:: Trim leading space if any
if "!CPU:~0,1!"==" " set "CPU=!CPU:~1!"

for %%F in ("%COMSPEC%") do set "SHELL=%%~nxF"

:: 2. Gather Dynamic Info via Micro VBScript Helper (Fast and Tiny)
set "vbs_file=%temp%\win7fetch_helper.vbs"
(
echo On Error Resume Next
echo Set objWMIService = GetObject^("winmgmts:\\.\root\cimv2"^)
echo Set colOS = objWMIService.ExecQuery^("Select TotalVisibleMemorySize, FreePhysicalMemory, LastBootUpTime from Win32_OperatingSystem"^)
echo For Each objOS in colOS
echo     totalMem = Round^(objOS.TotalVisibleMemorySize / 1024^)
echo     freeMem = Round^(objOS.FreePhysicalMemory / 1024^)
echo     usedMem = totalMem - freeMem
echo     lastBoot = objOS.LastBootUpTime
echo Next
echo Set colVideo = objWMIService.ExecQuery^("Select Name, CurrentHorizontalResolution, CurrentVerticalResolution from Win32_VideoController"^)
echo gpuName = "Unknown GPU"
echo resX = ""
echo resY = ""
echo For Each objVideo in colVideo
echo     If Not IsNull^(objVideo.CurrentHorizontalResolution^) Then
echo         gpuName = objVideo.Name
echo         resX = objVideo.CurrentHorizontalResolution
echo         resY = objVideo.CurrentVerticalResolution
echo         Exit For
echo     End If
echo Next
echo If resX = "" Then
echo     For Each objVideo in colVideo
echo         gpuName = objVideo.Name
echo         Exit For
echo     Next
echo End If
echo uptimeStr = "Unknown"
echo If Not IsNull^(lastBoot^) And Len^(lastBoot^) ^>= 14 Then
echo     bootYear = Left^(lastBoot, 4^)
echo     bootMonth = Mid^(lastBoot, 5, 2^)
echo     bootDay = Mid^(lastBoot, 7, 2^)
echo     bootHour = Mid^(lastBoot, 9, 2^)
echo     bootMin = Mid^(lastBoot, 11, 2^)
echo     bootSec = Mid^(lastBoot, 13, 2^)
echo     dtmBoot = DateSerial^(CInt^(bootYear^), CInt^(bootMonth^), CInt^(bootDay^)^) + TimeSerial^(CInt^(bootHour^), CInt^(bootMin^), CInt^(bootSec^)^)
echo     diffMin = DateDiff^("n", dtmBoot, Now^)
echo     uptimeHours = diffMin \ 60
echo     uptimeMins = diffMin Mod 60
echo     uptimeDays = uptimeHours \ 24
echo     uptimeHours = uptimeHours Mod 24
echo     uptimeStr = ""
echo     If uptimeDays ^> 0 Then uptimeStr = uptimeStr ^& uptimeDays ^& "d "
echo     If uptimeHours ^> 0 Then uptimeStr = uptimeStr ^& uptimeHours ^& "h "
echo     uptimeStr = uptimeStr ^& uptimeMins ^& "m"
echo End If
echo WScript.Echo "MEM_TOTAL=" ^& totalMem
echo WScript.Echo "MEM_USED=" ^& usedMem
echo WScript.Echo "GPU=" ^& gpuName
echo If resX ^<^> "" Then
echo     WScript.Echo "RESOLUTION=" ^& resX ^& "x" ^& resY
echo Else
echo     WScript.Echo "RESOLUTION=Unknown"
echo End If
echo WScript.Echo "UPTIME=" ^& uptimeStr
) > "%vbs_file%"

if exist "%vbs_file%" (
    for /f "usebackq delims=" %%A in (`%SystemRoot%\System32\cscript.exe //nologo "%vbs_file%"`) do (
        set "%%A"
    )
    del "%vbs_file%" 2>nul
)

:: 3. Setup Colors and ANSI Support
set "ENABLE_COLOR=0"
if "%WT_SESSION%" neq "" set "ENABLE_COLOR=1"
if "%TERM%" neq "" set "ENABLE_COLOR=1"

:: Check Windows Version (Major version >= 10 usually supports ANSI natively)
for /f "tokens=1-3 delims=." %%a in ("%win_ver%") do (
    if %%a gtr 9 set "ENABLE_COLOR=1"
)

:: Process command line overrides
if "%~1"=="--color" set "ENABLE_COLOR=1"
if "%~1"=="-c" set "ENABLE_COLOR=1"
if "%~1"=="--no-color" set "ENABLE_COLOR=0"
if "%~1"=="-n" set "ENABLE_COLOR=0"

:: Initialize ANSI color variables if enabled
if "%ENABLE_COLOR%"=="1" (
    for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
    set "RED=!ESC![91m"
    set "GRN=!ESC![92m"
    set "BLU=!ESC![94m"
    set "YLW=!ESC![93m"
    set "RST=!ESC![0m"
    set "CLR_TITLE=!ESC![1;36m"
    set "CLR_DASH=!ESC![90m"
    set "CLR_LABEL=!ESC![36m"
) else (
    set "RED="
    set "GRN="
    set "BLU="
    set "YLW="
    set "RST="
    set "CLR_TITLE="
    set "CLR_DASH="
    set "CLR_LABEL="
)

:: 4. Construct Left/Right Content
set "USER_HOST=%USERNAME%@%COMPUTERNAME%"
set "DASH="
set "temp_str=%USER_HOST%"
:dash_loop
if not "%temp_str%"=="" (
    set "DASH=%DASH%-"
    set "temp_str=%temp_str:~1%"
    goto :dash_loop
)

:: Detect Windows Version Category for Logo selection
set "WIN_LOGO_TYPE=WIN7"
for /f "tokens=1-3 delims=." %%a in ("%win_ver%") do (
    if "%%a"=="5" (
        set "WIN_LOGO_TYPE=WIN7"
    ) else if "%%a"=="6" (
        if "%%b"=="2" set "WIN_LOGO_TYPE=WIN10"
        if "%%b"=="3" set "WIN_LOGO_TYPE=WIN10"
    ) else if %%a gtr 9 (
        if !win_build! gtr 21999 (
            set "WIN_LOGO_TYPE=WIN11"
        ) else (
            set "WIN_LOGO_TYPE=WIN10"
        )
    )
)

:: Set Logo Lines with exact width 41 depending on OS version
if "%WIN_LOGO_TYPE%"=="WIN11" goto :logo_win11
if "%WIN_LOGO_TYPE%"=="WIN10" goto :logo_win10
goto :logo_win7

:logo_win11
set "L1=%BLU%################  ################       %RST%"
set "L2=%BLU%################  ################       %RST%"
set "L3=%BLU%################  ################       %RST%"
set "L4=%BLU%################  ################       %RST%"
set "L5=%BLU%################  ################       %RST%"
set "L6=%BLU%################  ################       %RST%"
set "L7=%BLU%################  ################       %RST%"
set "L8=                                         "
set "L9=%BLU%################  ################       %RST%"
set "L10=%BLU%################  ################       %RST%"
set "L11=%BLU%################  ################       %RST%"
set "L12=%BLU%################  ################       %RST%"
set "L13=%BLU%################  ################       %RST%"
set "L14=%BLU%################  ################       %RST%"
set "L15=%BLU%################  ################       %RST%"
set "L16="
set "L17="
set "L18="
set "L19="
goto :logo_done

:logo_win10
set "L1=%BLU%                                ..,      %RST%"
set "L2=%BLU%                    ....,,:;+ccllll      %RST%"
set "L3=%BLU%      ...,,+:;  cllllllllllllllllll      %RST%"
set "L4=%BLU%,cclllllllllll  lllllllllllllllllll      %RST%"
set "L5=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L6=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L7=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L8=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L9=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L10=                                         "
set "L11=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L12=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L13=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L14=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L15=%BLU%llllllllllllll  lllllllllllllllllll      %RST%"
set "L16=%BLU%`'ccllllllllll  lllllllllllllllllll      %RST%"
set "L17=%BLU%       `' \*::  :ccllllllllllllllll      %RST%"
set "L18=%BLU%                       ````''*::cll      %RST%"
set "L19=%BLU%                                 ``      %RST%"
goto :logo_done

:logo_win7
set "L1=%RED%        ,.=:^^!^^!t3Z3z.,                    %RST%"
set "L2=%RED%       :tt:::tt333EE3                   %RST%"
set "L3=%RED%       Et:::ztt33EEEL%GRN% @Ee.,      ..,     %RST%"
set "L4=%RED%      ;tt:::tt333EE7%GRN% ;EEEEEEttttt33# %RST%"
set "L5=%RED%     :Et:::zt333EEQ.%GRN% $EEEEEttttt33QL %RST%"
set "L6=%RED%     it::::tt333EEF%GRN% @EEEEEEttttt33F %RST%"
set "L7=%RED%    ;3=*^```"*4EEV%GRN% :EEEEEEttttt33@.   %RST%"
set "L8=%BLU%    ,.=::::^^!t=., %RED%`%GRN% @EEEEEEtttz33QF  %RST%"
set "L9=%BLU%   ;::::::::zt33)%GRN%   "4EEEtttji3P*     %RST%"
set "L10=%BLU%  :t::::::::tt33.%YLW%:Z3z..%GRN%  ``%YLW% ,..g.       %RST%"
set "L11=%BLU%  i::::::::zt33F%YLW% AEEEtttt::::ztF   %RST%"
set "L12=%BLU% ;:::::::::t33V%YLW% ;EEEttttt::::t3     %RST%"
set "L13=%BLU% E::::::::zt33L%YLW% @EEEtttt::::z3F    %RST%"
set "L14=%BLU%{3=*^```"*4E3)%YLW% ;EEEtttt:::::tZ`         %RST%"
set "L15=%BLU%             `%YLW% :EEEEtttt::::z7         %RST%"
set "L16=%YLW%                 "VEzjt:;;z>*`           %RST%"
set "L17="
set "L18="
set "L19="
goto :logo_done

:logo_done

:: Info Lines
set "I1=%CLR_TITLE%%USER_HOST%%RST%"
set "I2=%CLR_DASH%%DASH%%RST%"
set "I3=%CLR_LABEL%OS:%RST% %OS_NAME% %OS_ARCH%"
set "I4=%CLR_LABEL%Host:%RST% %HOST%"
set "I5=%CLR_LABEL%Kernel:%RST% %KERNEL%"
set "I6=%CLR_LABEL%Uptime:%RST% %UPTIME%"
set "I7=%CLR_LABEL%Shell:%RST% %SHELL%"
set "I8=%CLR_LABEL%Resolution:%RST% %RESOLUTION%"
set "I9=%CLR_LABEL%CPU:%RST% %CPU%"
set "I10=%CLR_LABEL%GPU:%RST% %GPU%"
set "I11=%CLR_LABEL%Memory:%RST% %MEM_USED%MB / %MEM_TOTAL%MB"
set "I12="
set "I13="
set "I14="
set "I15="
set "I16="
set "I17="
set "I18="
set "I19="

:: 5. Output beautiful columns
echo %L1%  %I1%
echo %L2%  %I2%
echo %L3%  %I3%
echo %L4%  %I4%
echo %L5%  %I5%
echo %L6%  %I6%
echo %L7%  %I7%
echo %L8%  %I8%
echo %L9%  %I9%
echo %L10% %I10%
echo %L11% %I11%
echo %L12% %I12%
echo %L13% %I13%
echo %L14% %I14%
echo %L15% %I15%
echo %L16% %I16%
echo %L17% %I17%
echo %L18% %I18%
echo %L19% %I19%
goto :eof

:install_cmd
echo Installing win7fetch...
set "install_dir=%USERPROFILE%\.win7fetch"
if not exist "%install_dir%" mkdir "%install_dir%"

copy /Y "%~f0" "%install_dir%\win7fetch.cmd" >nul

for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%B"

echo "%USER_PATH%" | findstr /I /C:".win7fetch" >nul
if errorlevel 1 (
    if "%USER_PATH%"=="" (
        reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "%%USERPROFILE%%\.win7fetch" /f >nul
    ) else (
        reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "%USER_PATH%;%%USERPROFILE%%\.win7fetch" /f >nul
    )
    echo.
    echo win7fetch has been successfully installed and added to your user PATH!
    echo Please restart your Command Prompt or run 'refreshenv' to use the 'win7fetch' command.
) else (
    echo win7fetch is already installed and in your PATH!
)
goto :eof

:uninstall_cmd
echo Uninstalling win7fetch...
set "install_dir=%USERPROFILE%\.win7fetch"
if exist "%install_dir%" rmdir /S /Q "%install_dir%"

for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%B"
if not "%USER_PATH%"=="" (
    set "NEW_PATH=%USER_PATH%"
    set "NEW_PATH=!NEW_PATH:;%%USERPROFILE%%\.win7fetch=!"
    set "NEW_PATH=!NEW_PATH:%%USERPROFILE%%\.win7fetch;=!"
    set "NEW_PATH=!NEW_PATH:%%USERPROFILE%%\.win7fetch=!"
    set "NEW_PATH=!NEW_PATH:;%USERPROFILE%\.win7fetch=!"
    set "NEW_PATH=!NEW_PATH:%USERPROFILE%\.win7fetch;=!"
    set "NEW_PATH=!NEW_PATH:%USERPROFILE%\.win7fetch=!"
    
    if "!NEW_PATH!"=="" (
        reg delete "HKCU\Environment" /v Path /f >nul 2>&1
    ) else (
        reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "!NEW_PATH!" /f >nul
    )
)
echo win7fetch has been successfully uninstalled.
goto :eof

:show_help
echo win7fetch - A beautiful, ultra-lightweight neofetch clone for Windows
echo.
echo Usage: win7fetch [options]
echo.
echo Options:
echo   -h, --help        Show this help message
echo   -c, --color       Force enable colors (ANSI escape codes)
echo   -n, --no-color    Force disable colors
echo   -i, --install     Install win7fetch to user PATH
echo   -u, --uninstall   Uninstall win7fetch
echo.
echo Extremely optimized for low memory environments (e.g. 512MB RAM).
goto :eof
