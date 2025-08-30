# ModelSim Batch Script for AXI Simple Single Port RAM Testbench
# This script compiles and runs the single port RAM testbench in batch mode (no GUI)

# Create work library if it doesn't exist
if {[file exists work] == 0} {
    vlib work
}

echo "=== Compiling AXI Simple Single Port RAM Testbench ==="

# Compile the single port RAM module first
vlog -work work single_port_ram.v
echo "single_port_ram.v compilation completed"

# Compile the DUT (Device Under Test) - Verilog file
vlog -work work axi_simple_single_port_ram.sv
echo "axi_simple_single_port_ram.sv compilation completed"

# Compile header files in dependency order
echo "=== Compiling Header Files ==="

# 1. Common definitions (no dependencies)
vlog -work work ../part11_axi4_testbench_refactoring/axi_common_defs.svh
echo "axi_common_defs.svh compilation completed"

# 2. Utility functions (depends on common definitions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_utility_functions.svh
echo "axi_utility_functions.svh compilation completed"

# 3. Random generation functions (depends on common definitions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_random_generation.svh
echo "axi_random_generation.svh compilation completed"

# 4. Stimulus functions (depends on common definitions, utility functions, and random generation)
vlog -work work ../part11_axi4_testbench_refactoring/axi_stimulus_functions.svh
echo "axi_stimulus_functions.svh compilation completed"

# 5. Verification functions (depends on common definitions and utility functions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_verification_functions.svh
echo "axi_verification_functions.svh compilation completed"

# 6. Monitoring functions (depends on common definitions and utility functions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_monitoring_functions.svh
echo "axi_monitoring_functions.svh compilation completed"

# 7. Protocol verification module (depends on common definitions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_protocol_verification_module.sv
echo "axi_protocol_verification_module.sv compilation completed"

# 8. Monitoring module (depends on common definitions and utility functions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_monitoring_module.sv
echo "axi_monitoring_module.sv compilation completed"

# 9. Write channel control module (depends on common definitions and utility functions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_write_channel_control_module.sv
echo "axi_write_channel_control_module.sv compilation completed"

# 10. Read channel control module (depends on common definitions and utility functions)
vlog -work work ../part11_axi4_testbench_refactoring/axi_read_channel_control_module.sv
echo "axi_read_channel_control_module.sv compilation completed"

# 11. Main testbench (depends on all header files and modules)
vlog -work work axi_simple_single_port_ram_tb.sv
echo "axi_simple_single_port_ram_tb.sv compilation completed"

echo "=== Compilation completed successfully ==="

# Start simulation with the testbench module
vsim -c -t ps -voptargs=+acc work.top_tb

# Set time resolution to 1ps
set time_resolution 1ps

# Run simulation with a timeout to avoid infinite loop
set MAX_SIM_TIME 10ms
run $MAX_SIM_TIME

# Exit simulation
quit -f
