@echo off
rem ZE Guns Of Bohemia - links this project into the Zomboid Workshop folder of ANOTHER PC.
rem Run it ON THE PC THAT PLAYS (right-click > Run as administrator: Windows needs admin
rem for a link to a network folder). Only Contents is linked; workshop.txt and preview.png
rem are copied. Run it again any time: it rebuilds the link.

set "SRC=\\DESKTOP-TRN6SLV\Users\ROG\Documents\zegunsofbohemia"
set "DST=C:\Users\monkm\Zomboid\Workshop\ZEGunsOfBohemia"

if not exist "%SRC%\Contents\mods" (
    echo Can't reach %SRC%
    echo Open it in Explorer once, log in with the other PC's Windows user and tick "Remember".
    pause
    exit /b 1
)

if not exist "%DST%" mkdir "%DST%"
rem an old link: plain rmdir removes just the link. An old COPY of the mod in this
rem Workshop folder: deleted (the project on DESKTOP-TRN6SLV is never touched).
if exist "%DST%\Contents" rmdir "%DST%\Contents" 2>nul
if exist "%DST%\Contents" rmdir /s /q "%DST%\Contents"

mklink /D "%DST%\Contents" "%SRC%\Contents"
if errorlevel 1 (
    echo.
    echo mklink failed: run this file as administrator.
    pause
    exit /b 1
)

copy /y "%SRC%\workshop.txt" "%DST%\" >nul
copy /y "%SRC%\preview.png" "%DST%\" >nul

echo.
echo Done: %DST%\Contents now points to %SRC%\Contents
echo In Zomboid, go back to the main menu and load the save to pick up changes.
pause
