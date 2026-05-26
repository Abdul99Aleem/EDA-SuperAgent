# Vivado Batch Mode Simulation Script
# Usage: vivado -mode batch -source tools/run_vivado.tcl -tclargs <rtl_file> <testbench_file>

set rtl_file [lindex $argv 0]
set tb_file [lindex $argv 1]
set timestamp [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set outdir "outputs/reports"
set outfile "${outdir}/sim_${timestamp}.txt"

# Create output directory
file mkdir $outdir

# Open log file
set log_fh [open $outfile w]
puts $log_fh "=== VLSI Super Agent Simulation ==="
puts $log_fh "RTL: $rtl_file"
puts $log_fh "Testbench: $tb_file"
puts $log_fh "Timestamp: $timestamp"
puts $log_fh ""

# Create temporary work directory
set work_dir "/tmp/xsim_work_${timestamp}"
file mkdir $work_dir
cd $work_dir

# Compile RTL and testbench
puts $log_fh "=== Compilation Phase ==="
if {[catch {
    exec xvlog $rtl_file $tb_file 2>@1
} compile_output]} {
    puts $log_fh $compile_output
    puts $log_fh ""
    puts $log_fh "STATUS: COMPILE_ERROR"
    close $log_fh
    puts "Compilation failed. Check $outfile"
    exit 1
} else {
    puts $log_fh $compile_output
    puts $log_fh "Compilation successful"
}

# Elaborate design (find top module from testbench)
puts $log_fh ""
puts $log_fh "=== Elaboration Phase ==="
set tb_module [file rootname [file tail $tb_file]]
if {[catch {
    exec xelab $tb_module -debug typical -s sim_snapshot 2>@1
} elab_output]} {
    puts $log_fh $elab_output
    puts $log_fh ""
    puts $log_fh "STATUS: ELABORATION_ERROR"
    close $log_fh
    puts "Elaboration failed. Check $outfile"
    exit 1
} else {
    puts $log_fh $elab_output
    puts $log_fh "Elaboration successful"
}

# Run simulation
puts $log_fh ""
puts $log_fh "=== Simulation Phase ==="
if {[catch {
    exec xsim sim_snapshot -runall -log xsim.log 2>@1
} sim_output]} {
    puts $log_fh $sim_output
    # Check if it's a timeout or actual error
    if {[string match "*timeout*" $sim_output]} {
        puts $log_fh ""
        puts $log_fh "STATUS: TIMEOUT"
    } else {
        puts $log_fh ""
        puts $log_fh "STATUS: RUNTIME_FAIL"
    }
    close $log_fh
    puts "Simulation failed. Check $outfile"
    exit 1
} else {
    puts $log_fh $sim_output
}

# Read xsim.log and check for PASS/FAIL
if {[file exists xsim.log]} {
    set sim_log [open xsim.log r]
    set sim_content [read $sim_log]
    close $sim_log
    puts $log_fh ""
    puts $log_fh "=== Simulation Output ==="
    puts $log_fh $sim_content

    # Determine status
    if {[string match "*PASS*" $sim_content]} {
        puts $log_fh ""
        puts $log_fh "STATUS: PASS"
        close $log_fh
        puts "Simulation PASSED. Report: $outfile"
        exit 0
    } elseif {[string match "*FAIL*" $sim_content] || [string match "*Error*" $sim_content]} {
        puts $log_fh ""
        puts $log_fh "STATUS: RUNTIME_FAIL"
        close $log_fh
        puts "Simulation FAILED. Report: $outfile"
        exit 1
    } else {
        puts $log_fh ""
        puts $log_fh "STATUS: UNKNOWN"
        close $log_fh
        puts "Simulation completed with unknown status. Report: $outfile"
        exit 0
    }
}

close $log_fh
puts "Report saved to: $outfile"
