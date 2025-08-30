# ModelSim Script for AXI Simple Dual Port RAM Testbench
# This script compiles and runs the testbench

# Create work library if it doesn't exist
if {[file exists work] == 0} {
    vlib work
}

# Compile the dual port RAM module first
vlog -work work dual_port_ram.v

# Compile the DUT (Device Under Test) - SystemVerilog file
vlog -work work axi_simple_dual_port_ram.sv

# Compile the logger package first (required by testbench)
vlog -work work axi_logger_pkg.sv

# Compile the logger module
vlog -work work axi_logger.sv

# Compile the testbench - SystemVerilog file
vlog -work work axi_simple_dual_port_ram_tb.sv

# Start simulation with the testbench module
vsim -t ps -voptargs=+acc work.axi_simple_dual_port_ram_tb

# Add waves for all signals
add wave -noupdate -divider {Clock and Reset}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/clk
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/rst_n
add wave -noupdate -divider {Write Address Channel}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_aw_addr
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_aw_burst
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_aw_size
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_aw_id
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_aw_len
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_aw_valid
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_aw_ready
add wave -noupdate -divider {Write Data Channel}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_w_data
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_w_strb
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_w_last
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_w_valid
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_w_ready
add wave -noupdate -divider {Write Response Channel}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_b_resp
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_b_id
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_b_valid
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_b_ready
add wave -noupdate -divider {Read Address Channel}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_ar_addr
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_ar_burst
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_ar_size
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_ar_id
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_ar_len
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_ar_valid
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_ar_ready
add wave -noupdate -divider {Read Data Channel}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_r_data
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_r_resp
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_r_last
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_r_valid
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/axi_r_ready
add wave -noupdate -divider {Test Control}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/current_phase
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/write_addr_phase_start
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/write_data_phase_start
add wave -noupdate /axi_simple_dual_port_ram_tb/write_resp_phase_start
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/read_addr_phase_start
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/read_data_phase_start
add wave -noupdate -divider {Phase Completion}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/write_addr_phase_done
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/write_data_phase_done
add wave -noupdate /axi_simple_dual_port_ram_tb/write_resp_phase_done
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/read_addr_phase_done
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/read_data_phase_done
add wave -noupdate -divider {DUT Internal Signals}
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/dut/axi_clk
add wave -noupdate -radix hexadecimal /axi_simple_dual_port_ram_tb/dut/axi_resetn

# Set time resolution to 1ps
set time_resolution 1ps

# Run simulation with a timeout to avoid infinite loop
set MAX_SIM_TIME 2ms
run $MAX_SIM_TIME

echo "Simulation stopped (timeout = $MAX_SIM_TIME). If the test finishes earlier, it will call \$finish."
echo "If you still see no completion, inspect ready/valid handshakes and the log 'axi4_testbench.log'."
