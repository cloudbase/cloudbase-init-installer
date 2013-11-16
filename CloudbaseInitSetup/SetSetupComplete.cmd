mkdir "%SYSTEMROOT%\Setup\Scripts"
sc config cloudbase-init start= demand
echo sc config cloudbase-init start= auto ^&^& net start cloudbase-init > "%SYSTEMROOT%\Setup\Scripts\SetupComplete.cmd"
