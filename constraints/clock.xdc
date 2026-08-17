# Example clock constraint for a 100 MHz FPGA implementation.
create_clock -name clk -period 10.000 [get_ports clk]
