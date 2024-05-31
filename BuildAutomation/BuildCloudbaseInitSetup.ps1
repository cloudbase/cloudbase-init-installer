Param(
  [string]$platform = "x64",
  [string]$pythonversion = "3.12.3",
  [string]$pythonversionPrelease = "",
  [string]$SignX509Thumbprint = $null,
  [string]$release = $null,
  # Cloudbase-Init repo details
  [string]$CloudbaseInitRepoUrl = "https://github.com/cloudbase/cloudbase-init.git",
  [string]$CloudbaseInitRepoBranch = "master",
  # Use an already available installer or clone a new one.
  [switch]$ClonePullInstallerRepo = $true,
  [string]$InstallerDir = $null,
  [string]$VSRedistDir = "${ENV:ProgramFiles(x86)}\Common Files\Merge Modules",
  [string]$SignTimestampUrl = "http://timestamp.digicert.com?alg=sha256",
  [switch]$InstallEmbededPython
)

$ErrorActionPreference = "Stop"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\BuildUtils.ps1"

$PythonInstallerSha1Hash = @{
    "python-installer-3.12.3-x64.exe" = "B1207FBA545A75841E2DBCA2AD4F17B26414E0C1";
    "python-installer-3.12.3-x86.exe" = "FF180F8EA0B126E5A0FAF0A22EC50E96E5B9C5AB";
    "python-installer-3.13.0b1-x64.exe" = "46ADF56A03D91D39EA4E8B6F5FFB080C824BDFDA";
    "python-installer-3.13.0b1-x86.exe" = "62E6FE0D5C9267275ABDD36302F327EB4E68C794";
    "python-installer-3.12.3-embed-x64.zip" = "77558B39C2C8CBE056949DD49F445851911B76A7";
    "python-installer-3.12.3-embed-x86.zip" = "E24BB06C194DE9A3EC695F63079F3793992E8DA1";
}

$platformVCVarsRequired = "x86_amd64"
# On Visual Studio 2019, the mixed x86_amd64 VC variables
# make compilation for x86 use the x64 functions
if ($platform -eq "x86") {
    $platformVCVarsRequired = "x86"
}

SetVCVars "2019" $platformVCVarsRequired

# Needed for SSH
$ENV:HOME = $ENV:USERPROFILE

$python_dir = "C:\Python_CloudbaseInit"

$ENV:PATH = "$python_dir\;$python_dir\scripts;$ENV:PATH"
$ENV:PATH += ";$ENV:ProgramFiles (x86)\Git\bin\"
$ENV:PATH += ";$ENV:ProgramFiles\7-zip\"

$basepath = "C:\build\cloudbase-init"
CheckDir $basepath

