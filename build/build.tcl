# Vivado batch build for one MEGA65 board revision: synthesis, implementation, bitstream
# Usage: vivado -mode batch -source build.tcl -tclargs <R3|R4|R5|R6> [jobs]
set board [string toupper [lindex $argv 0]]
set jobs 4
if {[llength $argv] > 1} { set jobs [lindex $argv 1] }

set here [file dirname [file normalize [info script]]]
open_project [file join $here .. CORE CORE-$board.xpr]

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
puts "impl_1 status: $status"
if {![string match "*write_bitstream Complete*" $status]} {
   puts "ERROR: bitstream was not generated"
   exit 1
}

# timing summary (worst negative slack must be >= 0)
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "Worst setup slack (WNS): $wns ns"
exit 0
