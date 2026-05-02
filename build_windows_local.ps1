$ErrorActionPreference = 'Stop'

$repo = "C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer"
$msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
$vsdevcmd = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
$branch = (git -C $repo rev-parse --abbrev-ref HEAD).Trim()
$safeBranch = ($branch -replace '[^A-Za-z0-9._-]', '_')
$buildDir = Join-Path $repo ("build-" + $safeBranch)
$depsBuildDir = Join-Path $repo ("deps\\build-" + $safeBranch)

function Assert-LastExitCode {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandText
    )

    if ($LASTEXITCODE -ne 0) {
        throw ("Command failed with exit code {0}: {1}" -f $LASTEXITCODE, $CommandText)
    }
}

Write-Host "Preparing Visual Studio environment..."
cmd /c "`"$vsdevcmd`" -arch=x64 -host_arch=x64 && set" |
ForEach-Object {
    if ($_ -match '^(.*?)=(.*)$') {
        Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
    }
}

$env:PATH = "C:\Program Files\CMake\bin;C:\Strawberry\perl\bin;$env:PATH"

Write-Host "Building dependencies..."
Set-Location "$repo\deps"
if (!(Test-Path $depsBuildDir)) {
    New-Item -ItemType Directory -Path $depsBuildDir | Out-Null
}
Set-Location $depsBuildDir
& cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release
Assert-LastExitCode "cmake .. -G `"Visual Studio 17 2022`" -A x64 -DCMAKE_BUILD_TYPE=Release"
& $msbuild deps.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo
Assert-LastExitCode "msbuild deps.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo"

Write-Host "Building OrcaSlicer..."
Set-Location $repo
if (!(Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}
Set-Location $buildDir
& cmake .. -G "Visual Studio 17 2022" -A x64 -DORCA_TOOLS=ON -DCMAKE_BUILD_TYPE=Release
Assert-LastExitCode "cmake .. -G `"Visual Studio 17 2022`" -A x64 -DORCA_TOOLS=ON -DCMAKE_BUILD_TYPE=Release"
& $msbuild ALL_BUILD.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo
Assert-LastExitCode "msbuild ALL_BUILD.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo"
& $msbuild INSTALL.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo
Assert-LastExitCode "msbuild INSTALL.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo"

Write-Host ""
Write-Host "Build finished for branch: $branch"
Write-Host "Build directory: $buildDir"
Write-Host "Deps directory: $depsBuildDir"
Write-Host "Output files:"
Get-ChildItem "$buildDir\src\Release" | Select-Object Name, Length
