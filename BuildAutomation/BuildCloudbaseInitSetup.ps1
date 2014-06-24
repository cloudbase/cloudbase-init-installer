$ErrorActionPreference = "Stop"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\BuildUtils.ps1"

SetVCVars

# Needed for SSH
$ENV:HOME = $ENV:USERPROFILE

$python_dir = "C:\Python27_CloudbaseInit"

$ENV:PATH += ";$ENV:ProgramFiles (x86)\Git\bin\"
$ENV:PATH += ";C:\Tools\AlexFTPS-1.1.0"
$ENV:PATH += ";$python_dir\;$python_dir\scripts"

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

    $python_template_dir = "$cloudbaseInitInstallerDir\Python27_Template"
    CheckCopyDir $python_template_dir $python_dir

    ExecRetry {
        python $python_dir\scripts\pip-2.7-script.py install -U "pbr>=0.8"
        if ($LastExitCode) { throw "pip install failed" }
    }

    $sign_cert_thumbprint = "65c29b06eb665ce202676332e8129ac48d613c61"
    $ftpsCredentials = GetCredentialsFromFile "$ENV:UserProfile\ftps.txt"

    # Make sure that we don't have temp files from a previous build
    $python_build_path = "$ENV:LOCALAPPDATA\Temp\pip_build_$ENV:USERNAME"
    if (Test-Path $python_build_path) {
        Remove-Item -Recurse -Force $python_build_path
    }

    PipInstall $python_dir "distribute"

    PullInstall "cloudbase-init" "https://github.com/cloudbase/cloudbase-init.git"

    cd $cloudbaseInitInstallerDir\CloudbaseInitSetup

    foreach ($platform in @("x86", "x64"))
    {
        #&msbuild CloudbaseInitSetup.sln /m /p:Platform=$platform /p:Configuration=`"Release $platform`"  /p:DefineConstants=`"Python27SourcePath=$python_dir`;CarbonSourcePath=Carbon`"
        &msbuild CloudbaseInitSetup.wixproj /m /p:Platform=$platform /p:Configuration=`"Release`"  /p:DefineConstants=`"Python27SourcePath=$python_dir`;CarbonSourcePath=Carbon`"
        if ($LastExitCode) { throw "MSBuild failed" }

        $msi_path = "bin\Release\$platform\CloudbaseInitSetup.msi"

        ExecRetry {
            signtool.exe sign /sha1 $sign_cert_thumbprint /t http://timestamp.verisign.com/scripts/timstamp.dll /v $msi_path
            if ($LastExitCode) { throw "signtool failed" }
        }
    }

    $ftpsUsername = $ftpsCredentials.UserName
    $ftpsPassword = $ftpsCredentials.GetNetworkCredential().Password

    foreach ($platform in @("x86", "x64"))
    {
        $msi_path = "bin\Release\$platform\CloudbaseInitSetup.msi"

        ExecRetry {
            &ftps -h www.cloudbase.it -ssl All -U $ftpsUsername -P $ftpsPassword -sslInvalidServerCertHandling Accept -p $msi_path "/cloudbase.it/main/downloads/CloudbaseInitSetup_Beta_$platform.msi"
            if ($LastExitCode) { throw "ftps failed" }
        }
    }

    Remove-Item -Recurse -Force $python_dir
}
finally
{
    popd
}
