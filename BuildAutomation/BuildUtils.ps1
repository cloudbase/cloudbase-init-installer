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

function Expand7z($archive)
{
	&7z.exe x -y $archive
	if ($LastExitCode) { throw "7z.exe failed on archive: $archive"}
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

        Write-Host "Downloading: $url"

        Invoke-WebRequest -uri $url -OutFile $tgzFile

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

function SetVCVars()
{
	pushd "$ENV:ProgramFiles (x86)\Microsoft Visual Studio 11.0\VC\"
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

function PatchFromGitCommit($sourcePath, $destPath, $gitRef, $gerritUrl, $gerritRef)
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

        $patch = &git format-patch -1 --stdout $gitRef
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

function PatchRelease($project, $version, $gitRef, $gerritUrl, $gerritRef)
{
    $destPath = ".\dist\$project-$version"
    PatchFromGitCommit $project $destPath $gitRef $gerritUrl $gerritRef
}
