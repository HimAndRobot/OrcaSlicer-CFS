# Build Windows Local

Branch alvo atual:

- `v2.3.2`

## 1. Preparar ambiente no PowerShell

```powershell
cmd /c '"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 && set' |
ForEach-Object {
  if ($_ -match '^(.*?)=(.*)$') {
    Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
  }
}

$env:PATH = "C:\Program Files\CMake\bin;C:\Strawberry\perl\bin;$env:PATH"
```

## 2. Build das dependências

Rode esta parte se ainda não tiver `deps/build` pronto para essa árvore:

```powershell
Set-Location "C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\deps"
if (!(Test-Path build)) { New-Item -ItemType Directory -Path build | Out-Null }
Set-Location build
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" `
  deps.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo
```

## 3. Build principal

```powershell
Set-Location "C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer"
if (!(Test-Path build)) { New-Item -ItemType Directory -Path build | Out-Null }
Set-Location build
cmake .. -G "Visual Studio 17 2022" -A x64 -DORCA_TOOLS=ON -DCMAKE_BUILD_TYPE=Release
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" `
  ALL_BUILD.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" `
  INSTALL.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo
```

## 4. Arquivos gerados

Saídas esperadas:

- `C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\build\src\Release\orca-slicer.exe`
- `C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\build\src\Release\OrcaSlicer.dll`
- `C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\build\src\Release\OrcaSlicer_profile_validator.exe`

Para listar o conteúdo final:

```powershell
Get-ChildItem "C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\build\src\Release" | Select-Object Name,Length
```

## 5. Logs rápidos

Se der erro no build principal:

```powershell
Get-Content "C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\build\slicer-msbuild.log" -Tail 120
```

Se quiser gerar log detalhado do build principal:

```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" `
  ALL_BUILD.vcxproj /t:Build /p:Configuration=Release /m:1 /v:minimal /nologo /fl "/flp:logfile=slicer-msbuild.log;verbosity=diagnostic"
```
