# AXI Simple Single Port RAM Testbench - Part13 Version
# This script compiles and simulates the AXI4 simple single port RAM testbench
# with enhanced strobe control parameters

# =============================================================================
# Environment Setup
# =============================================================================
# Set working directory to script location
cd [file dirname [info script]]

# =============================================================================
# Library Setup
# =============================================================================
# Create work library
vlib work

# Map work library
vmap work

# =============================================================================
# Compilation
# =============================================================================
echo "=== Compiling AXI Simple Single Port RAM Testbench (Part13) ==="

# Compile common definitions
echo "Compiling axi_common_defs.svh..."
vlog -sv axi_common_defs.svh

# Compile utility functions
echo "Compiling axi_utility_functions.svh..."
vlog -sv axi_utility_functions.svh

# Compile verification functions
echo "Compiling axi_verification_functions.svh..."
vlog -sv axi_verification_functions.svh

# Compile stimulus functions
echo "Compiling axi_stimulus_functions.svh..."
vlog -sv axi_stimulus_functions.svh

# Compile random generation functions
echo "Compiling axi_random_generation.svh..."
vlog -sv axi_random_generation.svh

# Compile monitoring functions
echo "Compiling axi_monitoring_functions.svh..."
vlog -sv axi_monitoring_functions.svh

# Compile protocol verification module
echo "Compiling axi_protocol_verification_module.sv..."
vlog -sv axi_protocol_verification_module.sv

# Compile monitoring module
echo "Compiling axi_monitoring_module.sv..."
vlog -sv axi_monitoring_module.sv

# Compile write channel control module
echo "Compiling axi_write_channel_control_module.sv..."
vlog -sv axi_write_channel_control_module.sv

# Compile read channel control module
echo "Compiling axi_read_channel_control_module.sv..."
vlog -sv axi_read_channel_control_module.sv

# Compile byte verification control module
echo "Compiling axi_byte_verification_control_module.sv..."
vlog -sv axi_byte_verification_control_module.sv

# Compile single port RAM module
echo "Compiling single_port_ram.v..."
vlog -sv ../part10_axi_simple_single_port_ram/single_port_ram.v

# Compile AXI simple single port RAM module
echo "Compiling axi_simple_single_port_ram.sv..."
vlog -sv ../part10_axi_simple_single_port_ram/axi_simple_single_port_ram.sv

# Compile testbench
echo "Compiling axi_simple_single_port_ram_tb_part13.sv..."
vlog -sv axi_simple_single_port_ram_tb_part13.sv

# =============================================================================
# Simulation
# =============================================================================
echo "=== Starting Simulation ==="

# Start simulation with top module
vsim -c -do "run -all; quit" top_tb

# =============================================================================
# Completion
# =============================================================================
echo "=== Part13 AXI Simple Single Port RAM Testbench Simulation Complete ==="
echo "Check the transcript for results and any error messages."
