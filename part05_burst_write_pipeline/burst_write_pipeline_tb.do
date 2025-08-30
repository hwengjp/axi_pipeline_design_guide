# ModelSim script for burst_write_pipeline_tb
# Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

# Create work library
vlib work

# Compile source files
vlog -sv burst_write_pipeline.v
vlog -sv burst_write_pipeline_tb.sv

# Start simulation
vsim -t ps work.burst_write_pipeline_tb

# Add waves
add wave -position insertpoint  \
sim:/burst_write_pipeline_tb/clk \
sim:/burst_write_pipeline_tb/rst_n \
sim:/burst_write_pipeline_tb/test_addr \
sim:/burst_write_pipeline_tb/test_length \
sim:/burst_write_pipeline_tb/test_addr_valid \
sim:/burst_write_pipeline_tb/test_addr_ready \
sim:/burst_write_pipeline_tb/test_data \
sim:/burst_write_pipeline_tb/test_data_valid \
sim:/burst_write_pipeline_tb/test_data_ready \
sim:/burst_write_pipeline_tb/dut_response \
sim:/burst_write_pipeline_tb/dut_valid \
sim:/burst_write_pipeline_tb/dut_ready \
sim:/burst_write_pipeline_tb/test_count \
sim:/burst_write_pipeline_tb/burst_count \
sim:/burst_write_pipeline_tb/response_count \
sim:/burst_write_pipeline_tb/valid_address_count \
sim:/burst_write_pipeline_tb/valid_data_count \
sim:/burst_write_pipeline_tb/bubble_count \
sim:/burst_write_pipeline_tb/current_burst_addr \
sim:/burst_write_pipeline_tb/current_burst_length \
sim:/burst_write_pipeline_tb/burst_response_count \
sim:/burst_write_pipeline_tb/array_index \
sim:/burst_write_pipeline_tb/array_size \
sim:/burst_write_pipeline_tb/expected_response_index \
sim:/burst_write_pipeline_tb/stall_index \
sim:/burst_write_pipeline_tb/final_ready

# Configure wave display
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# Note: To set signals to HEX display, use the GUI or add manually:
# Right-click on signal in wave window -> Properties -> Radix -> Hexadecimal

# Run simulation
run -all

# Display completion message
echo "Simulation completed. Check the transcript for results." 