# ModelSim Batch Script for AXI Simple Dual Port RAM Testbench
# This script compiles and runs the testbench in batch mode (no GUI)

# Create work library if it doesn't exist
if {[file exists work] == 0} {
    vlib work
}

echo "=== Compiling AXI Simple Dual Port RAM Testbench ==="

# Compile the dual port RAM module first
vlog -work work dual_port_ram.v
echo "dual_port_ram.v compilation completed"

# Compile the DUT (Device Under Test) - Verilog file
vlog -work work axi_simple_dual_port_ram.sv
echo "axi_simple_dual_port_ram.sv compilation completed"



# Compile the testbench - SystemVerilog file
vlog -work work axi_simple_dual_port_ram_tb.sv
echo "axi_simple_dual_port_ram_tb.sv compilation completed"

echo "=== Compilation completed successfully ==="

# Start simulation with the testbench module
vsim -c -t ps -voptargs=+acc work.axi_simple_dual_port_ram_tb

echo "=== Starting simulation ==="

# Set time resolution to 1ps
set time_resolution 1ps

# Run simulation with a timeout to avoid infinite loop
set MAX_SIM_TIME 10ms
run $MAX_SIM_TIME

echo "=== Simulation completed ==="
echo "Simulation time: $now"
echo "If the test finishes earlier, it will call \$finish automatically."

# Exit simulation
quit -f
