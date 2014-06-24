function CheckRemoveDir($path)
{
    if (Test-Path $path) {
        Remove-Item -Recurse -Force $path
    }
}

function CheckCopyDir($src, $dest)
{
    CheckRemoveDir $dest
    Copy-Item $src $dest -Recurse
}

function CheckDir($path)
{
    if (!(Test-Path -path $path))
    {
        mkdir $path
    }
}

function GitClonePull($path, $url, $branch="master")
{
    Write-Host "Cloning / pulling: $url"

    $needspull = $true

    if (!(Test-Path -path $path))
    {
        git clone -b $branch $url
        if ($LastExitCode) { throw "git clone failed" }
        $needspull = $false
    }

    if ($needspull)
    {
        pushd .
        try
        {
            cd $path

            $branchFound = (git branch)  -match "(.*\s)?$branch"
            if ($LastExitCode) { throw "git branch failed" }

            if($branchFound)
            {
                git checkout $branch
                if ($LastExitCode) { throw "git checkout failed" }
            }
            else
            {
                git checkout -b $branch origin/$branch
                if ($LastExitCode) { throw "git checkout failed" }
            }

            git reset --hard
            if ($LastExitCode) { throw "git reset failed" }

            git clean -f -d
            if ($LastExitCode) { throw "git clean failed" }

            git pull
            if ($LastExitCode) { throw "git pull failed" }
        }
        finally
        {
            popd
        }
    }
}

function PullInstall($path, $url)
{
    GitClonePull $path $url

    pushd .
    try
    {
        cd $path

        # Remove build directory
        CheckRemoveDir "build"

        # Remove Python compiled files
        Get-ChildItem  -include "*.pyc" -recurse | foreach ($_) {remove-item $_.fullname}

        python setup.py build --force
        if ($LastExitCode) { throw "python setup.py build failed" }

        python setup.py install --force
        if ($LastExitCode) { throw "python setup.py install failed" }

        # Workaround for a setup related issue
        python setup.py install
        if ($LastExitCode) { throw "python setup.py install failed" }
    }
    finally
    {
        popd
    }
}

function Expand7z($archive, $outputDir = ".")
{
    pushd .
    try
    {
        cd $outputDir
        &7z.exe x -y $archive
        if ($LastExitCode) { throw "7z.exe failed on archive: $archive"}
    }
    finally
    {
        popd
    }
}

function PullRelease($project, $release, $version)
{
    pushd .
    try
    {
        $projectVer = "$project-$version"
        $tarFile = "$projectVer.tar"
        $tgzFile = "$tarFile.gz"
        $url = "https://launchpad.net/$project/$release/$version/+download/$tgzFile"

        DownloadFile $url "$pwd\$tgzFile"

        Expand7z $tgzFile
        Remove-Item -Force $tgzFile
        cd ".\dist"
        CheckRemoveDir $projectVer
        Expand7z $tarFile
        Remove-Item -Force $tarFile
    }
    finally
    {
        popd
    }
}

function InstallRelease($project, $version)
{
    pushd .
    try
    {
        $projectVer = "$project-$version"
        cd ".\dist"
        cd $projectVer
        &python setup.py install --force
        if ($LastExitCode) { throw "python setup.py build failed" }
        cd ..
        Remove-Item -Recurse -Force $projectVer
    }
    finally
    {
        popd
    }
}

function PullInstallRelease($project, $release, $version)
{
    PullRelease $project $release $version
    InstallRelease $project $version
}

function PipInstall($python_dir, $package)
{
    python "$python_dir\Scripts\pip-script.py" install $package --force
    if ($LastExitCode) { throw "pip install failed on package: $package" }
}

function SetVCVars($version="12.0")
{
    pushd "$ENV:ProgramFiles (x86)\Microsoft Visual Studio $version\VC\"
    try
    {
        cmd /c "vcvarsall.bat&set" |
        foreach {
          if ($_ -match "=") {
            $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
          }
        }
    }
    finally
    {
        popd
    }
}

function ReplaceVSToolSet($toolset)
{
    Get-ChildItem -Filter *.vcxproj -Recurse |
    Foreach-Object {
        $vcxprojfile = $_.FullName
        (Get-Content $vcxprojfile) |
        Foreach-Object {$_ -replace "<PlatformToolset>[^<]+</PlatformToolset>", "<PlatformToolset>$toolset</PlatformToolset>"} |
        Set-Content $vcxprojfile
    }
}

