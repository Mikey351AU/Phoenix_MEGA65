set cur_dir [pwd]
# ../../CORE/CORE-R6.runs/synth_1/

cd ../../../CORE/m2m-rom/
if {$::tcl_platform(platform) eq "windows"} {
   # Vivado for Windows: run the bash script inside WSL (wsl.exe starts in the matching /mnt/c/... folder)
   exec wsl.exe bash ./make_rom.sh >@stdout 2>@stderr
} else {
   exec ./make_rom.sh <@stdin >@stdout 2>@stderr
}
cd $cur_dir

