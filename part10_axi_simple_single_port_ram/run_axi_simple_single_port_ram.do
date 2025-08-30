# =============================================================================
# ModelSim/QuestaSim Do File for AXI Simple Single Port RAM Testbench
# =============================================================================
# This script compiles and runs the simulation for the single port RAM design
# with conflict control testing

# =============================================================================
# Library and Work Setup
# =============================================================================
# Create work library if it doesn't exist
if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

# =============================================================================
# Compilation
# =============================================================================
echo "Compiling AXI Simple Single Port RAM design files..."

# Compile part09 modules first (dependencies)
echo "Compiling part09 dependency modules..."
vlog -work work ../part09_axi4_testbench_refactoring/axi_protocol_verification_module.sv
vlog -work work ../part09_axi4_testbench_refactoring/axi_monitoring_module.sv
vlog -work work ../part09_axi4_testbench_refactoring/axi_write_channel_control_module.sv
vlog -work work ../part09_axi4_testbench_refactoring/axi_read_channel_control_module.sv

# Compile the single port RAM module
echo "Compiling single port RAM module..."
vlog -work work single_port_ram.v

# Compile the main design file
echo "Compiling main design file..."
vlog -work work axi_simple_single_port_ram.sv

# Compile the testbench
echo "Compiling testbench..."
vlog -work work axi_simple_single_port_ram_tb.sv

echo "Compilation completed successfully."

# =============================================================================
# Simulation Setup
# =============================================================================
echo "Setting up simulation..."

# Load the testbench
vsim -t ps work.top_tb

# Add waves for all signals
add wave -divider "Clock and Reset"
add wave -position insertpoint sim:/top_tb/clk
add wave -position insertpoint sim:/top_tb/rst_n

add wave -divider "Write Address Channel (AW)"
add wave -position insertpoint sim:/top_tb/axi_aw_addr
add wave -position insertpoint sim:/top_tb/axi_aw_burst
add wave -position insertpoint sim:/top_tb/axi_aw_size
add wave -position insertpoint sim:/top_tb/axi_aw_id
add wave -position insertpoint sim:/top_tb/axi_aw_len
add wave -position insertpoint sim:/top_tb/axi_aw_valid
add wave -position insertpoint sim:/top_tb/axi_aw_ready

add wave -divider "Write Data Channel (W)"
add wave -position insertpoint sim:/top_tb/axi_w_data
add wave -position insertpoint sim:/top_tb/axi_w_strb
add wave -position insertpoint sim:/top_tb/axi_w_last
add wave -position insertpoint sim:/top_tb/axi_w_valid
add wave -position insertpoint sim:/top_tb/axi_w_ready

add wave -divider "Write Response Channel (B)"
add wave -position insertpoint sim:/top_tb/axi_b_resp
add wave -position insertpoint sim:/top_tb/axi_b_id
add wave -position insertpoint sim:/top_tb/axi_b_valid
add wave -position insertpoint sim:/top_tb/axi_b_ready

add wave -divider "Read Address Channel (AR)"
add wave -position insertpoint sim:/top_tb/axi_ar_addr
add wave -position insertpoint sim:/top_tb/axi_ar_burst
add wave -position insertpoint sim:/top_tb/axi_ar_size
add wave -position insertpoint sim:/top_tb/axi_ar_id
add wave -position insertpoint sim:/top_tb/axi_ar_len
add wave -position insertpoint sim:/top_tb/axi_ar_valid
add wave -position insertpoint sim:/top_tb/axi_ar_ready

add wave -divider "Read Data Channel (R)"
add wave -position insertpoint sim:/top_tb/axi_r_data
add wave -position insertpoint sim:/top_tb/axi_r_id
add wave -position insertpoint sim:/top_tb/axi_r_resp
add wave -position insertpoint sim:/top_tb/axi_r_last
add wave -position insertpoint sim:/top_tb/axi_r_valid
add wave -position insertpoint sim:/top_tb/axi_r_ready

add wave -divider "DUT Internal Signals - Read Pipeline"
add wave -position insertpoint sim:/top_tb/dut/r_t0_addr
add wave -position insertpoint sim:/top_tb/dut/r_t0_valid
add wave -position insertpoint sim:/top_tb/dut/r_t0_count
add wave -position insertpoint sim:/top_tb/dut/r_t1_addr
add wave -position insertpoint sim:/top_tb/dut/r_t1_valid
add wave -position insertpoint sim:/top_tb/dut/t1_r_ready

add wave -divider "DUT Internal Signals - Write Pipeline"
add wave -position insertpoint sim:/top_tb/dut/w_t0a_addr
add wave -position insertpoint sim:/top_tb/dut/w_t0a_valid
add wave -position insertpoint sim:/top_tb/dut/w_t0d_data
add wave -position insertpoint sim:/top_tb/dut/w_t0d_valid
add wave -position insertpoint sim:/top_tb/dut/w_t1_addr
add wave -position insertpoint sim:/top_tb/dut/w_t1_data
add wave -position insertpoint sim:/top_tb/dut/w_t1_valid
add wave -position insertpoint sim:/top_tb/dut/t1_w_ready

add wave -divider "Test Control"
add wave -position insertpoint sim:/top_tb/current_phase
add wave -position insertpoint sim:/top_tb/test_execution_completed

# =============================================================================
# Run Simulation
# =============================================================================
echo "Starting simulation..."

# Run the simulation
run -all

# =============================================================================
# Simulation Results
# =============================================================================
echo "Simulation completed."
echo "Check the transcript for test results and any error messages."

# Keep the simulation running to view results
# run 1000ns
