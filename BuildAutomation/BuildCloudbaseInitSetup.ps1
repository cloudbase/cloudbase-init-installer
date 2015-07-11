Param(
  [string]$SignX509Thumbprint,
  [string]$platform = "x64",
  [string]$release = $null
)

$ErrorActionPreference = "Stop"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\BuildUtils.ps1"

SetVCVars

# Needed for SSH
$ENV:HOME = $ENV:USERPROFILE

$python_dir = "C:\Python27_CloudbaseInit"

$ENV:PATH = "$python_dir\;$python_dir\scripts;$ENV:PATH"
$ENV:PATH += ";$ENV:ProgramFiles (x86)\Git\bin\"

$basepath = "C:\OpenStack\build\cloudbase-init"
CheckDir $basepath

pushd .
try
{
    cd $basepath

    # Don't use the default pip temp directory to avoid concurrency issues
    $ENV:TMPDIR = Join-Path $basepath "temp"
    CheckRemoveDir $ENV:TMPDIR
    mkdir $ENV:TMPDIR

    $cloudbaseInitInstallerDir = "cloudbase-init-installer"
    ExecRetry {
        # Make sure to have a private key that matches a github deployer key in $ENV:HOME\.ssh\id_rsa
        GitClonePull $cloudbaseInitInstallerDir "git@github.com:/cloudbase/cloudbase-init-installer.git"
    }

    if($platform -eq "x64") {
        $python_template_dir = "$cloudbaseInitInstallerDir\Python27_x64_Template"
    }
    else {
        $python_template_dir = "$cloudbaseInitInstallerDir\Python27_Template"
    }

    CheckCopyDir $python_template_dir $python_dir

    # Make sure that we don't have temp files from a previous build
    $python_build_path = "$ENV:LOCALAPPDATA\Temp\pip_build_$ENV:USERNAME"
    if (Test-Path $python_build_path) {
        Remove-Item -Recurse -Force $python_build_path
    }

    ExecRetry { PipInstall "pbr<1.0,>=0.11" }

    if ($release)
    {
        ExecRetry { PipInstall "cloudbase-init==$release" }
    }
    else
    {
        ExecRetry { PullInstall "cloudbase-init" "https://github.com/stackforge/cloudbase-init.git" }
    }

    ExecRetry { PipInstall "wmi" }

    $version = &"$python_dir\python.exe" -c "from cloudbaseinit import version; print version.get_version()"
    if ($LastExitCode -or !$version.Length) { throw "Unable to get cloudbase-init version" }
    Write-Host "Cloudbase-Init version: $version"

    $msi_version = $version.Substring(0, $version.LastIndexOf('.')) + ".0"
    Write-Host "Cloudbase-Init MSI version: $msi_version"

    cd $cloudbaseInitInstallerDir

    &msbuild CloudbaseInitSetup.sln /m /p:Platform=$platform /p:Configuration=`"Release`"  /p:DefineConstants=`"Python27SourcePath=$python_dir`;CarbonSourcePath=Carbon`;Version=$msi_version`"
    if ($LastExitCode) { throw "MSBuild failed" }

    $msi_path = "CloudbaseInitSetup\bin\Release\$platform\CloudbaseInitSetup.msi"

    if($SignX509Thumbprint)
    {
        ExecRetry {
            Write-Host "Signing MSI with certificate: $SignX509Thumbprint"
            signtool.exe sign /sha1 $SignX509Thumbprint /t http://timestamp.verisign.com/scripts/timstamp.dll /v $msi_path
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
