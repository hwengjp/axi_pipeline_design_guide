# ModelSim script for pipeline_tb
# Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

# Create work library
vlib work

# Compile source files (using relative paths from part03 folder)
vlog -work work ../part01_pipeline_principles/pipeline.v
vlog -work work ../part02_pipeline_insert/pipeline_insert.v
vlog -work work pipeline_tb.sv

# Start simulation
vsim -t ps work.pipeline_tb

# Add waves
add wave -radix decimal /pipeline_tb/clk
add wave -radix decimal /pipeline_tb/rst_n

# Test pattern generator signals
add wave -radix decimal /pipeline_tb/test_data
add wave -radix binary /pipeline_tb/test_valid
add wave -radix binary /pipeline_tb/test_ready

# DUT signals
add wave -radix decimal /pipeline_tb/dut_data
add wave -radix binary /pipeline_tb/dut_valid
add wave -radix binary /pipeline_tb/dut_ready

# Result checker signals
add wave -radix decimal /pipeline_tb/result_data
add wave -radix binary /pipeline_tb/result_valid
add wave -radix binary /pipeline_tb/result_ready

# Final output signals
add wave -radix decimal /pipeline_tb/final_data
add wave -radix binary /pipeline_tb/final_valid
add wave -radix binary /pipeline_tb/final_ready

# Test control signals
add wave -radix decimal /pipeline_tb/test_count

# Sequence checker signals
add wave -radix decimal /pipeline_tb/prev_test_data
add wave -radix binary /pipeline_tb/prev_test_valid
add wave -radix decimal /pipeline_tb/prev_result_data
add wave -radix binary /pipeline_tb/prev_result_valid

# Additional useful signals
add wave -radix decimal /pipeline_tb/bubble_cycles
add wave -radix decimal /pipeline_tb/stall_cycles
add wave -radix decimal /pipeline_tb/array_index
add wave -radix decimal /pipeline_tb/expected_data_index

# Run simulation
run -all

# Display final results
echo "Simulation completed. Check the transcript for results."