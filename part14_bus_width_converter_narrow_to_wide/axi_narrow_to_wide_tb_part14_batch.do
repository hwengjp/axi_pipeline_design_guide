# AXI4 Bus Width Converter Testbench - PART13 Complete Version
# This script compiles and runs the comprehensive testbench based on PART13

# Clean up previous simulation
if {[file exists "work"]} {
    vdel -all
}

# Create work library
vlib work

# Compile SystemVerilog files
vlog -sv axi_common_defs.svh
vlog -sv ../part10_axi_simple_single_port_ram/single_port_ram.v
vlog -sv ../part10_axi_simple_single_port_ram/axi_simple_single_port_ram.sv
vlog -sv axi_narrow_to_wide.sv
vlog -sv axi_narrow_to_wide_dut.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_protocol_verification_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_monitoring_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_write_channel_control_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_read_channel_control_module.sv
vlog -sv ../part13_axi4_testbench_byte_access_verification/axi_byte_verification_control_module.sv
vlog -sv axi_narrow_to_wide_tb_part14.sv

# Start simulation
vsim -c -do "run -all; quit" top_tb
