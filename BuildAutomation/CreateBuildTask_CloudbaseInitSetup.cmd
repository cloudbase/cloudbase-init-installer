schtasks.exe /create /tn CloudbaseInitSetupAutoBuild /tr C:\OpenStack\BuildCloudbaseInitSetup.cmd /sc DAILY /ru Administrator /rp /st 04:00:00
