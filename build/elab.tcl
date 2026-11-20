# Quick check: syntax check + RTL elaboration of one board revision (no synthesis/implementation)
# Usage: vivado -mode batch -source elab.tcl -tclargs <R3|R4|R5|R6>
set board [string toupper [lindex $argv 0]]
set top   "mega65_[string tolower $board]"
set here  [file dirname [file normalize [info script]]]
open_project [file join $here .. CORE CORE-$board.xpr]
update_compile_order -fileset sources_1
check_syntax -fileset sources_1
synth_design -rtl -top $top -part xc7a200tfbg484-2 -name rtl_1
puts "ELABORATION OK"
exit 0
