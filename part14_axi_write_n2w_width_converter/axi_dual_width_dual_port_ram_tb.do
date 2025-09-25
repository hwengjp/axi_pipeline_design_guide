# Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
# AXI4 Dual Width Dual Port RAM Testbench - Part14 Version
# This do file compiles and simulates the AXI4 Dual Width Dual Port RAM testbench
# It uses the same modular architecture as the AXI Write N2W Width Converter testbench

# Create work library
vlib work

# Compile common include files
vlog -work work axi_common_defs.svh
vlog -work work axi_stimulus_functions.svh
vlog -work work axi_verification_functions.svh
vlog -work work axi_utility_functions.svh
vlog -work work axi_random_generation.svh
vlog -work work axi_monitoring_functions.svh

# Compile modular testbench components
vlog -work work axi_protocol_verification_module.sv
vlog -work work axi_monitoring_module.sv
vlog -work work axi_write_channel_control_module.sv
vlog -work work axi_read_channel_control_module.sv
vlog -work work axi_byte_verification_control_module.sv

# Compile DUT
vlog -work work axi_dual_width_dual_port_ram.sv

# Compile testbench
vlog -work work axi_dual_width_dual_port_ram_tb.sv

# Simulate
vsim -t ps work.top_tb

# Add signals to wave viewer
add wave -divider "Clock and Reset"
add wave -position insertpoint sim:/top_tb/clk
add wave -position insertpoint sim:/top_tb/rst_n

add wave -divider "Write Address Channel"
add wave -position insertpoint sim:/top_tb/axi_aw_addr
add wave -position insertpoint sim:/top_tb/axi_aw_burst
add wave -position insertpoint sim:/top_tb/axi_aw_size
add wave -position insertpoint sim:/top_tb/axi_aw_id
add wave -position insertpoint sim:/top_tb/axi_aw_len
add wave -position insertpoint sim:/top_tb/axi_aw_valid
add wave -position insertpoint sim:/top_tb/axi_aw_ready

add wave -divider "Write Data Channel"
add wave -position insertpoint sim:/top_tb/axi_w_data
add wave -position insertpoint sim:/top_tb/axi_w_strb
add wave -position insertpoint sim:/top_tb/axi_w_last
add wave -position insertpoint sim:/top_tb/axi_w_valid
add wave -position insertpoint sim:/top_tb/axi_w_ready

add wave -divider "Write Response Channel"
add wave -position insertpoint sim:/top_tb/axi_b_resp
add wave -position insertpoint sim:/top_tb/axi_b_id
add wave -position insertpoint sim:/top_tb/axi_b_valid
add wave -position insertpoint sim:/top_tb/axi_b_ready

add wave -divider "Read Address Channel"
add wave -position insertpoint sim:/top_tb/axi_ar_addr
add wave -position insertpoint sim:/top_tb/axi_ar_burst
add wave -position insertpoint sim:/top_tb/axi_ar_size
add wave -position insertpoint sim:/top_tb/axi_ar_id
add wave -position insertpoint sim:/top_tb/axi_ar_len
add wave -position insertpoint sim:/top_tb/axi_ar_valid
add wave -position insertpoint sim:/top_tb/axi_ar_ready

add wave -divider "Read Data Channel"
add wave -position insertpoint sim:/top_tb/axi_r_data
add wave -position insertpoint sim:/top_tb/axi_r_id
add wave -position insertpoint sim:/top_tb/axi_r_resp
add wave -position insertpoint sim:/top_tb/axi_r_last
add wave -position insertpoint sim:/top_tb/axi_r_valid
add wave -position insertpoint sim:/top_tb/axi_r_ready

add wave -divider "DUT Internal Signals"
add wave -position insertpoint sim:/top_tb/dut/*

# Run simulation
run -all

# Display test results
echo "Test completed. Check the transcript for results."
