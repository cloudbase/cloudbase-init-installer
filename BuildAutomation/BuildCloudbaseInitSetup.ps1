$ErrorActionPreference = "Stop"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\BuildUtils.ps1"

$basepath = "C:\OpenStack"
CheckDir $basepath
cd $basepath

$python_dir = "C:\Python27_CloudbaseInit"
$python_template_dir = $python_dir + "_Template"

CheckCopyDir $python_template_dir $python_dir

$ENV:PATH += ";$ENV:ProgramFiles (x86)\Git\bin\"
$ENV:PATH += ";C:\Tools\AlexFTPS-1.1.0"
$ENV:PATH += ";$python_dir\;$python_dir\scripts"
$ENV:PATH += ";$ENV:ProgramFiles\TortoiseSVN\bin"

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

# Note: pbr updates pip
python $python_dir\scripts\pip-script.py install -U distribute
if ($LastExitCode) { throw "pip install failed" }

PullInstall "cloudbase-init" "https://github.com/cloudbase/cloudbase-init.git"

pushd .

$setupdir = "CloudbaseInitSetup" 
CheckDir $setupdir
cd $setupdir

svn co https://srv1.cloudbase.it/svn/cloudbaseinitsetup/CloudbaseInitSetup/trunk/ --username autobuild --password LsdU3mGMnj --non-interactive --trust-server-cert
if ($LastExitCode) { throw "svn checkout failed" }

cd trunk\CloudbaseInitSetup
&msbuild CloudbaseInitSetup.wixproj /p:Platform=x86 /p:Configuration=Release /p:DefineConstants=`"Python27SourcePath=$python_dir`"
if ($LastExitCode) { throw "MSBuild failed" }

&ftps -h www.cloudbase.it -ssl All -U ociuhandu -P nnxwf5wu -sslInvalidServerCertHandling Accept -p bin\Release\CloudbaseInitSetup.msi /cloudbase.it/main/downloads/CloudbaseInitSetup_Beta.msi

Remove-Item -Recurse -Force $python_dir

popd
