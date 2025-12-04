## Cloudbase-Init Installer code

### Build requirements

The project currently requires Visual Studio 2019 with v141 build tools.
TODO: ``UtilsActions`` project uses APIs that have been removed from more recent toolset versions and will have to be updated.

### How the Python template folder has been created

```powershell
#ps1

$currentPath = (Resolve-Path .).Path
$templateName = "Python311_6_x64_Template"
$pythonTemplateFolder = Join-Path $currentPath $templateName
$pythonInstaller = ".\python-3.13.10-amd64.exe"
Start-Process -FilePath "${$pythonInstaller}" -NoNewWindow -Wait -ArgumentList @("/quiet", "TargetDir=${pythonTemplateFolder}","Include_test=0","Include_tcltk=0","Include_launcher=0","Include_doc=0")

# pushd $pythonTemplateFolder
#    Get-ChildItem -Path .\ -Recurse -Include *.pyc,*__pycache__ | foreach ($_) { Remove-Item $_.FullName -Force -Recurse }
# popd
```
