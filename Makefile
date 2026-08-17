.PHONY: test synth clean
test:
	iverilog -g2012 -o simv rtl/matmul_accel.sv tb/tb_matmul.sv
	vvp simv
synth:
	yosys synth/synth.ys
clean:
	rm -f simv *.vcd
