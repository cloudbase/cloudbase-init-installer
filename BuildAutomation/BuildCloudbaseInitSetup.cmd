@ECHO OFF

set SCRIPTNAME=BuildCloudbaseInitSetup
set OUTFILE=%SCRIPTNAME%_out.txt
set ERRFILE=%SCRIPTNAME%_err.txt

C:
cd \OpenStack
Powershell -Command .\%SCRIPTNAME%.ps1 1> %OUTFILE% 2> %ERRFILE%
IF ERRORLEVEL 1 GOTO sendemail
goto gata
:sendemail
Powershell -Command .\SendResultsEmail.ps1 %SCRIPTNAME% %OUTFILE% %ERRFILE%
:gata
