## Cloudbase-Init Installer code

### How the Python template folder has been created

```powershell
#ps1

$currentPath = (Resolve-Path .).Path
$templateName = "Python311_6_x64_Template"
$pythonTemplateFolder = Join-Path $currentPath $templateName
python-3.11.6-amd64.exe /quiet TargetDir="${pythonTemplateFolder}" Include_test=0 Include_tcltk=0 Include_launcher=0 Include_doc=0
pushd $pythonTemplateFolder
    Get-ChildItem -Path .\ -Recurse -Include *.pyc,*__pycache__ | foreach ($_) { Remove-Item $_.FullName -Force -Recurse }
popd
```