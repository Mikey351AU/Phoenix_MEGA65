# Shortcut for: .\build.ps1 -Board R6   (all other parameters of build.ps1 are passed through)
& (Join-Path $PSScriptRoot "build.ps1") -Board R6 @args
exit $LASTEXITCODE
