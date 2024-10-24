@echo off
setlocal enabledelayedexpansion

:loop
REM Prompt user for the path to the folder containing the audio files
echo.
echo Please enter the full path to the folder containing the audio files (e.g. E:/Data):
set /p "source_folder="

REM Replace forward slashes with backslashes
set "source_folder=%source_folder:/=\%"

REM Check if the folder exists
if not exist "%source_folder%" (
    echo.
    echo The specified folder does not exist. Please check the path and try again.
    goto loop
)

REM Ask the user if they want to copy files to the same directory or a new one
echo Do you want to organise your files within the same directory (Y/N)?
set /p "copy_to_same_dir="

if /i "%copy_to_same_dir%"=="Y" (
    set "dest_folder=%source_folder%"
) else (
    :new_dest_loop
    echo.
    echo Please enter the full path to a new destination folder:
    set /p "dest_folder="

    REM Replace forward slashes with backslashes
    set "dest_folder=!dest_folder:/=\!"

    REM Create the destination folder if it doesn't exist
    if not exist "!dest_folder!" (
        echo.
        echo The destination folder does not exist. Creating it now...
        mkdir "!dest_folder!"
        if not exist "!dest_folder!" (
            echo Failed to create the destination folder. Please check the path and permissions.
            goto new_dest_loop
        )
    )
)

REM Check if the directory is read-only
attrib "%dest_folder%" | find /i "R" >nul
if %errorlevel% equ 1 (
    echo.
    echo The specified destination folder is read-only. Please choose a different folder.
    goto new_dest_loop
)

REM Use ROBOCOPY to calculate the total size of the source folder (without copying)
echo Checking destination folder has enough space...
set total_source_size_bytes=0
for /f "tokens=3" %%a in ('dir /s "%source_folder%" ^| findstr /i "File(s)"') do set total_source_size_bytes=%%a
REM Remove commas from the free space value if present
set total_source_size_bytes=%total_source_size_bytes:,=%

REM If the length of total_source_size_bytes is greater than 3, remove the last 3 digits to approximate KB (32 bit INT can't calc correctly)
if "%total_source_size_bytes:~3%" neq "" (
    set "total_source_size_kb=%total_source_size_bytes:~0,-3%"
) else (
    set "total_source_size_kb=0"
)

REM If copying to the same folder, check for at least 0.5 GB (512 MB) of free space
if "!source_folder!"=="!dest_folder!" (
    set /a required_space_kb=512000
) else (
    REM If copying to a new folder, check if there is enough space for source folder + 0.5 GB
    set /a required_space_kb=total_source_size_kb+512000
)

REM Run dir and extract the available free space
for /f "tokens=3" %%a in ('dir "!dest_folder!" ^| findstr /i "bytes free"') do set free_space=%%a
echo free space %free_space% bytes
REM Remove commas from the free space value if present
set free_space=%free_space:,=%

REM If the length of free_space is greater than 3, remove the last 3 digits to approximate KB (32 bit INT can't calc correctly)
if "%free_space:~3%" neq "" (
    set "free_space_kb=%free_space:~0,-3%"
) else (
    set "free_space_kb=0"
)

REM Check if free space is greater than or equal to the required space
if %free_space_kb% lss %required_space_kb% (
    echo.
    echo Warning: There is not enough free space available in the destination folder. Required space: %required_space_kb% KB. Free space: %free_space_kb% KB.
    pause
    exit /b
)

REM Set the size limit for each folder in bytes (8.97GB so ~under the threshold to get the next GB)
set /a size_limit_kb=9405726
REM set limit for max number of files to move at once (255)
set /a file_limit = 255

REM Initialize variables
set /a current_folder_size=0
set /a folder_index=1
set "current_folder=Part !folder_index!"
set /a file_count_in_batch=0

REM Create the first folder in the destination directory
mkdir "!dest_folder!\!current_folder!"

REM Temporary file to store the list of files to be moved
set "file_list="

echo Beginning to move files...
REM First pass: Calculate cumulative sizes and set breakpoints
for %%f in ("!source_folder!\*.wav") do (
    REM Get the size of the current file in KB
    set /a file_size_bytes=%%~zf
    set /a file_size_kb=file_size_bytes/1024
    
    REM Check if adding the file would exceed the folder size limit
    set /a new_folder_size_kb=current_folder_size+file_size_kb
    if !new_folder_size_kb! geq !size_limit_kb! (
		echo Moving !file_count_in_batch! files into "!current_folder!"

        REM Move the accumulated files in bulk
        robocopy "!source_folder!" "!dest_folder!\!current_folder!" !file_list! /mov /njh /njs /ndl /nc /ns /nfl
        
        REM Reset file list and folder size
        set "file_list="
		set /a file_count_in_batch=0
        set /a current_folder_size=0
        set /a folder_index+=1
        set "current_folder=Part !folder_index!"
        mkdir "!dest_folder!\!current_folder!"
    )

    REM Add the file to the list for bulk moving
    set "file_list=!file_list! "%%~nxf""

    REM Update the current folder size
    set /a current_folder_size+=file_size_kb
	set /a file_count_in_batch+=1
	
	if !file_count_in_batch! geq !file_limit! (
		echo Moving !file_count_in_batch! files into "!current_folder!"

        REM Move the accumulated files in bulk
        robocopy "!source_folder!" "!dest_folder!\!current_folder!" !file_list! /mov /njh /njs /ndl /nc /ns /nfl
        
        REM Reset file list and folder size
        set "file_list="
		set /a file_count_in_batch=0
	)
)

REM After the loop, move any remaining files
if defined file_list (
	echo Moving !file_count_in_batch! files into "!current_folder!"
    robocopy "!source_folder!" "!dest_folder!\!current_folder!" !file_list! /mov /njh /njs /ndl /nc /ns /nfl
)

echo All files have been organized into folders.
pause
