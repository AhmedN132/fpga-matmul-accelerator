# FPGA Matrix-Multiply Accelerator

A parameterized signed fixed-point RTL accelerator for dense `N x N` matrix multiplication. The datapath computes one complete dot product per active cycle using `N` parallel signed multipliers and a widened accumulation path.

## Architecture
- Configurable matrix dimension (`N`) and operand width (`W`)
- `N` parallel signed multipliers per output element
- Widened accumulator sized from operand width and matrix dimension
- One output element committed per cycle while busy
- `start` / `busy` / `done` transaction interface
- New `start` requests are ignored while a transaction is active
- Registered result matrix

For the default `N=4`, a transaction produces 16 output elements over 16 active compute cycles after launch.

## Verification
The self-checking SystemVerilog regression covers:
- identity-matrix multiplication
- signed deterministic vectors
- randomized signed matrices
- control behavior when `start` is asserted while `busy`
- cycle-by-cycle result checking against a nested-loop reference model

## FPGA flow
- Example XDC clock constraint
- Yosys synthesis script
- Make targets for simulation and synthesis
- GitHub Actions simulation regression

## Run
```bash
make test
make synth   # optional, requires Yosys
```

## Skills demonstrated
Parameterized RTL, signed/fixed-width arithmetic, MAC datapaths, control logic, synthesis-aware design, self-checking verification, reference models, FPGA constraints and CI.
