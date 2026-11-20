# Cycle model of CORE/vhdl/rotate.vhd driven by a model of Phoenix's rtl/phoenix_video.vhd.
# Checks for both rotation directions that every rotated pixel comes from the right source pixel
# and that the output raster stays frame locked. Run in Windows PowerShell:  .\run_rotsim.ps1
# Keep the constants at the top of RotSim.Run() in sync with the generics of rotate.vhd.
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'RotSim.cs'))) -Language CSharp
[RotSim]::Run($false, 6)
[RotSim]::Run($true, 6)
