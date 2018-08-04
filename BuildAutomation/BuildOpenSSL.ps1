Param(
  [ValidateSet("x86", "amd64", "x86_amd64")]
  [string]$Platform = "amd64",
  [ValidateSet(12, 14)]
  [UInt16]$VSVersionNumber = 14,
  [string]$OpenSSLVersion = "1.0.2o",
  [string]$OpenSSLSha1 = "a47faaca57b47a0d9d5fb085545857cc92062691",
  [string]$BuildDir = "C:\Build\OpenSSL"
)

$ErrorActionPreference = "Stop"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\BuildUtils.ps1"

function BuildOpenSSL($buildDir, $outputPath, $opensslVersion, $platform, $cmakeGenerator, $platformToolset,
                      $dllBuild=$true, $runTests=$true, $hash=$null)
{
    $opensslBase = "openssl-$opensslVersion"
    $opensslPath = "$ENV:Temp\$opensslBase.tar.gz"
    $opensslUrl = "https://www.openssl.org/source/$opensslBase.tar.gz"

    pushd .
    try
    {
        cd $buildDir

        # Needed by the OpenSSL server
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        ExecRetry { (new-object System.Net.WebClient).DownloadFile($opensslUrl, $opensslPath) }

        if($hash) { ChechFileHash $opensslPath $hash }

        Expand7z $opensslPath
        del $opensslPath
        Expand7z "$opensslBase.tar"
        del "$opensslBase.tar"

        cd $opensslBase
        &cmake . -G $cmakeGenerator -T $platformToolset

        $platformMap = @{"x86"="VC-WIN32"; "amd64"="VC-WIN64A"; "x86_amd64"="VC-WIN64A"}
        &perl Configure $platformMap[$platform] --prefix="$ENV:OPENSSL_ROOT_DIR"
        if ($LastExitCode) { throw "perl failed" }

        if($platform -eq "amd64" -or $platform -eq "x86_amd64")
        {
            &.\ms\do_win64a
            if ($LastExitCode) { throw "do_win64 failed" }
        }
        elseif($platform -eq "x86")
        {
            &.\ms\do_nasm
            if ($LastExitCode) { throw "do_nasm failed" }
        }
        else
        {
            throw "Invalid platform: $platform"
        }

        if($dllBuild)
        {
            $makFile = "ms\ntdll.mak"
        }
        else
        {
            $makFile = "ms\nt.mak"
        }

        &nmake -f $makFile
        if ($LastExitCode) { throw "nmake failed" }

        if($runTests)
        {
            &nmake -f $makFile test
            if ($LastExitCode) { throw "nmake test failed" }
        }

        &nmake -f $makFile install
        if ($LastExitCode) { throw "nmake install failed" }

        copy "$ENV:OPENSSL_ROOT_DIR\bin\*.dll" $outputPath
        copy "$ENV:OPENSSL_ROOT_DIR\bin\*.exe" $outputPath
    }
    finally
    {
        popd
    }
}

$vsVersion = "${VSVersionNumber}.0"

$cmakePlatformMap = @{"x86"=""; "amd64"=" Win64"; "x86_amd64"=" Win64"}
$cmakeGenerator = "Visual Studio $($vsVersion.Split(".")[0])$($cmakePlatformMap[$Platform])"
$platformToolset = "v$($vsVersion.Replace('.', ''))"

SetVCVars $vsVersion $Platform

# Make sure ActivePerl comes before MSYS Perl, otherwise
# the OpenSSL build will fail
$ENV:PATH = "C:\Perl64\bin;$ENV:PATH"
$ENV:PATH += ";$ENV:ProgramFiles\7-Zip"
$ENV:PATH += ";${ENV:ProgramFiles}\Git\bin"
$ENV:PATH += ";${ENV:ProgramFiles}\CMake\bin"
$ENV:PATH += ";${ENV:ProgramFiles}\nasm"

CheckRemoveDir $BuildDir
mkdir $BuildDir

pushd $BuildDir
try
{
    $outputPath = "$BuildDir\bin"
    mkdir $outputPath
    $ENV:OPENSSL_ROOT_DIR="$OutputPath\OpenSSL"

    BuildOpenSSL $BuildDir $outputPath $OpenSSLVersion $Platform $cmakeGenerator $platformToolset $true $true $OpenSSLSha1
}
finally
{
    popd
}
