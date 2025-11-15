@echo off
echo Packaging Nordens Paris addon...

set "OUTPUT_FILE=NordensParis.zip"

if exist "%OUTPUT_FILE%" (
    echo Removing existing zip file...
    del "%OUTPUT_FILE%"
)

echo Creating zip archive...
powershell -command "Compress-Archive -Path 'src\*.lua', 'src\*.toc' -DestinationPath '%OUTPUT_FILE%' -CompressionLevel Optimal"

if exist "%OUTPUT_FILE%" (
    echo.
    echo Packaging complete! Created %OUTPUT_FILE%
) else (
    echo.
    echo Error: Failed to create zip file
)
