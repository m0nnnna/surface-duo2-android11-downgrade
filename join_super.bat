@echo off
:: Reassemble super_built.img from the release parts (Windows).
:: Run this in the folder that contains the super_built.img.part* files.
cd /d "%~dp0"
echo Joining super_built.img.part00..03 -> super_built.img ...
copy /b /y super_built.img.part00+super_built.img.part01+super_built.img.part02+super_built.img.part03 super_built.img
echo Done. Verify with: certutil -hashfile super_built.img SHA256
pause
