echo off
echo *** Setting Alias=TfsDb
echo *** Setting SQLInstance=SQL-004

set DBSERVERALIAS=TfsDb 
set DBSERVER=SQL-004.appliediscloud.com
set DBSERVERPORT=1433

rem %windir%\system32\cliconfg.exe 

echo *** Changing Registry for 32 bit
reg add HKLM\Software\Microsoft\MSSQLServer\Client\ConnectTo /v %DBSERVERALIAS% /t REG_SZ /d "DBMSSOCN,%DBSERVER%,%DBSERVERPORT%" /f 
reg query HKLM\Software\Microsoft\MSSQLServer\Client\ConnectTo 
rem 64-bit support for database alias 
rem %windir%\SysWOW64\cliconfig.exe 
echo *** Changing Registry for 64 bit
rem if /i NOT "%PROCESSOR_ARCHITECTURE%" == "X86" ( 
    reg add HKLM\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo /v %DBSERVERALIAS% /t REG_SZ /d "DBMSSOCN,%DBSERVER%,%DBSERVERPORT%" /f 
    reg query HKLM\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo 
echo *** Script Complete