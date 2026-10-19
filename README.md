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
## Notes and Reflection

### Challenges Encountered

#### 1. Designing the Parallel Multiply-Accumulate Datapath
One of the more challenging aspects of this project was translating matrix multiplication into a hardware architecture that could take advantage of parallel computation.
Unlike software, where matrix multiplication is typically implemented using nested loops, an FPGA allows multiple multiplication operations to occur simultaneously. The challenge was determining how to organize these operations while keeping the design manageable and parameterized.
To address this, I implemented a datapath with N parallel signed multipliers, allowing one complete dot product to be computed during each active cycle. The individual products are then accumulated to produce one element of the output matrix.
This helped me better understand the relationship between hardware parallelism, resource utilization, and computational throughput.

#### 2. Handling Signed Arithmetic and Accumulator Width
Another challenge was ensuring that signed multiplication and accumulation produced correct results without unintended overflow or truncation.
Since multiplying two W-bit signed numbers can require up to 2W bits, accumulating multiple products requires additional bits to represent the result correctly.
To handle this, I used a widened accumulator based on the operand width and matrix dimension, ensuring sufficient precision for the sum of N signed products.
This reinforced the importance of explicitly managing bit widths and signed arithmetic in RTL, especially when designing mathematical hardware accelerators.

#### 3. Implementing Transaction Control Logic
Another challenging aspect was coordinating the computation using the start, busy, and done signals.
Although the arithmetic datapath performs the multiplication, the controller must ensure that each output element is calculated and stored in the correct location. It must also prevent new transactions from interfering with an operation already in progress.
To address this, I implemented control logic that tracks the current output element, advances through the result matrix, and indicates when the computation is complete.
New start requests are ignored while the accelerator is busy, preventing an active computation from being interrupted.
This helped me understand how control logic and arithmetic datapaths must work together to create a reliable hardware accelerator.

#### 4. Verification and Debugging
Verifying the accelerator was another important part of the project. Even if the multiplication logic appears correct, errors in indexing, signed arithmetic, or transaction timing can lead to incorrect matrix results.
To improve verification, I developed a self-checking SystemVerilog testbench that compares the accelerator's output against a reference matrix multiplication model implemented using nested loops.
The verification environment includes identity-matrix tests, deterministic signed inputs, randomized signed matrices, and tests for start requests issued while the accelerator is busy.
Cycle-by-cycle result checking helped verify that the correct output elements were produced at the expected times.
This reinforced the importance of verifying both mathematical correctness and the timing behavior of digital hardware.

### What I Would Do Differently
If I were to rebuild this project, I would make several improvements to both the architecture and the verification process.
- **Explore different parallel architectures:** Compare the current parallel dot-product design with sequential MAC implementations and systolic arrays to better understand the trade-offs between throughput, latency, and FPGA resource utilization.
- **Introduce pipelining:** Add pipeline registers to the multiplication and accumulation datapath to reduce the critical path and potentially improve the maximum achievable clock frequency.
- **Expand verification coverage:** Introduce more edge-case tests involving maximum and minimum signed values, different matrix dimensions, accumulator overflow boundaries, and repeated transactions.
- **Improve performance analysis:** Evaluate synthesis reports to quantify resource utilization, logic depth, and achievable clock frequency rather than focusing only on functional correctness.
- **Integrate memory and communication interfaces:** Add a memory-mapped interface, such as AXI4-Lite for control and a suitable data-transfer interface for matrix operands, to make the accelerator easier to integrate into a larger SoC.

### Final Takeaway
The biggest lesson from this project was understanding how mathematical algorithms translate into physical hardware architectures. While matrix multiplication is straightforward to describe using software loops, implementing it in RTL requires careful consideration of parallelism, data widths, control sequencing, and timing.
Designing the parallel datapath strengthened my understanding of hardware acceleration and signed arithmetic, while developing the self-checking verification environment reinforced the importance of testing both computational correctness and cycle-level behavior.
This project also helped me appreciate the trade-offs between performance and hardware complexity, particularly how increasing parallelism can improve throughput while requiring additional logic resources.
```

## Skills demonstrated
Parameterized RTL, signed/fixed-width arithmetic, MAC datapaths, control logic, synthesis-aware design, self-checking verification, reference models, FPGA constraints and CI.
