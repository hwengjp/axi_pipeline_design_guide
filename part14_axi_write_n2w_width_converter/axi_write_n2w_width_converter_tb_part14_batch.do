# Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
# AXI4 Write N2W Width Converter Testbench - Part14 Batch Script
# This script compiles and runs the testbench for the AXI4 Write N2W Width Converter

# Create work library
vlib work

# Compile SystemVerilog files
# Local files
vlog -sv axi_common_defs.svh
vlog -sv dual_width_dual_port_ram.v
vlog -sv axi_write_n2w_width_converter.sv
vlog -sv axi_dual_width_dual_port_ram.sv
vlog -sv axi_write_n2w_width_converter_dut.sv

# Local testbench files (copied from part13)
vlog -sv axi_stimulus_functions.svh
vlog -sv axi_verification_functions.svh
vlog -sv axi_utility_functions.svh
vlog -sv axi_random_generation.svh
vlog -sv axi_monitoring_functions.svh

# Local module files (copied from part13)
vlog -sv axi_protocol_verification_module.sv
vlog -sv axi_monitoring_module.sv
vlog -sv axi_write_channel_control_module.sv
vlog -sv axi_read_channel_control_module.sv
vlog -sv axi_byte_verification_control_module.sv

# Testbench
vlog -sv axi_write_n2w_width_converter_tb_part14.sv

# Simulate
vsim -c -do "run -all; quit" top_tb
