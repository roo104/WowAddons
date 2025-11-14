@echo off
echo Deploying Nordens Paris to WoW AddOns folder...

set "ADDON_PATH=C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\NordensParis"

if not exist "%ADDON_PATH%" (
    echo Creating addon directory...
    mkdir "%ADDON_PATH%"
)

echo Copying files...
copy /Y "src\*.toc" "%ADDON_PATH%\"
copy /Y "src\*.lua" "%ADDON_PATH%\"

echo.
echo Deployment complete!