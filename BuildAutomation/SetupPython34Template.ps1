$ErrorActionPreference = "Stop"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

$defaultPythonDir = "C:\Python34"
$pythonDir = "C:\Python34_CloudbaseInit"
$pythonScriptsDir = "$pythonDir\scripts"
$ENV:PATH = "$pythonDir;$pythonScriptsDir;$ENV:PATH"
$ENV:PATH += ";${ENV:ProgramFiles}\7-zip"

function VerifyHash($filename, $expectedHash) {
    $hash = (Get-FileHash -Algorithm SHA1 $filename).Hash
    if ($hash -ne $expectedHash) {
        throw "SHA1 hash not valid for file: $filename. Expected: $expectedHash Current: $hash"
    }
}

function Expand7z($archive, $outputDir = ".")
{
    $archivePath = Resolve-Path $archive

    pushd .
    try
    {
        cd $outputDir
        &7z.exe x -y $archivePath
        if ($LastExitCode) { throw "7z.exe failed on archive: $archivePath"}
    }
    finally
    {
        popd
    }
}

function CheckRemoveDir($path)
{
    if (Test-Path $path) {
        Remove-Item -Recurse -Force $path
    }
}

function Install-Python() {
    $filename = "python.msi"
    Start-BitsTransfer -Source "https://www.python.org/ftp/python/3.4.1/python-3.4.1.msi" -Destination $filename
    VerifyHash $filename "BA88B1936D034385C132DE18D6259F5850DCCE70"
    Start-Process -Wait msiexec.exe -ArgumentList "/i $filename /qn TARGETDIR=$defaultPythonDir"
    del $filename
}

function Install-PyWin32() {
    $url = "http://downloads.sourceforge.net/project/pywin32/pywin32/Build%20219/pywin32-219.win32-py3.4.exe"
    $filename = "pywin32.exe"
    Start-BitsTransfer -Source $url -Destination $filename
    VerifyHash $filename "fc8e85a8bce33703fdae0afb37e0adb508402d19"

    $tmpDir = "pywin32"
    CheckRemoveDir $tmpDir
    mkdir $tmpDir
    Expand7z $filename $tmpDir
    $platLibDir = "$tmpDir\PLATLIB"
    $scriptsDir = "$tmpDir\SCRIPTS"
    $sitePackagesDir = "$pythonDir\Lib\Site-Packages"
    Copy-Item -Recurse -Force "$platLibDir\*" $sitePackagesDir
    & "$pythonDir\python.exe" "$scriptsDir\pywin32_postinstall.py" -install
    if ($LastExitCode) { throw "pywin32_postinstall.py failed"}
    #& "$pythonDir\python.exe" "$scriptsDir\pywin32_testall.py"
    #if ($LastExitCode) { throw "pywin32_testall.py failed"}

    rmdir -Recurse -Force $tmpDir
    del $filename
}

if (!(Test-Path $defaultPythonDir)) {
    Install-Python
}

if ((Resolve-Path $pythonDir).Path -ne (Resolve-Path $defaultPythonDir).Path) {
    CheckRemoveDir $pythonDir
    mkdir $pythonDir
    Copy-Item -Recurse $defaultPythonDir\* $pythonDir

    & "$pythonDir\python.exe" "$scriptPath\change_python_launchers_exe_path.py" "pip=pip:main"
    if ($LastExitCode) { throw "change_python_launchers_exe_path.py failed"}
    copy "$pythonScriptsDir\pip.exe" "$pythonScriptsDir\pip3.exe"
    copy "$pythonScriptsDir\pip.exe" "$pythonScriptsDir\pip3.4.exe"

    & "$pythonDir\python.exe" "$scriptPath\change_python_launchers_exe_path.py" "easy_install=setuptools.command.easy_install:main"
    if ($LastExitCode) { throw "change_python_launchers_exe_path.py failed"}
}

Install-PyWin32
