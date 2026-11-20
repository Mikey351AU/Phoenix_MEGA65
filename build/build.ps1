# Builds Phoenix for one MEGA65 board revision and creates the .cor file.
# Needs: Vivado 2022.2 for Windows, WSL with Ubuntu, and setup_wsl.sh run once.
# Usage (PowerShell, in C:\phnx\Phoenix_MEGA65\build):   .\build.ps1 -Board R3
#   R3 = MEGA65 R3 and R3A, R6 = MEGA65 R6 (R4/R5 projects exist but are untested)
param(
   [Parameter(Mandatory = $true)][ValidateSet("R3", "R4", "R5", "R6")][string]$Board,
   [string]$Vivado  = "C:\Xilinx\Vivado\2022.2\bin\vivado.bat",
   [string]$Version = "V0.2",
   [int]   $Jobs    = [Math]::Max(1, [Environment]::ProcessorCount - 1),
   # bit2core from github.com/MEGA65/mega65-tools (copy in build\m65_bit2core): writes the current core
   # header (board model, size, CRC32) that the MEGA65 flash menu needs. Path as seen from WSL.
   [string]$MegaToolsBit2Core = "./build/m65_bit2core/bit2core",
   # Use the old QNICE bit2core instead (old header without model/CRC; not listed by current flash menus)
   [switch]$OldHeader
)
$ErrorActionPreference = "Stop"
$root   = Split-Path $PSScriptRoot -Parent
$b      = $Board.ToLower()               # r3, r6, ...
$target = "mega65$b"                     # bit2core target name, e.g. mega65r3
$name   = "phoenix_$b"                   # release file names, e.g. phoenix_r3.cor

if (-not (Test-Path $Vivado)) { throw "Vivado not found at $Vivado (use -Vivado <path to vivado.bat>)" }
if (-not (Test-Path "$root\M2M\QNICE\assembler\qasm")) { throw "QNICE toolchain missing: run 'wsl bash ./setup_wsl.sh' first" }

Push-Location $PSScriptRoot
try {
   & $Vivado -mode batch -nojournal -log "build_$b.log" -source build.tcl -tclargs $Board $Jobs
   if ($LASTEXITCODE -ne 0) { throw "Vivado build failed, see build\build_$b.log" }
} finally { Pop-Location }

$bit = Get-ChildItem "$root\CORE\CORE-$Board.runs\impl_1\*.bit" | Select-Object -First 1
if (-not $bit) { throw "no .bit file found in CORE\CORE-$Board.runs\impl_1" }
New-Item -ItemType Directory -Force "$root\release" | Out-Null
Copy-Item $bit.FullName "$root\release\$name.bit" -Force

Push-Location $root
try {
   if ($OldHeader) {
      Write-Warning "Using the QNICE bit2core (old core header without board model and CRC)."
      wsl.exe ./M2M/QNICE/tools/bit2core "release/$name.bit" "Phoenix" $Version "release/$name.cor"
   } else {
      if ($MegaToolsBit2Core -eq "./build/m65_bit2core/bit2core" -and -not (Test-Path "$root\build\m65_bit2core\bit2core")) {
         wsl.exe bash ./build/m65_bit2core/build.sh
         if ($LASTEXITCODE -ne 0) { throw "building mega65-tools bit2core failed" }
      }
      wsl.exe $MegaToolsBit2Core $target "release/$name.bit" "Phoenix" $Version "release/$name.cor"
   }
   if ($LASTEXITCODE -ne 0) { throw "bit2core failed" }
} finally { Pop-Location }

Get-Item "$root\release\$name.*" | Format-Table Name, Length
