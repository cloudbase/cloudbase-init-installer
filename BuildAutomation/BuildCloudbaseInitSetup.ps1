$ErrorActionPreference = "Stop"

function PullInstall($path, $url)
{
    $needspull = $true 

    if (!(Test-Path -path $path))
    {
        git clone $url
        if ($LastExitCode) { throw "git clone failed" }
        $needspull = $false
    }

    pushd .
    cd $path
    if ($needspull)
    {
        git pull
        if ($LastExitCode) { throw "git pull failed" }
    }
    python setup.py build --force
    if ($LastExitCode) { throw "python setup.py build failed" }

    python setup.py install --force
    if ($LastExitCode) { throw "python setup.py install failed" }

    python setup.py install
    if ($LastExitCode) { throw "python setup.py install failed" }

    popd
}

$basepath = "C:\OpenStack"
if (!(Test-Path -path $basepath))
{
    mkdir $basepath
}
cd $basepath

$python_dir = "C:\Python27_CloudbaseInit"
$python_template_dir = $python_dir + "_Template"

if (Test-Path $python_dir) {
	Remove-Item -Recurse -Force $python_dir
}
Copy-Item $python_template_dir $python_dir -Recurse

$ENV:PATH += ";$ENV:ProgramFiles (x86)\Git\bin\"
$ENV:PATH += ";C:\Tools\AlexFTPS-1.1.0"
$ENV:PATH += ";$python_dir\;$python_dir\scripts"
$ENV:PATH += ";$ENV:ProgramFiles\TortoiseSVN\bin"

pushd "$ENV:ProgramFiles (x86)\Microsoft Visual Studio 11.0\VC\"
cmd /c "vcvarsall.bat&set" |
foreach {
  if ($_ -match "=") {
    $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
  }
}
popd

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
if (!(Test-Path -path $setupdir))
{
    mkdir $setupdir
}

cd $setupdir
svn co https://srv1.cloudbase.it/svn/cloudbaseinitsetup/CloudbaseInitSetup/trunk/ --username autobuild --password LsdU3mGMnj --non-interactive --trust-server-cert
if ($LastExitCode) { throw "svn checkout failed" }

cd trunk\CloudbaseInitSetup
&msbuild CloudbaseInitSetup.wixproj /p:Platform=x86 /p:Configuration=Release /p:DefineConstants=`"Python27SourcePath=$python_dir`"
if ($LastExitCode) { throw "MSBuild failed" }

&ftps -h www.cloudbase.it -ssl All -U ociuhandu -P nnxwf5wu -sslInvalidServerCertHandling Accept -p bin\Release\CloudbaseInitSetup.msi /cloudbase.it/main/downloads/CloudbaseInitSetup_Beta.msi

Remove-Item -Recurse -Force $python_dir

popd




