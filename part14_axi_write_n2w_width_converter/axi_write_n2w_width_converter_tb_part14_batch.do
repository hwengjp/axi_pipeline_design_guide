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

# Part13 files (relative path)
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_stimulus_functions.svh
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_verification_functions.svh
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_utility_functions.svh
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_random_generation.svh
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_monitoring_functions.svh

# Part13 module files (required for testbench)
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_protocol_verification_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_monitoring_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_write_channel_control_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_read_channel_control_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_byte_verification_control_module.sv

# Testbench
vlog -sv axi_write_n2w_width_converter_tb_part14.sv

# Simulate
vsim -c -do "run -all; quit" top_tb
