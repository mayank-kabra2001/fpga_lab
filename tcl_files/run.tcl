# FPGA Implementation of MYTH CORE

#
#STEP#0: define your customized top file and setting up the board
#

set fp [open "tmp.txt" r]
set content [read $fp]
close $fp
set lines [split $content \n]
set mode [lindex $lines 0]
set file_name [lindex $lines 1]
set clock_rate [lindex $lines 2]
set board_name [lindex $lines 3]



if { $mode == "1" } {
	set var1 [format {%0.3f} [expr {$clock_rate/1.0}]]
	set var2 [format {%0.3f} [expr {$clock_rate/2.0}]]
	set constr [open "./fpga_lab_requirements/${file_name}_fpga_lab_constr.xdc" a]

	set a {[get_ports clk]}
	set b {[get_clocks clk]}
	set c {[get_ports reset]}
	set d {[get_ports anode_active[*]]}
	set e {[get_ports out[*]]}
	#writing to the constraints file ... 
	puts $constr "create_clock -period ${var1} -name clk -waveform {0.000 ${var2}} $a"
	puts $constr "set_input_delay -clock $b -min -add_delay 0.000 $c"
	puts $constr "set_input_delay -clock $b -max -add_delay 0.000 $c"
	puts $constr "set_output_delay -clock $b -min -add_delay 0.000 $d"
	puts $constr "set_output_delay -clock $b -max -add_delay 0.000 $d"
	puts $constr "set_output_delay -clock $b -min -add_delay 0.000 $e"
	puts $constr "set_output_delay -clock $b -max -add_delay 0.000 $e"
	close $constr
	set cons ./fpga_lab_requirements/${file_name}_fpga_lab_constr.xdc

} else {
	set io_standard [lindex $lines 4]
	set myfile [open "${file_name}.v" r]
	set search_IO "assign PIPE_Constr_pin"
	set constr [open "./fpga_lab_requirements/my_${file_name}_constraints.xdc" w]
	while {[gets $myfile data] != -1} {
	    if {[string match *[string toupper $search_IO]* [string toupper $data]] } {
	    	#puts $data
			set p1 $data
			set p2 [lindex [split $p1 " "] 16]
			set pin [lindex [split $p2 "_"] 3]
			#puts $pin

			set s1 [lindex [split $p1 " "] 18]
			set signal [lindex [split $s1 "_"] 2]
			set s2 [lindex [split $s1 "_"] 3]
			set index [string trim $s2 "a0"]
			set signal_value $signal$index
			#puts $signal_value
			
			set x ""
			append x {[get_ports } "{${signal_value}}]"
			puts $constr "set_property PACKAGE_PIN ${pin} $x"
			puts $constr "set_property IOSTANDARD ${io_standard} $x"
	    }
	}

	set var1 [format {%0.3f} [expr {$clock_rate/1.0}]]
	set var2 [format {%0.3f} [expr {$clock_rate/2.0}]]

	set a {[get_ports clk]}
	set b {[get_clocks clk]}
	set c {[get_ports reset]}
	set d {[get_ports anode_active[*]]}
	set e {[get_ports out[*]]}
	#writing to the constraints file ... 
	puts $constr "create_clock -period ${var1} -name clk -waveform {0.000 ${var2}} $a"
	puts $constr "set_input_delay -clock $b -min -add_delay 0.000 $c"
	puts $constr "set_input_delay -clock $b -max -add_delay 0.000 $c"
	puts $constr "set_output_delay -clock $b -min -add_delay 0.000 $d"
	puts $constr "set_output_delay -clock $b -max -add_delay 0.000 $d"
	puts $constr "set_output_delay -clock $b -min -add_delay 0.000 $e"
	puts $constr "set_output_delay -clock $b -max -add_delay 0.000 $e"
	close $constr
	set cons ./fpga_lab_requirements/my_${file_name}_constraints.xdc

}



#
# STEP#1: define output directory area.
#
set outputDir FPGA_${file_name}
file mkdir $outputDir

#
# STEP#2: setup design sources and constraints
#
read_verilog -v ${file_name}.v
read_verilog ./fpga_lab_requirements/includes/clk_gate.v
read_verilog -sv ./fpga_lab_requirements/includes/pseudo_rand.sv
set_property include_dirs {./fpga_lab_requirements/includes ./} [current_fileset]
read_xdc $cons 
set fp [open $cons]
while {-1 != [gets $fp line]} {
    puts "The current line is '$line'."
}

#
# STEP#3: run synthesis, report utilization and timing estimates, write checkpoint design
#
synth_design -top counter -part $board_name -retiming
file mkdir $outputDir/syn/reports
write_checkpoint -force $outputDir/syn/post_synth
report_timing_summary -file $outputDir/syn/reports/post_synth_timing_summary.rpt
report_power -file $outputDir/syn/reports/post_synth_power.rpt

#
# STEP#4: run placement and logic optimzation, report utilization and timing estimates, write checkpoint design
#
opt_design -directive ExploreArea
place_design
phys_opt_design
file mkdir $outputDir/place
file mkdir $outputDir/place/reports
write_checkpoint -force $outputDir/place/post_place
report_timing_summary -file $outputDir/place/reports/post_place_timing_summary.rpt

#
# STEP#5: run router, report actual utilization and timing, write checkpoint design, run drc, write verilog and xdc out
#
route_design
file mkdir $outputDir/route
file mkdir $outputDir/route/reports
write_checkpoint -force $outputDir/route/post_route
report_timing_summary -file $outputDir/route/reports/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/route/reports/post_route_timing.rpt
report_clock_utilization -file $outputDir/route/reports/clock_util.rpt
report_utilization -file $outputDir/route/reports/post_route_util.rpt
report_power -file $outputDir/route/reports/post_route_power.rpt
report_drc -file $outputDir/route/reports/post_imp_drc.rpt
write_verilog -force $outputDir/fpga_impl_netlist.v
write_xdc -no_fixed_only -force $outputDir/fpga_impl.xdc

#
#STEP#7: Printing Summary
#
set met_timing "Met Timing Constrains: true"
set no_timing "Timing constraints given : true"
set no_timing_search "There are no user specified timing constraints."
set search "Timing constraints are not met."
set timing_report [open $outputDir/route/reports/post_route_timing_summary.rpt]
 while {[gets $timing_report data] != -1} {
    if {[string match *[string toupper $search]* [string toupper $data]] } {
		set met_timing "Met Timing Constrains: false"
		#set fid [open Vivado/out/status.txt w]
		#puts $fid "false" 
		#close $fid
		close $timing_report
		puts $met_timing
		puts "check your timing constraints and run the script again"
		puts "----------------EXITING -----------------"
		exit 
		#STEP 6 - write bitstream will not get performed  
    } elseif {[string match *[string toupper $no_timing_search]* [string toupper $data]] } {
		set no_timing "Timing constraints given : false"
		#set fid [open Vivado/out/status.txt w]
		#puts $fid "false" 
		#close $fid
		close $timing_report
		puts $no_timing
		puts "check your timing constraints and run the script again"
		puts "----------------EXITING -----------------"
		exit
		#STEP 6 - write bitstream will not get performed 
    } else {}
 }
close $timing_report
puts $met_timing
puts $no_timing

set search_util "Slice LUTs"
set util_report [open $outputDir/route/reports/post_route_util.rpt]
 while {[gets $util_report data] != -1} {
    if {[string match *[string toupper $search_util]* [string toupper $data]] } {
		set haha $data
    } else {
    }
 }
close $util_report
set theWords [regexp -all -inline {\S+} $haha]
puts $haha
puts [lindex $theWords 4]

#
# STEP#6: generate a bitstream
#
write_bitstream -force $outputDir/$file_name.bit

#
# STEP#7: connect to your board 
#
open_hw_manager
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]

set file_loc ./$outputDir/$file_name.bit
puts $file_loc
set test [exec pwd]
puts $test
set_property PROGRAM.FILE $file_loc [lindex [get_hw_devices] 0]
program_hw_device

exit