function SetRuntimeLibrary($runtimeLibrary)
{
    Get-ChildItem -Filter *.vcxproj -Recurse |
    Foreach-Object {
        $vcxprojfile = $_.FullName
        (Get-Content $vcxprojfile) |
        Foreach-Object {$_ -replace "<RuntimeLibrary>[^<]+</RuntimeLibrary>", "<RuntimeLibrary>$runtimeLibrary</RuntimeLibrary>"} |
        Set-Content $vcxprojfile
    }
}

function PatchFromGitCommit($sourcePath, $destPath, $gitRef, $gerritUrl, $gerritRef, $filesToPatch)
{
    pushd .
    try
    {
        pushd .
        cd $sourcePath

        if ($gerritUrl)
        {
            &git fetch $gerritUrl $gerritRef
            if ($LastExitCode) { throw "git fetch failed for Gerrit patchset: $gerritUrl $gerritRef" }
            $gitRef = "FETCH_HEAD"
        }

        $patch = &git format-patch -1 --stdout $gitRef -- $filesToPatch
        if ($LastExitCode) { throw "git format-patch failed for commit: $gitRef" }
        popd

        cd $destPath
        $patch -join "`n" | &patch -p1
        if ($LastExitCode) { throw "patch failed for commit: $gitRef" }
    }
    finally
    {
        popd
    }
}

function PatchRelease($project, $version, $gitRef, $gerritUrl, $gerritRef, $filesToPatch)
{
    $destPath = ".\dist\$project-$version"
    PatchFromGitCommit $project $destPath $gitRef $gerritUrl $gerritRef $filesToPatch
}

function ExecRetry($command, $maxRetryCount = 10, $retryInterval=2)
{
    $currErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $retryCount = 0
    while ($true)
    {
        try
        {
            & $command
            break
        }
        catch [System.Exception]
        {
            $retryCount++
            if ($retryCount -ge $maxRetryCount)
            {
                $ErrorActionPreference = $currErrorActionPreference
                throw
            }
            else
            {
                Write-Error $_.Exception
                Start-Sleep $retryInterval
            }
        }
    }

    $ErrorActionPreference = $currErrorActionPreference
}

function GetCredentialsFromFile($path)
{
    # To populate the credentials file use:
    # $username | Out-File $path
    # read-host -assecurestring | convertfrom-securestring | Add-Content $path

    $data = Get-Content $path
    $username = $data[0]
    $securePass = $data[1] | convertto-securestring
    return new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$securePass
}

function RunCommand($cmd, $arguments, $expectedExitCode = 0)
{
    Write-Host "Executing: $cmd $arguments"

    $p = Start-Process -Wait -PassThru -NoNewWindow $cmd -ArgumentList $arguments
    if($p.ExitCode -ne $expectedExitCode)
    {
        throw "$cmd failed with exit code: $($p.ExitCode)"
    }
}

function DownloadFile($url, $dest)
{
    Write-Host "Downloading: $url"

    $webClient = New-Object System.Net.webclient
    $webClient.DownloadFile($url, $dest)
}

function DownloadInstall($url, $type, $arguments="")
{
    $guid = [System.Guid]::NewGuid().ToString()
    $path = "$guid.$type"

    try
    {

        ExecRetry { DownloadFile $url $path }
        if($type -eq "msi")
        {
            if(!$arguments)
            {
                $arguments = "/qn"
            }
            ExecRetry { RunCommand "msiexec.exe" "/i $path $arguments" }
        }
        else
        {
            ExecRetry { RunCommand $path $arguments }
        }
    }
    finally
    {
        if(test-Path $path) { del $path }
    }
}

function ChocolateyInstall($package)
{
    ExecRetry {
        &cinst $package
        if($lastexitcode)
        {
            throw "cinst failed with exit code: $lastexitcode"
        }
    }
}

function ImportCertificateUser($pfxPath, $pfxPassword) {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
        [System.Security.Cryptography.X509Certificates.StoreName]::My,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pfxPath, $pfxPassword,
        ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet -bor
         [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet))
    $store.Add($cert)

    return $cert.Thumbprint
}

function ChechFileHash($path, $hash, $algorithm="SHA1") {
    $h = Get-Filehash -Algorithm $algorithm $path
    if ($h.Hash.ToUpper() -ne $hash.ToUpper()) {
        throw "Hash comparison failed for file: $path"
    }
}
