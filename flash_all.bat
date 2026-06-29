@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
set FB=fastboot.exe

echo ================================================================
echo   Surface Duo 2  -^>  Android 11 (2022.521.8)  full restore
echo   This ERASES ALL DATA. Bootloader must be UNLOCKED.
echo ================================================================
echo.
echo Detecting device (must be in bootloader/fastboot mode)...
%FB% devices | find "fastboot" >nul
if errorlevel 1 (
  echo   No fastboot device found. Put the phone in the bootloader and retry.
  pause & exit /b 1
)
%FB% getvar product 2>&1 | find "surfaceduo2" >nul
if errorlevel 1 ( echo   WARNING: device does not report product=surfaceduo2. )
echo.
echo Press a key to begin flashing, or close this window to abort.
pause >nul

:: ---- 1) firmware to BOTH slots (genuine A11) ----
for %%P in (abl aop bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster modem qupfw sfsecapp shrm tz uefisecapp xbl xbl_config) do (
  echo [firmware] %%P
  %FB% flash %%P_a images\%%P.img || goto :err
  %FB% flash %%P_b images\%%P.img || goto :err
)

:: ---- 2) boot chain to slot a ----
echo [boot chain] boot/dtbo/vendor_boot/vm-bootsys
%FB% flash boot_a        images\boot.img         || goto :err
%FB% flash dtbo_a        images\dtbo.img         || goto :err
%FB% flash vendor_boot_a images\vendor_boot.img  || goto :err
%FB% flash vm-bootsys_a  images\vm-bootsys.img   || goto :err

:: ---- 3) AVB: root vbmeta verity-DISABLED, system stock ----
echo [vbmeta] verity disabled
%FB% flash vbmeta_a        images\vbmeta_disabled.img || goto :err
%FB% flash vbmeta_system_a images\vbmeta_system.img   || goto :err

:: ---- 4) the corrected super (single, NON-slotted) ----
echo [super] flashing corrected super (~6.7 GB, takes a few minutes)...
%FB% flash super super_built.img || goto :err

:: ---- 5) wipe user data ----
echo [wipe] userdata + metadata
%FB% erase userdata
%FB% erase metadata

:: ---- 6) boot slot a ----
%FB% set_active a || goto :err
echo.
echo ================================================================
echo   DONE. Rebooting. First boot after wipe = 2-5 min, be patient.
echo ================================================================
%FB% reboot
pause
exit /b 0

:err
echo.
echo *** A fastboot command FAILED. Stop and check the output above. ***
pause
exit /b 1
