$ErrorActionPreference = "Stop"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\BuildUtils.ps1"

$basepath = "C:\OpenStack\build\cloudbase-init"
CheckDir $basepath
cd $basepath

$python_dir = "C:\Python27_CloudbaseInit"
$python_template_dir = $python_dir + "_Template"

CheckCopyDir $python_template_dir $python_dir

$ENV:PATH += ";$ENV:ProgramFiles (x86)\Git\bin\"
$ENV:PATH += ";C:\Tools\AlexFTPS-1.1.0"
$ENV:PATH += ";$python_dir\;$python_dir\scripts"

# Needed for SSH
$ENV:HOME = $ENV:USERPROFILE

# Don't use the default pip temp directory to avoid concurrency issues
$ENV:TMPDIR = Join-Path $basepath "temp"
CheckRemoveDir $ENV:TMPDIR
mkdir $ENV:TMPDIR

$sign_cert_thumbprint = "65c29b06eb665ce202676332e8129ac48d613c61"
$ftpsCredentials = GetCredentialsFromFile "$ENV:UserProfile\ftps.txt"

SetVCVars

git config --global user.name "Alessandro Pilotti"
git config --global user.email "ap@pilotti.it"

# Make sure that we don't have temp files from a previous build
$python_build_path = "$ENV:LOCALAPPDATA\Temp\pip_build_$ENV:USERNAME"
if (Test-Path $python_build_path) {
	Remove-Item -Recurse -Force $python_build_path
}

python $python_dir\scripts\pip-2.7-script.py install -U pbr==0.5.22
if ($LastExitCode) { throw "pip install failed" }

PipInstall $python_dir "distribute"

PullInstall "cloudbase-init" "https://github.com/cloudbase/cloudbase-init.git"

pushd .

# Make sure to have a private key that matches a github deployer key in $ENV:HOME\.ssh\id_rsa
GitClonePull "cloudbase-init-installer" "git@github.com:/cloudbase/cloudbase-init-installer.git"

cd cloudbase-init-installer\CloudbaseInitSetup

&msbuild CloudbaseInitSetup.wixproj /p:Platform=x86 /p:Configuration=Release /p:DefineConstants=`"Python27SourcePath=$python_dir`"
if ($LastExitCode) { throw "MSBuild failed" }

$msi_path = "bin\Release\CloudbaseInitSetup.msi"

signtool.exe sign /sha1 $sign_cert_thumbprint /t http://timestamp.verisign.com/scripts/timstamp.dll /v $msi_path
if ($LastExitCode) { throw "signtool failed" }

$ftpsUsername = $ftpsCredentials.UserName
$ftpsPassword = $ftpsCredentials.GetNetworkCredential().Password

&ftps -h www.cloudbase.it -ssl All -U $ftpsUsername -P $ftpsPassword -sslInvalidServerCertHandling Accept -p $msi_path /cloudbase.it/main/downloads/CloudbaseInitSetup_Beta.msi
if ($LastExitCode) { throw "ftps failed" }

Remove-Item -Recurse -Force $python_dir

popd
