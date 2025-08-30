# ModelSim script for burst_rw_pipeline_tb
# This script sets up the simulation environment and runs the testbench

# Create work library
vlib work

# Compile Verilog files
vlog -work work burst_rw_pipeline.v
vlog -work work burst_rw_pipeline_tb.sv

# Start simulation
vsim -t ps work.burst_rw_pipeline_tb

# Add waves with HEX display for bus signals
# Clock and Reset
add wave -noupdate -radix binary /burst_rw_pipeline_tb/clk
add wave -noupdate -radix binary /burst_rw_pipeline_tb/rst_n

# Read Interface - Test Pattern Generator
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/test_r_addr
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/test_r_length
add wave -noupdate -radix binary /burst_rw_pipeline_tb/test_r_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/test_r_ready

# Write Address Interface - Test Pattern Generator
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/test_w_addr
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/test_w_length
add wave -noupdate -radix binary /burst_rw_pipeline_tb/test_w_addr_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/test_w_addr_ready

# Write Data Interface - Test Pattern Generator
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/test_w_data
add wave -noupdate -radix binary /burst_rw_pipeline_tb/test_w_data_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/test_w_data_ready

# Read Interface - DUT Output
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut_r_data
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut_r_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut_r_last
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut_r_ready

# Write Interface - DUT Output
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut_b_response
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut_b_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut_b_ready

# Test Control Signals
add wave -noupdate -radix binary /burst_rw_pipeline_tb/final_r_ready
add wave -noupdate -radix binary /burst_rw_pipeline_tb/final_b_ready

# Test Counters
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/test_count
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/r_burst_count
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/w_burst_count
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/r_data_count
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/b_response_count

# Stall Control - Read
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/r_stall_counter
add wave -noupdate -radix binary /burst_rw_pipeline_tb/r_stall_active
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/r_current_stall_cycles

# Stall Control - Write
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/w_stall_counter
add wave -noupdate -radix binary /burst_rw_pipeline_tb/w_stall_active
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/w_current_stall_cycles

# Array Indices
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/r_array_index
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/w_addr_array_index
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/w_data_array_index

# Burst Tracking
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/r_burst_data_count
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/w_burst_response_count
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/r_burst_queue_index
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/w_burst_queue_index

# DUT Internal Signals - Read Pipeline
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/r_t0_mem_addr
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/r_t0_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/r_t0_last
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/dut/r_t0_count

add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/r_t1_addr
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/r_t1_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/r_t1_last

add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/r_t2_data
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/r_t2_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/r_t2_last

# DUT Internal Signals - Write Pipeline
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/w_t0a_mem_addr
add wave -noupdate -radix decimal /burst_rw_pipeline_tb/dut/w_t0a_count
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t0a_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t0a_last

add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/w_t0d_data
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t0d_valid

add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/w_t1_addr
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/w_t1_data
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t1_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t1_last

add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/w_t2_addr
add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/w_t2_data
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t2_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t2_last

add wave -noupdate -radix hexadecimal /burst_rw_pipeline_tb/dut/w_t3_response
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t3_valid
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/w_t3_last

# DUT Internal Signals - State Management
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/t1_current_state

# DUT Internal Signals - Arbitration
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/t1_r_ready
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/t1_w_ready

# DUT Internal Signals - Downstream Ready
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/d_r_ready
add wave -noupdate -radix binary /burst_rw_pipeline_tb/dut/d_b_ready

# Configure wave display
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# Run simulation
run -all

# Zoom to fit
wave zoom full