function Install-PythonFromInstaller {
    param($python_template_dir)

    ExecRetry -maxRetryCount 3 {
        $pythonVersionInstaller = $pythonversion.Replace("-",".").Replace("_",".").Trim()
        $pythonVersionInstallerSuffix = $pythonVersionInstaller
        if ($pythonversionPrelease) {
            $pythonVersionInstallerSuffix = $pythonversionPrelease
        }
        $pythonArchInstaller = ""
        if ($platform -eq "x64") {
            $pythonArchInstaller = "-amd64"
        }
        $pythonInstallerName = "python-installer-${pythonVersionInstallerSuffix}-${platform}.exe"
        $pythonInstallerPath = (Join-Path $pwd $pythonInstallerName)
        $PythonInstallerUrl = "https://www.python.org/ftp/python/${pythonVersionInstaller}/python-${pythonVersionInstallerSuffix}${pythonArchInstaller}.exe"
        DownloadFile $PythonInstallerUrl $pythonInstallerPath
        $expectedSha1Hash = $PythonInstallerSha1Hash[$pythonInstallerName]
        if (!$expectedSha1Hash) {
            throw "expected Sha1 Hash for ${pythonInstallerPath} is not configured"
        }
        $sha1Hash  = (Get-FileHash -Algorithm SHA1 $pythonInstallerPath).Hash
        if ($sha1Hash -ne $expectedSha1Hash) {
            throw "$pythonInstallerPath SHA1 hash is: ${sha1Hash}. Expected hash: ${expectedSha1Hash}"
        }

        try {
            Write-Host "Trying to uninstall Python ${pythonVersionInstaller} to ${python_template_dir}"
            $installProcess  = Start-Process -PassThru -Wait $pythonInstallerPath `
                -ArgumentList "/silent /uninstall"
            $installProcess.WaitForExit()
            if ($installProcess.ExitCode -ne 0) {
                Write-Host "Failed to uninstall ${pythonVersionInstaller} from ${python_template_dir}. Exit code: $($installProcess.ExitCode)"
            } else {
                Write-Host "Uninstalled Python ${pythonVersionInstaller} from ${python_template_dir}"
            }
            if ($python_template_dir -and (Test-Path $python_template_dir)) {
                Remove-Item -Force -Recurse "${python_template_dir}"
            }
        } catch {Write-Host $_}

        Write-Host "Trying to install Python ${pythonVersionInstaller} to ${python_template_dir}"
        $installProcess  = Start-Process -PassThru -Wait $pythonInstallerPath `
            -ArgumentList "/silent TargetDir=${python_template_dir} Include_test=0 Include_tcltk=0 Include_launcher=0 Include_doc=0"
        $installProcess.WaitForExit()
        if ($installProcess.ExitCode -ne 0) {
            throw "Failed to install ${pythonVersionInstaller} to ${python_template_dir}. Exit code: $($installProcess.ExitCode)"
        }
        Write-Host "Installed Python ${pythonVersionInstaller} to ${python_template_dir}"
    }
}

function Install-PythonEmbedded {
    param($python_template_dir)

    ExecRetry -maxRetryCount 3 {
        $pythonVersionInstaller = $pythonversion.Replace("-",".").Replace("_",".").Trim()
        $pythonVersionInstallerSuffix = $pythonVersionInstaller
        if ($pythonversionPrelease) {
            $pythonVersionInstallerSuffix = $pythonversionPrelease
        }
        $pythonArchInstaller = "-win32"
        if ($platform -eq "x64") {
            $pythonArchInstaller = "-amd64"
        }
        $pythonInstallerName = "python-installer-${pythonVersionInstallerSuffix}-embed-${platform}.zip"
        $pythonInstallerPath = (Join-Path $pwd $pythonInstallerName)
        $PythonInstallerUrl = "https://www.python.org/ftp/python/${pythonVersionInstaller}/python-${pythonVersionInstallerSuffix}-embed${pythonArchInstaller}.zip"
        DownloadFile $PythonInstallerUrl $pythonInstallerPath
        $expectedSha1Hash = $PythonInstallerSha1Hash[$pythonInstallerName]
        if (!$expectedSha1Hash) {
            throw "expected Sha1 Hash for ${pythonInstallerPath} is not configured"
        }
        $sha1Hash  = (Get-FileHash -Algorithm SHA1 $pythonInstallerPath).Hash
        if ($sha1Hash -ne $expectedSha1Hash) {
            throw "$pythonInstallerPath SHA1 hash is: ${sha1Hash}. Expected hash: ${expectedSha1Hash}"
        }
        if ($python_template_dir -and (Test-Path $python_template_dir)) {
            Remove-Item -Force -Recurse "${python_template_dir}"
        }
        Expand-Archive $pythonInstallerPath -DestinationPath $python_template_dir

        Write-Host "Installed Python ${pythonVersionInstaller} to ${python_template_dir}"
    }
}

pushd .
try
{
    cd $basepath

    # Don't use the default pip temp directory to avoid concurrency issues
    $ENV:TMPDIR = Join-Path $basepath "temp"
    CheckRemoveDir $ENV:TMPDIR
    mkdir $ENV:TMPDIR

    if ($ClonePullInstallerRepo)
    {
        # Clone a new installer repo no matter what.
        $cloudbaseInitInstallerDir = join-Path $basepath "cloudbase-init-installer"
        ExecRetry {
            GitClonePull $cloudbaseInitInstallerDir "https://github.com/cloudbase/cloudbase-init-installer.git"
        }
    }
    else
    {
        if (!$InstallerDir)
        {
            # No path provided, so use the current installer script path.
            $InstallerDir = (Join-Path -Path $PSScriptRoot -ChildPath ..\ -Resolve)
        }
        if (Test-Path $InstallerDir)
        {
            $cloudbaseInitInstallerDir = $InstallerDir
        }
        else
        {
            throw "Installer path not present: $InstallerDir"
        }
    }


    $python_template_dir = join-path $cloudbaseInitInstallerDir "Python$($pythonversion.replace('.', ''))_${platform}_Template"

    if ($InstallEmbededPython) {
        Install-PythonEmbedded $python_template_dir
    } else {
        Install-PythonFromInstaller $python_template_dir
    }

    CheckCopyDir $python_template_dir $python_dir

    # Make sure that we don't have temp files from a previous build
    $python_build_path = "$ENV:LOCALAPPDATA\Temp\pip_build_$ENV:USERNAME"
    if (Test-Path $python_build_path) {
        Remove-Item -Recurse -Force $python_build_path
    }

    if ($InstallEmbededPython) {
        try {
            DownloadFile "https://bootstrap.pypa.io/get-pip.py" "${scriptPath}\get-pip.py"
            & python.exe "${scriptPath}\get-pip.py"
            Out-File -Append -InputObject "Lib\site-packages" -Encoding ascii $python_dir\python*._pth
        } finally {
            Remove-Item -Force -ErrorAction SilentlyContinue "${scriptPath}\get-pip.py"
        }
    }

    ExecRetry { PipInstall "pip" -update $true }
    ExecRetry { PipInstall "wheel" -update $true }
    ExecRetry { PipInstall "setuptools" -update $true }

    ExecRetry { PullInstall "requirements" "https://github.com/openstack/requirements" }
    $upper_constraints_file = $(Resolve-Path ".\requirements\upper-constraints.txt").Path
    $env:PIP_CONSTRAINT = $upper_constraints_file
    $env:PIP_NO_BINARIES = "cloudbase-init"

    if ($release)
    {
        ExecRetry { PipInstall "cloudbase-init==$release" }
    }
    else
    {
        ExecRetry { PullInstall "cloudbase-init" $CloudbaseInitRepoUrl $CloudbaseInitRepoBranch }
    }

    $release_dir = join-path $cloudbaseInitInstallerDir "CloudbaseInitSetup\bin\Release\$platform"
    $bin_dir = join-path $cloudbaseInitInstallerDir "CloudbaseInitSetup\Binaries\$platform"

    $zip_content_dir = join-path $release_dir "zip_content"
    CheckRemoveDir $zip_content_dir
    mkdir $zip_content_dir

    $python_dir_release = join-path $zip_content_dir "Python"
    $bin_dir_release = join-path $zip_content_dir "Bin"

    CheckCopyDir $python_dir $python_dir_release
    CheckCopyDir $bin_dir $bin_dir_release

    $zip_path = join-path $release_dir "CloudbaseInitSetup.zip"
    if (Test-Path $zip_path) {
        del $zip_path
    }

    pushd $zip_content_dir
    try
    {
        CreateZip $zip_path *
    }
    finally
    {
        popd
    }

    $version = &"$python_dir\python.exe" -c "from cloudbaseinit import version; print(version.get_version())"
    if ($LastExitCode -or !$version.Length) { throw "Unable to get cloudbase-init version" }
    Write-Host "Cloudbase-Init version: $version"

    try
    {
        [int]::Parse($version.Substring($version.LastIndexOf('.') + 1)) | out-null
        $msi_version = $version + ".0"
        Write-Host "This is a tagged stable release"
    }
    catch
    {
        $msi_version = $version.Substring(0, $version.LastIndexOf('.')) + ".0"
    }

    Write-Host "Cloudbase-Init MSI version: $msi_version"

    $installer_sources_dir = join-path $cloudbaseInitInstallerDir "CloudbaseInitSetup"

    if($platform -eq "x64")
    {
        copy "${VSRedistDir}\Microsoft_VC140_CRT_x64.msm" $installer_sources_dir
    }
    else
    {
        copy "${VSRedistDir}\Microsoft_VC140_CRT_x86.msm" $installer_sources_dir
    }

    cd $cloudbaseInitInstallerDir

    &msbuild CloudbaseInitSetup.sln /m /p:Platform=$platform /p:Configuration=`"Release`"  /p:DefineConstants=`"PythonSourcePath=$python_dir`;CarbonSourcePath=Carbon`;Version=$msi_version`;VersionStr=$version`"
    if ($LastExitCode) { throw "MSBuild failed" }

    $msi_path = join-path $cloudbaseInitInstallerDir "CloudbaseInitSetup\bin\Release\$platform\CloudbaseInitSetup.msi"

    if($SignX509Thumbprint)
    {
        ExecRetry {
            Write-Host "Signing MSI with certificate: $SignX509Thumbprint"
            signtool.exe sign /sha1 $SignX509Thumbprint /tr $SignTimestampUrl /td SHA256 /v $msi_path
            if ($LastExitCode) { throw "signtool failed" }
        }
    }
    else
    {
        Write-Warning "MSI not signed"
    }

    Remove-Item -Recurse -Force $python_dir
}
finally
{
    popd
}
