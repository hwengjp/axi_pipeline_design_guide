# ModelSim script for burst_read_pipeline_tb
# Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

# Create work library
vlib work

# Compile source files
vlog -sv burst_read_pipeline.v
vlog -sv burst_read_pipeline_tb.sv

# Start simulation
vsim -t ps work.burst_read_pipeline_tb

# Add waves
add wave -position insertpoint  \
sim:/burst_read_pipeline_tb/clk \
sim:/burst_read_pipeline_tb/rst_n \
sim:/burst_read_pipeline_tb/test_addr \
sim:/burst_read_pipeline_tb/test_length \
sim:/burst_read_pipeline_tb/test_valid \
sim:/burst_read_pipeline_tb/test_ready \
sim:/burst_read_pipeline_tb/dut_data \
sim:/burst_read_pipeline_tb/dut_valid \
sim:/burst_read_pipeline_tb/dut_last \
sim:/burst_read_pipeline_tb/dut_ready \
sim:/burst_read_pipeline_tb/test_count \
sim:/burst_read_pipeline_tb/burst_count \
sim:/burst_read_pipeline_tb/data_count



# Configure wave display
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# Set bus signals to HEX display
#configure wave -radix hex sim:/burst_read_pipeline_tb/test_addr
#configure wave -radix hex sim:/burst_read_pipeline_tb/test_length
#configure wave -radix hex sim:/burst_read_pipeline_tb/dut_data

# Run simulation
run -all

# Display completion message
echo "Simulation completed. Check the transcript for results."